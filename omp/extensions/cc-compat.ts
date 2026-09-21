import { readdirSync, readFileSync, existsSync, type Dirent } from "node:fs";
import { spawnSync } from "node:child_process";
import { join } from "node:path";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const HOME = process.env.HOME ?? "";
const GUARD = join(HOME, "nerdtools", "claude", "hooks", "comment-guard.sh");

const SKIP_DIRS: Record<string, true> = {
  ".git": true,
  node_modules: true,
  out: true,
  build: true,
  dist: true,
  vendor: true,
  target: true,
  ".venv": true,
};

// The guard speaks the Claude Code hook protocol (stdin JSON, exit 2 = deny);
// omp's edit is a patch language, so new_string is synthesized from its + rows.
function runGuard(
  toolName: "Edit" | "Write",
  toolInput: Record<string, unknown>,
  toolResponse?: string,
): string | null {
  try {
    const res = spawnSync(GUARD, {
      input: JSON.stringify({
        tool_name: toolName,
        tool_input: toolInput,
        ...(toolResponse === undefined ? {} : { tool_response: toolResponse }),
      }),
      encoding: "utf8",
      timeout: 10_000,
    });
    if (res.status === 2 && res.stderr) return res.stderr.trim();
    return null;
  } catch {
    return null;
  }
}

function deeperClaudeMd(cwd: string): string[] {
  const found: string[] = [];
  const walk = (dir: string, depth: number): void => {
    if (found.length >= 30 || depth > 6) return;
    let entries: Dirent[];
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      if (found.length >= 30) return;
      if (entry.isFile() && entry.name === "CLAUDE.md") {
        found.push(join(dir, entry.name));
        continue;
      }
      if (
        entry.isDirectory() &&
        !entry.name.startsWith(".") &&
        !SKIP_DIRS[entry.name]
      ) {
        walk(join(dir, entry.name), depth + 1);
      }
    }
  };
  try {
    for (const entry of readdirSync(cwd, { withFileTypes: true })) {
      if (
        entry.isDirectory() &&
        !entry.name.startsWith(".") &&
        !SKIP_DIRS[entry.name]
      ) {
        walk(join(cwd, entry.name), 1);
      }
    }
  } catch {
    // A cwd we cannot read has nothing to point at.
  }
  return found;
}

// wt.sh hook-session prints the worktree's card and the compiler inbox
// tally on stdout; like Claude Code's SessionStart wiring, run the main
// checkout's copy with CLAUDE_PROJECT_DIR pointing at this session's cwd.
function wtSessionState(cwd: string): string | null {
  try {
    const list = spawnSync("git", ["worktree", "list", "--porcelain"], {
      cwd,
      encoding: "utf8",
      timeout: 5_000,
    });
    const mainLine = (list.stdout ?? "")
      .split("\n")
      .find((line) => line.startsWith("worktree "));
    if (!mainLine) return null;
    const wtSh = join(mainLine.slice("worktree ".length), "tools", "wt.sh");
    if (!existsSync(wtSh)) return null;
    const res = spawnSync("bash", [wtSh, "hook-session"], {
      cwd,
      encoding: "utf8",
      timeout: 15_000,
      env: { ...process.env, CLAUDE_PROJECT_DIR: cwd },
    });
    const out = (res.stdout ?? "").trim();
    return out.length ? out : null;
  } catch {
    return null;
  }
}
export default function (pi: ExtensionAPI) {
  const writeTargetExisted = new Map<string, boolean>();

  pi.on("tool_call", (event) => {
    if (event.toolName === "write" && event.input?.path) {
      try {
        writeTargetExisted.set(
          event.toolCallId,
          existsSync(String(event.input.path)),
        );
      } catch {
        writeTargetExisted.set(event.toolCallId, true);
      }
    }
  });

  pi.on("tool_result", (event) => {
    if (event.isError) return;
    if (event.toolName === "edit") {
      const path = String(event.input?.path ?? "");
      const added = String(event.input?.input ?? "")
        .split("\n")
        .filter((line) => line.startsWith("+"))
        .map((line) => line.slice(1));
      if (!path || !added.length) return;
      const message = runGuard("Edit", {
        file_path: path,
        new_string: added.join("\n"),
        old_string: "",
      });
      if (message) {
        return { content: [{ type: "text", text: message }], isError: true };
      }
      return;
    }
    if (event.toolName === "write") {
      if (writeTargetExisted.get(event.toolCallId) !== false) return;
      writeTargetExisted.delete(event.toolCallId);
      const path = String(event.input?.path ?? "");
      if (!path) return;
      const message = runGuard(
        "Write",
        { file_path: path, content: String(event.input?.content ?? "") },
        "Created",
      );
      if (message) {
        return { content: [{ type: "text", text: message }], isError: true };
      }
    }
  });

  pi.on("session_start", (_event, ctx) => {
    const cwd = String(ctx?.cwd ?? process.cwd());
    const parts: string[] = [];
    const memoryPath = join(
      HOME,
      ".claude",
      "projects",
      cwd.replace(/[^a-zA-Z0-9]/g, "-"),
      "memory",
      "MEMORY.md",
    );
    try {
      const memory = readFileSync(memoryPath, "utf8").trim();
      if (memory) {
        parts.push(
          `Claude Code memory index for this directory (${memoryPath}); follow its pointers at session start:\n\n${memory}`,
        );
      }
    } catch {
      // No store for this cwd: nothing to inject.
    }
    const wtState = wtSessionState(cwd);
    if (wtState) {
      parts.unshift(
        `Worktree/card state (tools/wt.sh hook-session):\n\n${wtState}`,
      );
    }
    const deeper = deeperClaudeMd(cwd);
    if (deeper.length) {
      parts.push(
        `CLAUDE.md files below the working directory; read the one covering a directory before editing files in it:\n${deeper.map((p) => `- ${p}`).join("\n")}`,
      );
    }
    if (parts.length) {
      try {
        pi.sendMessage(parts.join("\n\n"), {
          deliverAs: "nextTurn",
          attribution: "agent",
        });
      } catch {
        // Injection is advisory; a delivery failure must not kill the session.
      }
    }
  });
}
