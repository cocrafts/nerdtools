// Inbox: the focused session's worktree card State, and the handoff it was given if any.
// card.py finds them on the pane's machine through ~/nerdtools/claude/tools/wt.sh.
import { View, div } from "gpui-kit";
import { v_flex, h_flex, Scrollbar } from "gpui-base";
import { appHome, exec, focused, hc, readTextFile, theme } from "herdr";

// "Next: …", "In flight: …": the card's State labels, drawn apart from their text.
const LABEL = /^(\s*[-*]?\s*)([A-Z][A-Za-z ]{1,30}):(\s|$)/;

const age = (sec) => {
  const s = Date.now() / 1000 - sec;
  return s < 3600 ? `${Math.max(1, Math.floor(s / 60))}m` : s < 86400 ? `${Math.floor(s / 3600)}h` : `${Math.floor(s / 86400)}d`;
};

export default class Inbox extends View {
  init(_props, cx) {
    this.data = null;
    this.address = null;
    cx.spawn(async (cx) => {
      this.src = await readTextFile(`${appHome()}/mods/my-inbox/card.py`);
      await this.refresh(cx);
    });
    cx.timer.every(4000, (cx) => this.refresh(cx));
  }

  async refresh(cx) {
    if (!this.src || this.busy) return;
    const f = focused();
    const address = f?.terminal ?? null;
    if (address !== this.address) {
      this.address = address;
      this.data = null;
      cx.notify();
    }
    if (!address) return;
    this.busy = true;
    try {
      const info = JSON.parse((await hc(["get", address, "--json"])).stdout);
      const machine = address.includes("/") ? address.split("/")[0] : null;
      const pid = String(info.foreground?.pid ?? info.pid ?? "");
      const r = await exec("python3", ["-c", this.src, pid, f.cwd ?? "", this.data?.key ?? ""], { on: machine, timeout: 20000 });
      const out = JSON.parse(r.stdout);
      if (address === this.address && !out.same) this.data = out;
    } catch (e) {
      if (address === this.address) this.data = { error: String(e) };
    } finally {
      this.busy = false;
    }
    cx.notify();
  }

  render(_cx) {
    const t = theme();
    const d = this.data;
    const lines = (text) => text.split("\n").map((s, i) => {
      if (!s.trim()) return div().id(`gap-${i}`).h(6);
      const m = s.match(LABEL);
      if (!m) return div().w_full().text_size(12).text_color(t.muted).child(s);
      return h_flex().w_full().gap(4).items_start().text_size(12)
        .child(div().flex_none().font_medium().text_color(t.foreground).child(`${m[1]}${m[2]}:`))
        .child(div().flex_1().min_w(0).text_color(t.muted).child(s.slice(m[0].length)));
    });
    const section = (title, meta, text) => v_flex().gap(2)
      .child(h_flex().gap(6).items_center().pb(4)
        .child(div().text_size(11).font_medium().text_color(t.dim).child(title.toUpperCase()))
        .when(Boolean(meta), (e) => e.child(div().text_size(11).text_color(t.dim).child(meta))))
      .children(lines(text));
    const note = !this.address ? "Focus a pane" : !d ? "Reading…" : d.error ? `No card: ${d.error}` : d.none ? `No worktree card here: ${d.none}` : null;
    return v_flex().size_full().bg(t.background).text_size(13)
      // The terminal pane's header (mods/pane): 30 high, 12px medium.
      .child(h_flex().h(30).flex_none().px(10).gap(8).items_center().border_b(1).border_color(t.border).text_size(12)
        .child(div().font_medium().text_color(t.foreground).child("Inbox"))
        .when(Boolean(d?.name), (e) => e.child(div().px(5).py(1).rounded(4).border_1().border_color(t.border).text_size(10).text_color(t.muted).child(d.name))))
      // As my-timeline: the bottom clears the toasts that float over this corner.
      .child(div().flex_1().min_h(0).relative().mb(100)
        .child(v_flex().id("inbox-body").absolute().inset_0().overflow_y_scroll().px(14).py(10).gap(18)
          .when(Boolean(note), (e) => e.child(div().text_color(t.dim).child(note)))
          .when(!note, (e) => e
            .child(section("State", null, d.state || "(empty)"))
            .when(Boolean(d.handoff), (e) => e.child(section("Handoff", d.delivered ? `delivered · ${age(d.handoff_mtime)}` : `waiting · ${age(d.handoff_mtime)}`, d.handoff)))))
        .child(Scrollbar.vertical("inbox-body").absolute().inset_0()));
  }
}
