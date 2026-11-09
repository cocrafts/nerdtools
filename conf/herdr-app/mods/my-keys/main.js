// Key commands that need more than one app command, or the agents list's order.
// Lives in a zero-size block that is always shown, so the keys work with the sidebar hidden:
// `<mod>.<command>` reaches shown copies only.

import { View, div } from "gpui-kit";
import { agents, run, shared, nextCommand, notify, focused, panes } from "herdr";

const BUILD = Symbol("build");

// pane.split only goes right or down; left and up then move the old pane past the new one.
const SPLITS = {
  splitleft: ["right", true],
  splitdown: ["down", false],
  splitup: ["down", true],
  splitright: ["right", false],
};

async function handle(c, cx) {
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
    return div();
  }
}
