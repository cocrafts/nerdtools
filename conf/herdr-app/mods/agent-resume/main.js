// agent-resume: starts the sessions of coding agents again after a reboot.
// Agents: Claude Code, Codex, Antigravity (agy), OpenCode and Pi (see AGENTS in resume.js).
//
// A hook or a plugin of each agent writes labels on its herdr-core terminal:
//   resume.agent, resume.session (the session id), resume.pid (the shell pid), resume.args (the flags)
// After a reboot, herdr-core gives each kept terminal a new shell in its last folder.
// The new shell has a different pid. When this mod sees a labeled terminal with a
// different pid and no agent in it, it types the resume command of that agent in the shell.
// Before it types, it writes resume.tried=<shell pid>, so a failed resume is not repeated.
//
// The mod also:
//   - removes the labels when an agent exits in the same shell (no reboot), and
//   - records agents that have no hook (mode without a hook): no session id, so it
//     resumes the last session in the folder.
//
// This file has 2 roles:
//   - In the layout (the status bar): the indicator and the scanner.
//   - As a popup (props.panel): the panel with the config and the sessions (panel.js).

import { View, div } from "gpui-kit";
import { h_flex } from "gpui-base";
import { notify, theme, props, openOverlay, nextCommand, agents, terminals, hc, run, shared, closeOverlay } from "herdr";
import {
  AGENTS, config, labeled, inspect, sessionState, resumeNow, forget,
  agentForApp, recordWithoutHook, refreshPid,
} from "./resume.js";
import { codexSessions, matchCodex } from "./codex.js";
import { Panel } from "./panel.js";

// The mods-hub can turn this mod off (shared "herdr-mods.disabled", a list of mod names). Then the mod draws
// nothing, closes its dialog and skips its timed work. The bars hide its blocks and buttons.
const kitOff = () => { const v = shared("herdr-mods.disabled"); return Array.isArray(v) && v.includes("agent-resume"); };
const offView = () => { const o = props()?.overlay; if (o) closeOverlay(o); return div(); };

// Time between 2 scans.
const SCAN_MS = 3000;
// An agent that stops its status for this long in the same shell has exited.
// The delay keeps the labels during a shutdown, when the agents stop before the shells.
const EXIT_MS = 10000;
// An agent with no labels for this long has no hook: record it without a session id.
const NO_HOOK_MS = 10000;

export default class AgentResume extends View {
  init(_p, cx) {
    // An overlay gets its props from props(), not from the init argument.
    if (props()?.panel) {
      this.panel = new Panel(cx);
      return;
    }
    this.firstSeen = {}; // "<address>#<pid>" -> time the mod first saw that new shell
    this.active = {}; // address -> true after the mod saw an agent status there
    this.quietSince = {}; // address -> time the agent status went away
    this.unlabeledSince = {}; // address -> time the mod first saw an agent with no labels
    this.agentSince = {}; // address -> time the agent started (0: it ran before the mod started)
    this.scans = 0;
    this.busy = false;
    this.lastCount = 0; // sessions resumed in the last scan that resumed any
    cx.timer.every(SCAN_MS, (cx) => kitOff() || this.scan(cx));
    this.scan(cx);
    // "agent-resume.panel" (a key in keys.json, or herdr-app do) opens the panel.
    cx.spawn(async () => {
      for (;;) {
        const c = await nextCommand();
        if (c === "panel") this.openPanel(false);
      }
    });
  }

  scan(cx) {
    if (this.busy) return;
    const c = config();
    const now = Date.now();
    const toResume = [];
    const toCheckExit = [];
    const toRefresh = [];
    const toForget = [];
    const list = labeled();
    const appOf = new Map(agents().map((a) => [a.address, agentForApp(a.app)]));
    for (const t of list) {
      // Another agent runs in this terminal now: the recorded session is not its session.
      const runs = appOf.get(t.address);
      if (t.status && runs && runs !== t.labels["resume.agent"]) {
        toForget.push(t);
        delete this.active[t.address];
        delete this.agentSince[t.address];
        continue;
      }
      if (t.status) {
        if (!this.active[t.address]) {
          // The agent started (or the mod started). The first scan cannot know when.
          // A terminal that the mod just recorded keeps the time it was first seen.
          if (!(t.address in this.agentSince)) this.agentSince[t.address] = this.scans === 0 ? 0 : now;
          toRefresh.push(t);
        }
        this.active[t.address] = true;
        delete this.quietSince[t.address];
        continue;
      }
      if (this.active[t.address]) {
        this.quietSince[t.address] ??= now;
        if (now - this.quietSince[t.address] >= EXIT_MS) toCheckExit.push(t);
        continue;
      }
      if (c.enabled) toResume.push(t);
    }
    const toRecord = this.unlabeledAgents(now, c.noHook);
    const codexTerms = list.filter((t) => t.status && t.labels["resume.agent"] === "codex");
    // The tab-namer mod writes namer.session=<session> when it names a tab. A new
    // session in the terminal (/clear, /new) makes that name old: clear it, and
    // the tab shows the agent's own title again.
    const toUnname = list.filter((t) => {
      const named = t.labels["namer.session"];
      const current = t.labels["resume.session"];
      return named && current && named !== current && t.labels["herdr.tab"];
    });
    this.scans++;

    this.busy = true;
    cx.spawn(async (cx) => {
      const resumed = [];
      try {
        for (const t of toForget) await forget(t.address);
        for (const t of toCheckExit) await this.checkExit(t);
        for (const t of toRefresh) await refreshPid(t.address);
        for (const a of toRecord) await recordWithoutHook(a.address, a.agent);
        if (codexTerms.length > 0) await this.matchCodex(codexTerms, list);
        for (const t of toUnname) {
          run("tab.rename", { id: t.labels["herdr.tab"], name: "" });
          await hc(["label", t.address, "namer.session="]);
        }
        for (const t of toResume) {
          if (await this.tryResume(t)) resumed.push(t);
        }
      } finally {
        this.busy = false;
      }
      if (resumed.length === 0) return;
      this.lastCount = resumed.length;
      if (config().toast) {
        const names = [...new Set(resumed.map((t) => AGENTS[t.labels["resume.agent"]].name))].join(", ");
        notify({
          title: resumed.length === 1 ? `${names} session resumed` : `${resumed.length} sessions resumed`,
          body: resumed.map((t) => t.labels?.where ?? t.address).join(", "),
          level: "success",
          timeout: 8000,
        });
      }
      cx.notify();
    });
  }

  // Codex: give each Codex terminal its session from the Codex session files.
  async matchCodex(codexTerms, list) {
    const sessions = await codexSessions();
    const terms = codexTerms.map((t) => ({
      address: t.address,
      cwd: t.cwd,
      session: t.labels["resume.session"] ?? "",
      since: this.agentSince[t.address] ?? 0,
    }));
    const taken = list
      .filter((t) => t.labels["resume.agent"] === "codex" && !codexTerms.includes(t))
      .map((t) => t.labels["resume.session"])
      .filter(Boolean);
    for (const change of matchCodex(terms, sessions, taken)) {
      await hc(["label", change.address, `resume.session=${change.id}`]);
    }
  }

  // Agents (with a pane, not sub-agents) that have no labels after NO_HOOK_MS.
  // Codex is always recorded (the mod finds its session). The others only with noHook on.
  unlabeledAgents(now, noHook) {
    const byAddress = new Map(terminals().map((t) => [t.address, t]));
    const found = [];
    const seen = new Set();
    for (const a of agents()) {
      const agent = agentForApp(a.app);
      const term = byAddress.get(a.address);
      if (!agent || !term || term.parent || term.labels?.["resume.agent"]) continue;
      if (agent !== "codex" && !noHook) continue;
      seen.add(a.address);
      // The first scan cannot know when the agent started: 0.
      this.unlabeledSince[a.address] ??= this.scans === 0 ? 0 : now;
      // Codex has no hook to wait for: record it at once, with the time it was first seen.
      const wait = agent === "codex" ? 0 : NO_HOOK_MS;
      if (now - (this.unlabeledSince[a.address] || now - NO_HOOK_MS) >= wait) {
        this.agentSince[a.address] = this.unlabeledSince[a.address];
        found.push({ address: a.address, agent });
      }
    }
    for (const address of Object.keys(this.unlabeledSince)) {
      if (!seen.has(address)) delete this.unlabeledSince[address];
    }
    return found;
  }

  // The agent status went away. If the shell is the same, the agent exited: forget it.
  async checkExit(t) {
    delete this.active[t.address];
    delete this.quietSince[t.address];
    delete this.agentSince[t.address];
    const info = await inspect(t.address);
    if (info && !info.status && sessionState(info) === "stopped") await forget(t.address);
  }

  // Returns true when the mod typed the resume command in the terminal.
  async tryResume(t) {
    const info = await inspect(t.address);
    // Only a new shell (other pid) after a loss.
    if (!info || sessionState(info) !== "waiting") return false;
    // Give the new shell time to show its prompt.
    const key = `${info.address}#${info.pid}`;
    const now = Date.now();
    if (!this.firstSeen[key]) this.firstSeen[key] = now;
    if (now - this.firstSeen[key] < config().settleMs) return false;
    return resumeNow(t.address);
  }

  // From a click: a popup at the pointer. From a key: a dialog in the center.
  openPanel(atPointer = true) {
    openOverlay({
      mod: "agent-resume",
      kind: atPointer ? "popup" : "dialog",
      ...(atPointer ? { at: "pointer" } : {}),
      width: 440,
      height: 520,
      props: { panel: true },
    });
  }

  render(cx) {
    if (kitOff()) return offView();
    if (this.panel) return this.panel.render(cx);
    const t = theme();
    const on = config().enabled;
    const count = labeled().length;
    const text = on
      ? `Resume on · ${count} ${count === 1 ? "session" : "sessions"}`
      : "Resume off";
    return h_flex()
      .id("agent-resume")
      .size_full()
      .pl(14)
      .gap(6)
      .items_center()
      .justify_start()
      .bg(t.chrome)
      .text_size(11.8)
      .text_color(t.muted)
      .cursor_pointer()
      .hover((s) => s.text_color(t.foreground))
      .tooltip(this.tooltip(on))
      .on_click(() => this.openPanel())
      .child(div().flex_none().size(7).rounded(4).bg(on ? t.ansi2 : t.dim))
      .child(div().truncate().child(text));
  }

  tooltip(on) {
    const last = this.lastCount > 0
      ? ` Last resume: ${this.lastCount} ${this.lastCount === 1 ? "session" : "sessions"}.`
      : "";
    return (on ? "Agent Resume monitors your agent sessions." : "Agent Resume is off.")
      + last + " Click to open the panel.";
  }
}
