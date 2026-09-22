import { createHash, randomUUID, randomBytes, timingSafeEqual } from "node:crypto";
import { execFile } from "node:child_process";
import * as fs from "node:fs";
import * as net from "node:net";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@oh-my-pi/pi-coding-agent";

const registryDir = path.join(os.homedir(), ".claude", "sessions");
const entryFileRe = /^(\d+)\.json$/;
const keyFileRe = /^(\d+)\.[0-9a-f]{64}\.key$/;
const customMessageType = "cc-peer.message";
const wireVersion = 1;
const maxMessageChars = 1_000_000;
const maxPendingInjects = 50;
const perSenderWindowMs = 60_000;
const perSenderMaxInWindow = 20;
const repeatDropWindowMs = 10_000;
const injectSpacingMs = 1_500;
export const keyHashForToken = (token: string): string =>
  createHash("sha256").update(token, "utf8").digest("hex");

const udsForm = (pipe: string): string => `uds:${pipe}`;

const pipeFromUds = (address: string): string | undefined => {
  if (!address.startsWith("uds:")) return undefined;
  const rest = address.slice(4);
  return rest.startsWith("\\\\.\\pipe\\") ? rest : undefined;
};

const asRecord = (value: unknown): Record<string, unknown> | undefined =>
  typeof value === "object" && value !== null ? (value as Record<string, unknown>) : undefined;

const str = (value: unknown): string | undefined => (typeof value === "string" ? value : undefined);

const tokenEquals = (a: string, b: string): boolean => {
  const ab = Buffer.from(a);
  const bb = Buffer.from(b);
  return ab.length === bb.length && timingSafeEqual(ab, bb);
};

type Kernel32Api = {
  OpenProcess: (access: number, inherit: number, pid: number) => unknown;
  GetProcessTimes: (
    handle: unknown,
    creation: Uint8Array,
    exitTime: Uint8Array,
    kernel: Uint8Array,
    user: Uint8Array,
  ) => number;
  CloseHandle: (handle: unknown) => number;
};

let kernel32Once: Promise<Kernel32Api | undefined> | undefined;

const kernel32 = (): Promise<Kernel32Api | undefined> => {
  kernel32Once ??= (async () => {
    try {
      const ffi = await import("bun:ffi");
      const symbols = ffi.dlopen("kernel32.dll", {
        OpenProcess: { args: ["u32", "i32", "u32"], returns: "ptr" },
        GetProcessTimes: { args: ["ptr", "ptr", "ptr", "ptr", "ptr"], returns: "i32" },
        CloseHandle: { args: ["ptr"], returns: "i32" },
      }).symbols;
      return symbols as unknown as Kernel32Api;
    } catch {
      return undefined;
    }
  })();
  return kernel32Once;
};

const filetimeFromBuffer = (creation: Uint8Array): string => {
  const dv = new DataView(creation.buffer, creation.byteOffset, 8);
  const lo = BigInt(dv.getUint32(0, true));
  const hi = BigInt(dv.getUint32(4, true));
  return ((hi << 32n) | lo).toString();
};

const readProcStartViaKernel32 = async (targetPid: number): Promise<string | undefined> => {
  const api = await kernel32();
  if (!api) return undefined;
  const handle = api.OpenProcess(0x1000, 0, targetPid);
  if (!handle) return undefined;
  try {
    const creation = new Uint8Array(8);
    const exitTime = new Uint8Array(8);
    const kernelTime = new Uint8Array(8);
    const userTime = new Uint8Array(8);
    if (api.GetProcessTimes(handle, creation, exitTime, kernelTime, userTime) === 0) return undefined;
    return filetimeFromBuffer(creation);
  } finally {
    api.CloseHandle(handle);
  }
};

const procStartFromProcFs = (targetPid: number): string | undefined => {
  try {
    const stat = fs.readFileSync(`/proc/${targetPid}/stat`, "utf8");
    return stat.slice(stat.lastIndexOf(")") + 2).split(" ")[19];
  } catch {
    return undefined;
  }
};

const procStartViaPowerShell = (targetPid: number): Promise<string> => {
  const { promise, resolve } = Promise.withResolvers<string>();
  execFile(
    "powershell.exe",
    [
      "-NoProfile",
      "-Command",
      `[System.Diagnostics.Process]::GetProcessById(${targetPid}).StartTime.ToFileTime()`,
    ],
    { timeout: 10_000, windowsHide: true },
    (err, stdout) => resolve(err ? "" : stdout.trim()),
  );
  return promise;
};

export const readSelfProcStart = async (): Promise<string> => {
  if (process.platform !== "win32") return procStartFromProcFs(process.pid) ?? "";
  return (await readProcStartViaKernel32(process.pid)) ?? (await procStartViaPowerShell(process.pid));
};

export const readProcStartForLiveness = async (targetPid: number): Promise<string | undefined> => {
  if (process.platform !== "win32") return procStartFromProcFs(targetPid);
  return readProcStartViaKernel32(targetPid);
};

type RegistryEntry = {
  pid: number;
  name?: string;
  kind?: string;
  status?: string;
  cwd?: string;
  startedAt?: number;
  procStart?: string;
  messagingSocketPath?: string;
  pidDomain?: string;
};

type PeerCredential = { peerToken: string; procStartFt?: string };

const readRegistry = (): { entries: RegistryEntry[]; keyedPids: Set<number> } => {
  const files = fs.existsSync(registryDir) ? fs.readdirSync(registryDir) : [];
  const keyedPids = new Set<number>();
  const entryFiles: { pid: number; file: string }[] = [];
  for (const f of files) {
    const keyMatch = keyFileRe.exec(f);
    if (keyMatch) {
      keyedPids.add(parseInt(keyMatch[1], 10));
      continue;
    }
    const entryMatch = entryFileRe.exec(f);
    if (entryMatch) entryFiles.push({ pid: parseInt(entryMatch[1], 10), file: f });
  }
  const entries: RegistryEntry[] = [];
  for (const { pid, file } of entryFiles) {
    try {
      const parsed = asRecord(JSON.parse(fs.readFileSync(path.join(registryDir, file), "utf8")));
      if (!parsed) continue;
      entries.push({
        pid,
        name: str(parsed.name),
        kind: str(parsed.kind),
        status: str(parsed.status),
        cwd: str(parsed.cwd),
        startedAt: typeof parsed.startedAt === "number" ? parsed.startedAt : undefined,
        procStart: str(parsed.procStart),
        messagingSocketPath: str(parsed.messagingSocketPath),
        pidDomain: str(parsed.pidDomain),
      });
    } catch {}
  }
  return { entries, keyedPids };
};

const keyFileForPid = (targetPid: number): string | undefined =>
  fs
    .readdirSync(registryDir)
    .find((f) => keyFileRe.exec(f)?.[1] === String(targetPid));

const readPeerCredential = (targetPid: number): PeerCredential | undefined => {
  const keyFile = fs.existsSync(registryDir) ? keyFileForPid(targetPid) : undefined;
  if (!keyFile) return undefined;
  try {
    const parsed = asRecord(JSON.parse(fs.readFileSync(path.join(registryDir, keyFile), "utf8")));
    const peerToken = str(parsed?.peerToken);
    if (!peerToken) return undefined;
    return { peerToken, procStartFt: str(parsed?.procStartFt) };
  } catch {
    return undefined;
  }
};

const readPeerTokenForPipe = (pipe: string): string | undefined => {
  const { entries } = readRegistry();
  const owner = entries.find((entry) => entry.messagingSocketPath === pipe && entry.pid !== process.pid);
  return owner ? readPeerCredential(owner.pid)?.peerToken : undefined;
};

const authenticatedPayload = (targetPeerToken: string | undefined, frame: unknown): string | undefined => {
  if (!targetPeerToken) return undefined;
  return `${JSON.stringify({ type: "auth", token: targetPeerToken })}\n${JSON.stringify(frame)}\n`;
};

const dialPipe = (pipe: string, timeoutMs: number): Promise<net.Socket> => {
  const { promise, resolve, reject } = Promise.withResolvers<net.Socket>();
  const socket = net.connect({ path: pipe, timeout: timeoutMs });
  const done = (err?: Error) => {
    socket.removeAllListeners();
    if (err) reject(err);
    else resolve(socket);
  };
  socket.once("connect", () => done());
  socket.once("error", (err) => done(err));
  socket.once("timeout", () => done(new Error(`connect timeout: ${pipe}`)));
  return promise;
};

export default async function ccPeer(pi: ExtensionAPI) {
  const pid = process.pid;
  const peerToken = randomBytes(16).toString("hex");
  const pidDomain = `${process.platform}:${os.hostname().toLowerCase()}`;
  const messagingSocketPath = `\\\\.\\pipe\\LOCAL\\cc-msg-${randomBytes(16).toString("hex")}`;
  const explicitName = process.env.CC_PEER_NAME?.trim() || "";
  const versionString = process.env.CC_PEER_VERSION?.trim() || "18.2.6";
  const fromMode = process.env.CC_PEER_FROM_MODE?.trim() || "bypass";
  const entryPath = path.join(registryDir, `${pid}.json`);
  const keyPath = path.join(registryDir, `${pid}.${keyHashForToken(peerToken)}.key`);
  const procStartPromise = readSelfProcStart();
  let ownerSessionId: string | undefined;
  let peerName = explicitName;
  let lastStatus = "";
  let base: Record<string, unknown> | undefined;
  let removed = false;
  let agentBusy = false;
  let pipeServer: net.Server | undefined;
  let pendingInjects = 0;
  const idleSubscriptions = new Map<string, { pipe: string; fromMode?: string }>();
  const senderWindows = new Map<string, number[]>();
  const lastContentBySender = new Map<string, { content: string; at: number }>();

  try {
    const tui = await import("@oh-my-pi/pi-tui");
    pi.registerMessageRenderer(customMessageType, (message: unknown, _opts: unknown, theme: unknown) => {
      const record = asRecord(message);
      const content = str(record?.content) ?? "";
      const firstLine = content.split("\n").find((line) => line.trim().length > 0) ?? "";
      const nameMatch = /from-name=\\"?([^"\n>]+)/.exec(content);
      const header = `cc-peer message${nameMatch ? ` from ${nameMatch[1]}` : ""}`;
      const container = new tui.Container();
      const themed = asRecord(theme);
      const fg = typeof themed?.fg === "function" ? themed.fg : (tone: string, text: string) => text;
      container.addChild(new tui.Text(`${fg("dim", "┈┈ ")}${fg("yellow", header)}`, 1, 0));
      container.addChild(new tui.Text(firstLine.slice(0, 200), 1, 0));
      return container;
    });
  } catch {}

  const writeAtomic = (file: string, text: string): void => {
    const tmp = `${file}.tmp${randomBytes(4).toString("hex")}`;
    fs.writeFileSync(tmp, text);
    fs.renameSync(tmp, file);
  };

  const unregister = (): void => {
    if (removed) return;
    removed = true;
    try {
      pipeServer?.close();
    } catch {}
    for (const f of [entryPath, keyPath]) {
      try {
        fs.unlinkSync(f);
      } catch {}
    }
  };

  const setStatus = (status: "busy" | "idle"): void => {
    if (!base || removed || status === lastStatus) return;
    lastStatus = status;
    const now = Date.now();
    writeAtomic(entryPath, JSON.stringify({ ...base, status, updatedAt: now, statusUpdatedAt: now }));
  };

  const sendIdleNotice = (origMsgId: string, pipe: string): void => {
    const frame = {
      msgV: wireVersion,
      type: "control",
      action: "peer_idle_notice",
      orig_msg_id: origMsgId,
      state: "idle",
      finished_at: new Date().toISOString(),
      from: udsForm(messagingSocketPath),
      from_mode: fromMode,
    };
    const payload = authenticatedPayload(readPeerTokenForPipe(pipe), frame);
    if (!payload) {
      pi.logger.warn(`idle notice to ${pipe} skipped: no vouch key for that pipe`);
      return;
    }
    dialPipe(pipe, 5_000)
      .then((socket) => {
        socket.end(payload);
      })
      .catch((err) => pi.logger.warn(`idle notice to ${pipe} failed: ${String(err)}`));
  };

  let lastInjectAt = 0;
  let injectQueueTail: Promise<void> = Promise.resolve();

  const deliverToSession = (content: string): void => {
    injectQueueTail = injectQueueTail.then(async () => {
      const waitMs = Math.max(0, lastInjectAt + injectSpacingMs - Date.now());
      if (waitMs > 0) await new Promise((r) => setTimeout(r, waitMs));
      lastInjectAt = Date.now();
      try {
        pi.sendMessage(
          { customType: customMessageType, attribution: "agent", content },
          { deliverAs: "aside" },
        );
      } catch (err) {
        pi.logger.warn(`cc-peer: injection failed: ${String(err)}`);
      }
    });
  };

  const receiveUserFrame = (sender: string, content: string): void => {
    if (content.length > maxMessageChars) {
      pi.logger.warn(`cc-peer: inbound dropped, ${content.length} chars over cap`);
      return;
    }
    const now = Date.now();
    const last = lastContentBySender.get(sender);
    if (last && last.content === content && now - last.at < repeatDropWindowMs) {
      pi.logger.info(`cc-peer: inbound dropped as identical repeat from ${sender}`);
      return;
    }
    const window = senderWindows.get(sender) ?? [];
    const kept = window.filter((t) => now - t < perSenderWindowMs);
    if (kept.length >= perSenderMaxInWindow) {
      pi.logger.warn(`cc-peer: inbound dropped, rate cap reached for ${sender}`);
      return;
    }
    kept.push(now);
    senderWindows.set(sender, kept);
    lastContentBySender.set(sender, { content, at: now });
    if (pendingInjects >= maxPendingInjects) {
      pi.logger.warn(`cc-peer: inbound dropped, ${pendingInjects} injects already pending`);
      return;
    }
    pendingInjects += 1;
    deliverToSession(content);
  };

  const handleFrame = (rawLine: string): void => {
    let frame: Record<string, unknown>;
    try {
      frame = asRecord(JSON.parse(rawLine)) ?? {};
    } catch {
      pi.logger.warn(`cc-peer: unparseable line (${rawLine.length}b)`);
      return;
    }
    const type = frame.type;
    if (type === "auth") return;
    if (type === "user") {
      const message = asRecord(frame.message);
      const content = str(message?.content);
      const sender = str(frame.from) ?? "unknown";
      if (content) receiveUserFrame(sender, content);
      return;
    }
    if (type === "control") {
      const action = frame.action;
      if (action === "notify_when_idle") {
        const msgId = str(frame.msg_id);
        const from = str(frame.from);
        const pipe = from ? pipeFromUds(from) : undefined;
        pi.logger.info(`cc-peer: notify_when_idle msg=${msgId ?? "?"} pipe=${pipe ?? "unshaped"} busy=${agentBusy}`);
        if (msgId && pipe) {
          idleSubscriptions.set(msgId, { pipe, fromMode: str(frame.from_mode) });
          if (!agentBusy) sendIdleNotice(msgId, pipe);
        }
        return;
      }
      if (action === "peer_idle_notice") {
        const orig = str(frame.orig_msg_id) ?? "unknown";
        const state = str(frame.state) ?? "unknown";
        deliverToSession(`<peer-idle-notice orig="${orig}" state="${state}"/>`);
        return;
      }
      if (action === "peer_message_status") {
        const status = str(frame.status) ?? "unknown";
        const orig = str(frame.orig_msg_id) ?? "";
        const reason = str(frame.reason) ?? str(frame.drop_reason) ?? "";
        deliverToSession(
          `<peer-message-status orig="${orig}" status="${status}"${reason ? ` reason="${reason}"` : ""}/>`,
        );
        return;
      }
      pi.logger.info(`cc-peer: control action ignored: ${String(action)}`);
      return;
    }
    pi.logger.info(`cc-peer: frame type ignored: ${String(type)}`);
  };

  const authLineRejection = (rawLine: string): string | undefined => {
    let rec: Record<string, unknown> | undefined;
    try {
      rec = asRecord(JSON.parse(rawLine));
    } catch {
      return `not JSON (${rawLine.length} chars, starts ${JSON.stringify(rawLine.slice(0, 24))})`;
    }
    if (!rec) return "JSON but not an object";
    if (rec.type !== "auth")
      return `type is ${JSON.stringify(rec.type)}, not "auth"; keys present: ${Object.keys(rec).join(",")}`;
    const token = str(rec.token);
    if (!token) return `no token field; keys present: ${Object.keys(rec).join(",")}`;
    if (!tokenEquals(token, peerToken))
      return `token mismatch: got ${token.length} chars sha256 ${keyHashForToken(token).slice(0, 12)}, expected ${peerToken.length} chars sha256 ${keyHashForToken(peerToken).slice(0, 12)}`;
    return undefined;
  };

  const startPipeServer = (): net.Server => {
    const server = net.createServer((socket) => {
      let buffer = "";
      let authed = false;
      socket.on("data", (chunk) => {
        buffer += chunk.toString("utf8");
        let newlineAt = buffer.indexOf("\n");
        while (newlineAt >= 0) {
          const line = buffer.slice(0, newlineAt).trim();
          buffer = buffer.slice(newlineAt + 1);
          if (line) {
            if (!authed) {
              if (authLineRejection(line) === undefined) {
                authed = true;
              } else {
                authed = true;
                pi.logger.info(
                  `cc-peer: unauthenticated first line accepted (Claude Code senders open with the user frame); gate is logging-only`,
                );
                handleFrame(line);
              }
            } else {
              handleFrame(line);
            }
          }
          newlineAt = buffer.indexOf("\n");
        }
      });
      socket.on("error", () => {});
    });
    server.once("error", (err) => pi.logger.warn(`peer pipe server error: ${String(err)}`));
    server.listen(messagingSocketPath);
    return server;
  };

  pi.on("session_start", async (_event: unknown, ctx: ExtensionContext) => {
    if (ownerSessionId !== undefined) return;
    ownerSessionId = ctx?.sessionManager?.getSessionId?.();
    if (!peerName) {
      try {
        const sessionName = await pi.getSessionName();
        if (typeof sessionName === "string" && sessionName) peerName = sessionName;
      } catch {}
    }
    if (!peerName) peerName = `omp-${pid}`;
    const procStart = await procStartPromise;
    const now = Date.now();
    base = {
      pid,
      sessionId: ownerSessionId,
      cwd: ctx?.cwd,
      startedAt: now,
      procStart,
      version: versionString,
      peerProtocol: 1,
      peerFeatures: ["notify_idle"],
      kind: process.env.CC_PEER_KIND?.trim() || "interactive",
      entrypoint: "cli",
      pidDomain,
      messagingSocketPath,
      name: peerName,
      nameSource: explicitName ? "explicit" : "derived",
      nameSince: now,
      status: "idle",
      updatedAt: now,
      statusUpdatedAt: now,
    };
    lastStatus = "idle";
    fs.mkdirSync(registryDir, { recursive: true });
    writeAtomic(keyPath, JSON.stringify({ peerToken, procStartFt: procStart, pidDomain }));
    writeAtomic(entryPath, JSON.stringify(base));
    pipeServer = startPipeServer();
  });

  pi.on("turn_start", () => setStatus("busy"));
  pi.on("agent_start", () => {
    agentBusy = true;
    setStatus("busy");
  });
  pi.on("turn_end", () => setStatus("idle"));
  pi.on("agent_end", () => {
    agentBusy = false;
    pendingInjects = 0;
    setStatus("idle");
    for (const [msgId, sub] of [...idleSubscriptions]) {
      idleSubscriptions.delete(msgId);
      sendIdleNotice(msgId, sub.pipe);
    }
  });

  pi.on("session_shutdown", (_event: unknown, ctx: ExtensionContext) => {
    const sid = ctx?.sessionManager?.getSessionId?.();
    if (sid && ownerSessionId && sid !== ownerSessionId) return;
    unregister();
  });

  for (const sig of ["SIGINT", "SIGTERM", "SIGHUP", "exit"] as const) {
    process.on(sig, () => {
      try {
        unregister();
      } catch {}
    });
  }

  const z = pi.zod;

  pi.registerTool({
    name: "cc_list_peers",
    label: "CC Peers",
    description:
      "List Claude Code peer sessions registered in ~/.claude/sessions (name, kind, status, cwd, pid, vouched). Use for cross-session messaging discovery.",
    parameters: z.object({}),
    async execute() {
      const { entries, keyedPids } = readRegistry();
      const rows = entries
        .filter((entry) => entry.pid !== pid && entry.name)
        .sort((a, b) => (b.startedAt ?? 0) - (a.startedAt ?? 0))
        .map((entry) => ({
          name: entry.name,
          pid: entry.pid,
          kind: entry.kind ?? "?",
          status: entry.status ?? "?",
          cwd: entry.cwd ?? "?",
          vouched: keyedPids.has(entry.pid),
          messagingSocketPath: entry.messagingSocketPath ?? undefined,
        }));
      const lines = rows.map(
        (row) =>
          `${row.name} [${row.pid}] ${row.kind}/${row.status} vouched=${row.vouched} ${row.cwd}`,
      );
      return {
        content: [{ type: "text", text: lines.length ? lines.join("\n") : "no peers" }],
        details: { rows },
      };
    },
  });

  pi.registerTool({
    name: "cc_send_message",
    label: "CC Send",
    description:
      "Send a cross-session message to a Claude Code peer by name over its messaging pipe. Prefer cc_list_peers first. Set subscribe_idle true to be notified when the peer goes idle.",
    parameters: z.object({
      to: z.string().describe("peer name, or 'name [pid]' with cc_list_peers pid as disambiguator"),
      message: z.string().describe("message body"),
      subscribe_idle: z
        .boolean()
        .optional()
        .describe("request peer_idle_notice when the peer turns idle"),
    }),
    async execute(_toolCallId, params) {
      if (params.message.length > maxMessageChars) {
        return {
          content: [
            {
              type: "text",
              text: `message too large for cross-session delivery: ${params.message.length} chars (cap ${maxMessageChars})`,
            },
          ],
          isError: true,
        };
      }
      const target = params.to.trim();
      const pidHint = /\[(\d+)\]\s*$/.exec(target)?.[1];
      const nameOnly = target.replace(/\s*\[\d+\]\s*$/, "").trim();
      const { entries, keyedPids } = readRegistry();
      const matches = entries.filter(
        (entry) =>
          entry.name === nameOnly && entry.pid !== pid && (!pidHint || String(entry.pid) === pidHint),
      );
      if (matches.length === 0) {
        const known = entries
          .filter((entry) => entry.name && entry.pid !== pid)
          .map((entry) => `${entry.name} [${entry.pid}]`)
          .join(", ");
        return {
          content: [{ type: "text", text: `no peer named '${nameOnly}'. known: ${known || "none"}` }],
          isError: true,
        };
      }
      if (matches.length > 1) {
        return {
          content: [
            {
              type: "text",
              text: `ambiguous name '${nameOnly}': ${matches
                .map((entry) => `${entry.name} [${entry.pid}]`)
                .join(", ")} — pass 'name [pid]'`,
            },
          ],
          isError: true,
        };
      }
      const peer = matches[0];
      if (!peer.messagingSocketPath) {
        return {
          content: [{ type: "text", text: `peer '${nameOnly}' has no messagingSocketPath` }],
          isError: true,
        };
      }
      if (!keyedPids.has(peer.pid)) {
        return {
          content: [
            { type: "text", text: `refusing to send to an unvouched pipe (no key for pid ${peer.pid})` },
          ],
          isError: true,
        };
      }
      try {
        process.kill(peer.pid, 0);
      } catch {
        return {
          content: [
            { type: "text", text: `peer pid ${peer.pid} is not alive (stale registry entry)` },
          ],
          isError: true,
        };
      }
      const credential = readPeerCredential(peer.pid);
      if (!credential) {
        return {
          content: [
            { type: "text", text: `no vouch key readable for pid ${peer.pid}; cannot authenticate` },
          ],
          isError: true,
        };
      }
      const liveProcStart = await readProcStartForLiveness(peer.pid);
      const recordedProcStart = credential.procStartFt ?? peer.procStart;
      if (liveProcStart && recordedProcStart && liveProcStart !== recordedProcStart) {
        return {
          content: [
            {
              type: "text",
              text: `stale registry entry: pid ${peer.pid} was reused (procStart mismatch)`,
            },
          ],
          isError: true,
        };
      }
      const msgId = randomUUID();
      const wrapped = `<cross-session-message from="${udsForm(messagingSocketPath)}" from-name="${peerName}" from-mode="${fromMode}">\n${params.message}\n</cross-session-message>`;
      const frame = {
        msgV: wireVersion,
        msg_id: msgId,
        type: "user",
        message: { role: "user", content: wrapped },
        priority: "next",
        from: udsForm(messagingSocketPath),
      };
      const payload = authenticatedPayload(credential.peerToken, frame);
      if (!payload) {
        return {
          content: [{ type: "text", text: `could not build authenticated payload for pid ${peer.pid}` }],
          isError: true,
        };
      }
      try {
        const socket = await dialPipe(peer.messagingSocketPath, 5_000);
        socket.end(payload);
      } catch (err) {
        return {
          content: [{ type: "text", text: `send to '${nameOnly}' failed: ${String(err)}` }],
          isError: true,
        };
      }
      if (params.subscribe_idle) {
        const subFrame = {
          msgV: wireVersion,
          type: "control",
          action: "notify_when_idle",
          from: udsForm(messagingSocketPath),
          msg_id: randomUUID(),
          from_mode: fromMode,
        };
        const subPayload = authenticatedPayload(credential.peerToken, subFrame);
        if (subPayload) {
          try {
            const socket = await dialPipe(peer.messagingSocketPath, 5_000);
            socket.end(subPayload);
          } catch (err) {
            pi.logger.warn(`idle subscribe to ${nameOnly} failed: ${String(err)}`);
          }
        }
      }
      return {
        content: [{ type: "text", text: `sent to ${nameOnly} [${peer.pid}] (msg_id ${msgId})` }],
        details: { msgId, peerPid: peer.pid },
      };
    },
  });
}
