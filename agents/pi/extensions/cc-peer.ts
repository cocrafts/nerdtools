import { createHash, randomUUID, randomBytes, timingSafeEqual } from "node:crypto";
import { execFile } from "node:child_process";
import * as fs from "node:fs";
import * as net from "node:net";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Container, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

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
  if (process.platform === "win32") return rest.startsWith("\\\\.\\pipe\\") ? rest : undefined;
  return path.isAbsolute(rest) ? rest : undefined;
};

const asRecord = (value: unknown): Record<string, unknown> | undefined =>
  typeof value === "object" && value !== null ? (value as Record<string, unknown>) : undefined;

const str = (value: unknown): string | undefined => (typeof value === "string" ? value : undefined);

const tokenEquals = (a: string, b: string): boolean => {
  const ab = Buffer.from(a);
  const bb = Buffer.from(b);
  return ab.length === bb.length && timingSafeEqual(ab, bb);
};

const procStartViaPs = (targetPid: number): Promise<string | undefined> => {
  const { promise, resolve } = Promise.withResolvers<string | undefined>();
  execFile(
    "ps",
    ["-o", "lstart=", "-p", String(targetPid)],
    { timeout: 1_000, env: { ...process.env, LC_ALL: "C", TZ: "UTC" } },
    (err, stdout) => resolve(err ? undefined : stdout.trim() || undefined),
  );
  return promise;
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

export const readSelfProcStart = async (): Promise<string | undefined> =>
  process.platform === "win32"
    ? (await procStartViaPowerShell(process.pid)) || undefined
    : procStartViaPs(process.pid);

export const readProcStartForLiveness = async (targetPid: number): Promise<string | undefined> =>
  process.platform === "win32"
    ? (await procStartViaPowerShell(targetPid)) || undefined
    : procStartViaPs(targetPid);

const pidDomainForPlatform = (): string => {
  if (process.platform === "win32") return `win32:${os.hostname().toLowerCase()}`;
  if (process.platform === "darwin") return "darwin";
  throw new Error(
    `cc-peer: no Claude Code pidDomain for platform '${process.platform}'; only win32 and darwin are implemented`,
  );
};

const messagingSocketPathForPlatform = (pid: number): string =>
  process.platform === "win32"
    ? `\\\\.\\pipe\\LOCAL\\cc-msg-${randomBytes(16).toString("hex")}`
    : path.join("/tmp/cc-socks", `${pid}.sock`);

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

type PeerCredential = { peerToken: string; procStartFt?: string; procStart?: string };

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
    return { peerToken, procStartFt: str(parsed?.procStartFt), procStart: str(parsed?.procStart) };
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

const dialPipe = (pipe: string, timeoutMs: number, track: (socket: net.Socket) => void): Promise<net.Socket> => {
  const { promise, resolve, reject } = Promise.withResolvers<net.Socket>();
  const socket = net.connect({ path: pipe, timeout: timeoutMs });
  track(socket);
  const done = (err?: Error) => {
    socket.removeListener("connect", onConnect);
    socket.removeListener("error", onError);
    socket.removeListener("timeout", onTimeout);
    socket.removeListener("close", onClose);
    socket.setTimeout(0);
    if (err) {
      socket.destroy();
      reject(err);
    } else resolve(socket);
  };
  const onConnect = () => done();
  const onError = (err: Error) => done(err);
  const onTimeout = () => done(new Error(`connect timeout: ${pipe}`));
  const onClose = () => done(new Error(`connection closed: ${pipe}`));
  socket.once("connect", onConnect);
  socket.once("error", onError);
  socket.once("timeout", onTimeout);
  socket.once("close", onClose);
  return promise;
};

export default async function ccPeer(pi: ExtensionAPI) {
  const pid = process.pid;
  const peerToken = randomBytes(16).toString("hex");
  const pidDomain = pidDomainForPlatform();
  const messagingSocketPath = messagingSocketPathForPlatform(pid);
  const explicitName = process.env.CC_PEER_NAME?.trim() || "";
  const versionString = process.env.CC_PEER_VERSION?.trim() || "0.80.6";
  const fromMode = process.env.CC_PEER_FROM_MODE?.trim() || "bypass";
  const entryPath = path.join(registryDir, `${pid}.json`);
  const keyPath = path.join(registryDir, `${pid}.${keyHashForToken(peerToken)}.key`);
  let ownerSessionId: string | undefined;
  let peerName = explicitName;
  let lastStatus = "";
  let base: Record<string, unknown> | undefined;
  let removed = false;
  let agentBusy = false;
  let pipeServer: net.Server | undefined;
  let pendingInjects = 0;
  let sessionContext: ExtensionContext | undefined;
  let injectTimer: NodeJS.Timeout | undefined;
  let wakeInject: (() => void) | undefined;
  const sockets = new Set<net.Socket>();
  const idleSubscriptions = new Map<string, { pipe: string; fromMode?: string }>();
  const senderWindows = new Map<string, number[]>();
  const lastContentBySender = new Map<string, { content: string; at: number }>();

  const logger = {
    info: (message: string): void => {
      if (!removed && sessionContext?.hasUI) sessionContext.ui.notify(message, "info");
      else if (!removed) process.stderr.write(`${message}\n`);
    },
    warn: (message: string): void => {
      if (!removed && sessionContext?.hasUI) sessionContext.ui.notify(message, "warning");
      else if (!removed) process.stderr.write(`${message}\n`);
    },
  };

  const trackSocket = (socket: net.Socket): void => {
    sockets.add(socket);
    socket.once("close", () => sockets.delete(socket));
    socket.on("error", () => {});
  };

  const connectPeer = (pipe: string): Promise<net.Socket> => {
    if (removed) return Promise.reject(new Error("cc-peer session has shut down"));
    return dialPipe(pipe, 5_000, trackSocket);
  };

  pi.registerMessageRenderer(customMessageType, (message, options, theme) => {
    const content = typeof message.content === "string" ? message.content : "";
    const firstLine = content.split("\n").find((line) => line.trim().length > 0) ?? "";
    const nameMatch = /from-name="([^"\n>]+)/.exec(content);
    const header = `cc-peer message${nameMatch ? ` from ${nameMatch[1]}` : ""}`;
    const container = new Container();
    container.addChild(new Text(`${theme.fg("dim", "┈┈ ")}${theme.fg("warning", header)}`, 1, 0));
    container.addChild(new Text(options.expanded ? content : firstLine.slice(0, 200), 1, 0));
    return container;
  });

  const writeAtomic = (file: string, text: string): void => {
    const tmp = `${file}.tmp${randomBytes(4).toString("hex")}`;
    fs.writeFileSync(tmp, text);
    fs.renameSync(tmp, file);
  };

  const unregister = (): void => {
    if (removed) return;
    removed = true;
    process.removeListener("exit", unregister);
    if (injectTimer) clearTimeout(injectTimer);
    injectTimer = undefined;
    wakeInject?.();
    wakeInject = undefined;
    idleSubscriptions.clear();
    senderWindows.clear();
    lastContentBySender.clear();
    for (const socket of sockets) socket.destroy();
    sockets.clear();
    sessionContext = undefined;
    try {
      pipeServer?.close();
    } catch {}
    const owned = process.platform === "win32" ? [entryPath, keyPath] : [entryPath, keyPath, messagingSocketPath];
    for (const f of owned) {
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
    if (removed) return;
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
      logger.warn(`idle notice to ${pipe} skipped: no vouch key for that pipe`);
      return;
    }
    connectPeer(pipe)
      .then((socket) => {
        socket.end(payload);
      })
      .catch((err) => logger.warn(`idle notice to ${pipe} failed: ${String(err)}`));
  };

  let lastInjectAt = 0;
  let injectQueueTail: Promise<void> = Promise.resolve();

  const flushIdleSubscriptions = (): void => {
    if (removed || agentBusy || pendingInjects > 0 || !sessionContext?.isIdle() || sessionContext.hasPendingMessages()) return;
    for (const [msgId, sub] of idleSubscriptions) {
      idleSubscriptions.delete(msgId);
      sendIdleNotice(msgId, sub.pipe);
    }
  };

  const deliverToSession = (content: string): void => {
    if (removed) return;
    pendingInjects += 1;
    injectQueueTail = injectQueueTail.then(async () => {
      try {
        if (removed) return;
        const waitMs = Math.max(0, lastInjectAt + injectSpacingMs - Date.now());
        if (waitMs > 0) await new Promise<void>((resolve) => {
          wakeInject = resolve;
          injectTimer = setTimeout(resolve, waitMs);
        });
        injectTimer = undefined;
        wakeInject = undefined;
        if (removed) return;
        lastInjectAt = Date.now();
        pi.sendMessage(
          { customType: customMessageType, content, display: true },
          { deliverAs: "steer", triggerTurn: true },
        );
      } catch (err) {
        logger.warn(`cc-peer: injection failed: ${String(err)}`);
      } finally {
        pendingInjects -= 1;
        flushIdleSubscriptions();
      }
    });
  };

  const receiveUserFrame = (sender: string, content: string): void => {
    if (content.length > maxMessageChars) {
      logger.warn(`cc-peer: inbound dropped, ${content.length} chars over cap`);
      return;
    }
    const now = Date.now();
    const last = lastContentBySender.get(sender);
    if (last && last.content === content && now - last.at < repeatDropWindowMs) {
      logger.info(`cc-peer: inbound dropped as identical repeat from ${sender}`);
      return;
    }
    const window = senderWindows.get(sender) ?? [];
    const kept = window.filter((t) => now - t < perSenderWindowMs);
    if (kept.length >= perSenderMaxInWindow) {
      logger.warn(`cc-peer: inbound dropped, rate cap reached for ${sender}`);
      return;
    }
    kept.push(now);
    senderWindows.set(sender, kept);
    lastContentBySender.set(sender, { content, at: now });
    if (pendingInjects >= maxPendingInjects) {
      logger.warn(`cc-peer: inbound dropped, ${pendingInjects} injects already pending`);
      return;
    }
    deliverToSession(content);
  };

  const handleFrame = (rawLine: string): void => {
    let frame: Record<string, unknown>;
    try {
      frame = asRecord(JSON.parse(rawLine)) ?? {};
    } catch {
      logger.warn(`cc-peer: unparseable line (${rawLine.length}b)`);
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
        logger.info(`cc-peer: notify_when_idle msg=${msgId ?? "?"} pipe=${pipe ?? "unshaped"} busy=${agentBusy}`);
        if (msgId && pipe) {
          idleSubscriptions.set(msgId, { pipe, fromMode: str(frame.from_mode) });
          flushIdleSubscriptions();
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
      logger.info(`cc-peer: control action ignored: ${String(action)}`);
      return;
    }
    logger.info(`cc-peer: frame type ignored: ${String(type)}`);
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
      trackSocket(socket);
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
                logger.info(
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
    server.once("error", (err) => logger.warn(`peer pipe server error: ${String(err)}`));
    if (process.platform !== "win32") {
      fs.mkdirSync(path.dirname(messagingSocketPath), { recursive: true, mode: 0o700 });
      fs.rmSync(messagingSocketPath, { force: true });
    }
    return server;
  };

  pi.on("session_start", async (_event: unknown, ctx: ExtensionContext) => {
    if (ownerSessionId !== undefined) return;
    sessionContext = ctx;
    ownerSessionId = ctx.sessionManager.getSessionId();
    if (!peerName) {
      try {
        const sessionName = await pi.getSessionName();
        if (typeof sessionName === "string" && sessionName) peerName = sessionName;
      } catch {}
    }
    if (!peerName) peerName = `pi-${pid}`;
    const procStart = await readSelfProcStart();
    if (removed) return;
    if (!procStart) {
      logger.warn(`cc-peer: own process start time unreadable on ${process.platform}; not registering as a peer`);
      return;
    }
    const now = Date.now();
    base = {
      pid,
      sessionId: ownerSessionId,
      cwd: ctx.cwd,
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
    fs.mkdirSync(registryDir, { recursive: true, mode: 0o700 });
    const keyProcStart = process.platform === "win32" ? { procStartFt: procStart } : { procStart };
    try {
      pipeServer = startPipeServer();
      await new Promise<void>((resolve, reject) => {
        const onError = (err: Error) => reject(err);
        pipeServer!.once("error", onError);
        pipeServer!.listen(messagingSocketPath, () => {
          pipeServer!.removeListener("error", onError);
          resolve();
        });
      });
      if (removed) return;
      writeAtomic(keyPath, JSON.stringify({ peerToken, ...keyProcStart, pidDomain }));
      fs.chmodSync(keyPath, 0o600);
      writeAtomic(entryPath, JSON.stringify(base));
      process.on("exit", unregister);
    } catch (err) {
      logger.warn(`cc-peer: peer registration failed: ${String(err)}`);
      unregister();
    }
  });

  pi.on("turn_start", () => setStatus("busy"));
  pi.on("agent_start", () => {
    agentBusy = true;
    setStatus("busy");
  });
  pi.on("agent_settled", () => {
    agentBusy = false;
    setStatus("idle");
    flushIdleSubscriptions();
  });

  pi.on("session_shutdown", () => unregister());

  pi.registerTool({
    name: "cc_list_peers",
    label: "CC Peers",
    promptSnippet: "List Claude Code, OMP, and Pi sessions available for cross-session messaging.",
    description:
      "List Claude Code peer sessions registered in ~/.claude/sessions (name, kind, status, cwd, pid, vouched). Use for cross-session messaging discovery.",
    parameters: Type.Object({}),
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
    promptSnippet: "Send a message to a discovered peer; optionally subscribe to its idle notification.",
    description:
      "Send a cross-session message to a Claude Code peer by name over its messaging pipe. Prefer cc_list_peers first. Set subscribe_idle true to be notified when the peer goes idle.",
    parameters: Type.Object({
      to: Type.String({ description: "peer name, or 'name [pid]' with cc_list_peers pid as disambiguator" }),
      message: Type.String({ description: "message body" }),
      subscribe_idle: Type.Optional(Type.Boolean({ description: "request peer_idle_notice when the peer turns idle" })),
    }),
    async execute(_toolCallId, params) {
      if (removed || !base || !pipeServer?.listening) throw new Error("cc-peer is not registered in this session");
      if (params.message.length > maxMessageChars) {
        throw new Error(`message too large for cross-session delivery: ${params.message.length} chars (cap ${maxMessageChars})`);
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
        throw new Error(`no peer named '${nameOnly}'. known: ${known || "none"}`);
      }
      if (matches.length > 1) {
        throw new Error(`ambiguous name '${nameOnly}': ${matches
          .map((entry) => `${entry.name} [${entry.pid}]`)
          .join(", ")} — pass 'name [pid]'`);
      }
      const peer = matches[0];
      if (!peer.messagingSocketPath) {
        throw new Error(`peer '${nameOnly}' has no messagingSocketPath`);
      }
      if (!keyedPids.has(peer.pid)) {
        throw new Error(`refusing to send to an unvouched pipe (no key for pid ${peer.pid})`);
      }
      try {
        process.kill(peer.pid, 0);
      } catch {
        throw new Error(`peer pid ${peer.pid} is not alive (stale registry entry)`);
      }
      const credential = readPeerCredential(peer.pid);
      if (!credential) {
        throw new Error(`no vouch key readable for pid ${peer.pid}; cannot authenticate`);
      }
      const liveProcStart = await readProcStartForLiveness(peer.pid);
      const recordedProcStart = credential.procStartFt ?? credential.procStart ?? peer.procStart;
      if (liveProcStart && recordedProcStart && liveProcStart !== recordedProcStart) {
        throw new Error(`stale registry entry: pid ${peer.pid} was reused (procStart mismatch)`);
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
        throw new Error(`could not build authenticated payload for pid ${peer.pid}`);
      }
      try {
        const socket = await connectPeer(peer.messagingSocketPath);
        socket.end(payload);
      } catch (err) {
        throw new Error(`send to '${nameOnly}' failed: ${String(err)}`);
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
            const socket = await connectPeer(peer.messagingSocketPath);
            socket.end(subPayload);
          } catch (err) {
            logger.warn(`idle subscribe to ${nameOnly} failed: ${String(err)}`);
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
