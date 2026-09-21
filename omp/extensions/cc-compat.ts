import {
  existsSync,
  readFileSync,
  realpathSync,
  statSync,
} from "node:fs";
import { spawnSync } from "node:child_process";
import {
  basename,
  dirname,
  isAbsolute,
  join,
  relative,
  resolve,
  sep,
} from "node:path";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const HOME = process.env.HOME ?? process.env.USERPROFILE ?? "";
const GUARD = join(HOME, "nerdtools", "claude", "hooks", "comment-guard.sh");


// The guard speaks the Claude Code hook protocol (stdin JSON, exit 2 = deny);
// omp's edit is a patch language, so new_string is synthesized from its + rows.
function runGuard(
  toolName: "Edit" | "Write",
  toolInput: Record<string, unknown>,
  toolResponse?: string,
): string | null {
  try {
    const res = spawnSync("bash", [GUARD], {
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

function realpathOr(target: string): string {
  try {
    return realpathSync(target);
  } catch {
    const parent = dirname(target);
    if (parent === target) return target;
    return join(realpathOr(parent), basename(target));
  }
}

function isWithin(root: string, target: string): boolean {
  const rel = relative(root, target);
  return (
    rel === "" ||
    (rel !== ".." && !rel.startsWith(`..${sep}`) && !isAbsolute(rel))
  );
}

function nestedClaudeContext(
  cwd: string,
  toolName: string,
  rawPath: string,
  loaded: Set<string>,
): string | null {
  if (!["read", "edit", "write"].includes(toolName) || !rawPath) return null;

  const root = realpathOr(resolve(cwd));
  const target = realpathOr(resolve(cwd, rawPath));
  let dir: string;
  if (toolName === "read") {
    try {
      dir = statSync(target).isDirectory() ? target : dirname(target);
    } catch {
      return null;
    }
  } else {
    dir = dirname(target);
  }
  if (!isWithin(root, dir) || dir === root) return null;

  const dirs: string[] = [];
  while (dir !== root) {
    dirs.push(dir);
    const parent = dirname(dir);
    if (parent === dir) return null;
    dir = parent;
  }
  dirs.reverse();

  const files: Array<{ path: string; content: string }> = [];
  for (const directory of dirs) {
    const path = join(directory, "CLAUDE.md");
    let canonical: string;
    try {
      canonical = realpathSync(path);
      if (!isWithin(root, canonical) || !statSync(canonical).isFile()) continue;
    } catch {
      continue;
    }
    if (loaded.has(canonical)) continue;
    try {
      const content = readFileSync(canonical, "utf8").trim();
      loaded.add(canonical);
      if (content) files.push({ path, content });
    } catch {
      continue;
    }
  }
  if (!files.length) return null;

  return [
    "<repo-rules>",
    "Context files below became applicable to the path just accessed. You MUST follow them for work in their directories.",
    ...files.flatMap(({ path, content }) => [
      `<file path="${path.replaceAll("&", "&amp;").replaceAll('"', "&quot;").replaceAll("<", "&lt;").replaceAll(">", "&gt;")}">`,
      content,
      "</file>",
    ]),
    "</repo-rules>",
  ].join("\n");
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
  const loadedNestedClaudeMd = new Set<string>();

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

  pi.on("tool_result", (event, ctx) => {
    if (event.isError) {
      writeTargetExisted.delete(event.toolCallId);
      return;
    }
    if (event.toolName === "edit") {
      const path = String(event.input?.path ?? "");
      const added = String(event.input?.input ?? "")
        .split("\n")
        .filter((line) => line.startsWith("+"))
        .map((line) => line.slice(1));
      if (path && added.length) {
        const message = runGuard("Edit", {
          file_path: path,
          new_string: added.join("\n"),
          old_string: "",
        });
        if (message) {
          return { content: [{ type: "text", text: message }], isError: true };
        }
      }
    }
    if (event.toolName === "write") {
      const targetExisted = writeTargetExisted.get(event.toolCallId);
      writeTargetExisted.delete(event.toolCallId);
      if (targetExisted === false) {
        const path = String(event.input?.path ?? "");
        if (path) {
          const message = runGuard(
            "Write",
            { file_path: path, content: String(event.input?.content ?? "") },
            "Created",
          );
          if (message) {
            return { content: [{ type: "text", text: message }], isError: true };
          }
        }
      }
    }

    const context = nestedClaudeContext(
      String(ctx?.cwd ?? process.cwd()),
      event.toolName,
      String(event.input?.path ?? ""),
      loadedNestedClaudeMd,
    );
    if (!context) return;
    return {
      content: [...event.content, { type: "text" as const, text: context }],
    };
  });

  const rearmNestedClaudeMd = (): void => {
    loadedNestedClaudeMd.clear();
  };
  pi.on("session_compact", rearmNestedClaudeMd);
  pi.on("session_tree", rearmNestedClaudeMd);
  pi.on("session_shutdown", rearmNestedClaudeMd);

  pi.on("session_start", (_event, ctx) => {
    loadedNestedClaudeMd.clear();
    const cwd = String(ctx?.cwd ?? process.cwd());
    const wtState = wtSessionState(cwd);
    if (!wtState) return;
    try {
      pi.sendMessage(
        `Worktree/card state (tools/wt.sh hook-session):\n\n${wtState}`,
        {
          deliverAs: "nextTurn",
          attribution: "agent",
        },
      );
    } catch {}
  });
}
