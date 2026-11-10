// Key commands that need more than one app command, or the agents list's order.
// Lives in a zero-size block that is always shown, so the keys work with the sidebar hidden:
// `<mod>.<command>` reaches shown copies only.

import { View, div } from "gpui-kit";
import { agents, run, shared, nextCommand, notify, focused, panes, terminals, hc } from "herdr";

const BUILD = Symbol("build");

// pane.split only goes right or down; left and up then move the old pane past the new one.
const SPLITS = {
  splitleft: ["right", true],
  splitdown: ["down", false],
  splitup: ["down", true],
  splitright: ["right", false],
};

// Side panels (my-main's panel-body stack) a key opens on, whatever the panel showed.
const PANELS = new Set(["inbox", "timeline"]);

// Pane moves that go through Vim first, as conf/herdr/vim-herdr-navigation does for the TUI:
// in a pane running Vim the key goes to it, and Vim at its split edge asks back for the pane
// move by setting the label NAV_LABEL on its terminal (editor/nvim.lua), which works for a
// Vim on another machine too.
const NAV = { navleft: "left", navdown: "down", navup: "up", navright: "right" };
const NAV_KEY = { left: "h", down: "j", up: "k", right: "l" };
const NAV_LABEL = "herdr.nav";
const VIM = new Set(["nvim", "vim"]);

async function navigate(direction) {
  const pane = panes().find((p) => p.focused);
  if (!pane?.terminal || !VIM.has(pane.program?.key)) return run("pane.go", { direction });
  // Ctrl: the one modifier editor/nvim.lua maps on every OS (vim.g.herdr_nav_mods in
  // nvim/lua/utils/plugins.lua), so a Vim on the other machine takes it too.
  const chord = `ctrl+${NAV_KEY[direction]}`;
  const r = await hc(["keys", pane.terminal, chord]);
  if (r.code !== 0) notify({ title: "my-keys", body: `hc keys ${pane.terminal} ${chord}: ${r.stderr}`, level: "error" });
}

// The last NAV_LABEL value seen per terminal; a change on the focused one is a request.
const navSeen = new Map();
function watchNav() {
  const now = focused()?.terminal;
  for (const term of terminals()) {
    const value = term.labels?.[NAV_LABEL] ?? null;
    const before = navSeen.get(term.address);
    navSeen.set(term.address, value);
    if (before === undefined || value === before || !value || term.address !== now) continue;
    const direction = value.split(":")[0];
    if (!Object.values(NAV).includes(direction)) return notify({ title: "my-keys", body: `${term.address}: bad ${NAV_LABEL}=${value}`, level: "error" });
    run("pane.go", { direction });
  }
}

async function handle(c, cx) {
  if (c in NAV) return navigate(NAV[c]);
  if (PANELS.has(c)) {
    run("layout.select", { stack: "panel-body", child: c });
    return run("layout.show", { id: "panel" });
  }
  const agent = c.match(/^agent([1-9])$/);
  if (agent) {
    const order = shared("agents.order") ?? agents().map((a) => a.address);
    const address = order[Number(agent[1]) - 1];
    if (address) run("agent.focus", { terminal: address });
    return;
  }
  const split = SPLITS[c];
  if (!split) return notify({ title: "my-keys", body: `unknown command: ${c}`, level: "error" });
  const [direction, behind] = split;
  const old = focused()?.pane;
  const tab = panes().find((p) => p.pane === old)?.tab;
  const before = new Set(panes().map((p) => p.pane));
  run("pane.split", { direction });
  if (!behind || !old) return;
  // run() only queues; the new pane appears once the core has made its terminal.
  for (let waited = 0; waited < 1500; waited += 30) {
    if (panes().some((p) => p.tab === tab && !before.has(p.pane))) return run("pane.swap", { pane: old, direction });
    await cx.sleep(30);
  }
  notify({ title: "my-keys", body: `${c}: the new pane did not appear within 1.5 s`, level: "error" });
}

export default class Keys extends View {
  render(cx) {
    // Reloading a mod in place keeps the instance but not its tasks: listen once per build.
    if (this.listening !== BUILD) {
      this.listening = BUILD;
      cx.spawn(async (cx) => {
        for (;;) {
          await handle(await nextCommand(), cx);
          cx.notify();
        }
      });
    }
    watchNav();
    return div();
  }
}
