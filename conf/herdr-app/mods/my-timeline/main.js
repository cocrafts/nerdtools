// Timeline: the prompts of the focused agent's conversation, oldest first, with what each
// took. Claude Code and Pi, on any machine: timeline.py reads the transcript there.
import { View, div } from "gpui-kit";
import { v_flex, h_flex, Scrollbar, v_virtual_list, VirtualListScrollHandle } from "gpui-base";
import { agents, appHome, exec, focused, hc, layout, readTextFile, theme } from "herdr";

const clock = (at) => new Date(at).toTimeString().slice(0, 5);
const took = (ms) => (ms < 60000 ? `${Math.max(0, Math.round(ms / 1000))}s` : ms < 3600000 ? `${Math.floor(ms / 60000)}m` : `${Math.floor(ms / 3600000)}h${String(Math.floor((ms % 3600000) / 60000)).padStart(2, "0")}m`);
const count = (n) => (n >= 1000 ? `${(n / 1000).toFixed(1)}k` : String(n));

// Only a virtual list can be scrolled from code, and it places rows by heights stated up
// front, so a card is built from one-line rows of fixed height, wrapped here by width.
const LINE = { text: 19, meta: 16, reply: 17 };
const PAD = 8, GAP = 3, SPACING = 6;
const CHAR_PX = 6.4; // measured 5.9 for the 13px UI font; the slack keeps wide letters inside
const SHUT = { text: 3, reply: 1 };
const MAX = 80;

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

function wrap(s, cols) {
  const out = [];
  for (const para of s.split("\n")) {
    let line = "";
    for (const word of para.split(/\s+/).filter(Boolean)) {
      for (let w = word; w; ) {
        const room = line ? cols - line.length - 1 : cols;
        if (w.length <= room) { line = line ? `${line} ${w}` : w; w = ""; }
        else if (line) { out.push(line); line = ""; }
        else { out.push(w.slice(0, cols)); w = w.slice(cols); }
      }
    }
    if (line || out.at(-1) !== "") out.push(line);
  }
  while (out.at(-1) === "") out.pop();
  return out;
}

function shut(lines, n) {
  if (lines.length <= n) return lines;
  return [...lines.slice(0, n - 1), `${lines[n - 1]}…`];
}

export default class Timeline extends View {
  init(_props, cx) {
    this.data = null;
    this.address = null;
    this.open = new Set();
    this.scroll = VirtualListScrollHandle.new();
    cx.spawn(async (cx) => {
      this.src = await readTextFile(`${appHome()}/mods/my-timeline/timeline.py`);
      await this.refresh(cx);
    });
    cx.timer.every(3000, (cx) => this.refresh(cx));
  }

  async refresh(cx) {
    if (!this.src || this.busy) return;
    const address = focused()?.terminal ?? null;
    const agent = agents().find((a) => a.address === address);
    if (address !== this.address) {
      this.address = address;
      this.data = null;
      this.open.clear();
      cx.notify();
    }
    if (!agent) return;
    this.busy = true;
    try {
      const info = JSON.parse((await hc(["get", address, "--json"])).stdout);
      const machine = address.includes("/") ? address.split("/")[0] : null;
      const args = ["-c", this.src, agent.app ?? "", String(info.foreground?.pid ?? ""), info.labels?.["resume.session"] ?? "", this.data?.key ?? ""];
      const r = await exec("python3", args, { on: machine, timeout: 15000 });
      const out = JSON.parse(r.stdout);
      if (address === this.address && !out.same) {
        // A new prompt, or the last one growing when its first reply comes.
        const tail = (x) => { const p = x?.prompts?.at(-1); return p && `${p.n}|${Boolean(p.reply)}`; };
        const fresh = tail(out) !== tail(this.data);
        this.data = out;
        // After the frame that lays out the new rows, or the list has no bottom to go to yet.
        if (fresh) cx.timer.after(50, (cx) => { this.scroll.scroll_to_bottom(); cx.notify(); });
      }
    } catch (e) {
      if (address === this.address) this.data = { error: String(e) };
    } finally {
      this.busy = false;
    }
    cx.notify();
  }

  render(_cx) {
    const t = theme();
    const agent = agents().find((a) => a.address === this.address);
    const d = this.data;
    const prompts = d?.prompts ?? [];
    const note = !agent ? "Focus an agent to see its prompts" : !d ? "Reading…" : d.error ? `No timeline: ${d.error} (Claude Code and Pi)` : prompts.length ? null : "No prompts yet";
    // The panel as drawn (its stored size clamped to its min and max), less the list's
    // padding and the card's padding.
    const panel = find(layout(), "panel");
    const drawn = Math.min(panel?.max ?? Infinity, Math.max(panel?.min ?? 0, panel?.size?.px ?? 368));
    const width = drawn - 20 - 2 * PAD;
    const cols = Math.max(20, Math.floor(width / CHAR_PX));
    const cards = prompts.map((p, i) => {
      const live = i === prompts.length - 1 && agent?.status === "working";
      const open = this.open.has(p.n);
      const text = wrap(p.text, cols), reply = wrap(p.reply, cols + 2);
      const lines = {
        text: open ? text.slice(0, MAX) : shut(text, SHUT.text),
        reply: open ? reply.slice(0, MAX) : shut(reply, SHUT.reply),
      };
      const rows = [LINE.meta, ...lines.text.map(() => LINE.text), LINE.meta, ...lines.reply.map(() => LINE.reply)];
      const height = 2 * PAD + rows.reduce((a, b) => a + b, 0) + GAP * (rows.length - 1) + SPACING;
      return { p, i, live, open, lines, height };
    });
    const line = (s, h, size, color) => div().h(h).flex_none().truncate().text_size(size).text_color(color).child(s || " ");
    const card = ({ p, i, live, open, lines, height }) =>
      h_flex().h(height).pb(SPACING).cursor_pointer()
        .child(v_flex().flex_1().min_w(0).h_full().gap(GAP).p(PAD).rounded(8).when(open || i === prompts.length - 1, (e) => e.bg(t.hover)).hover((s) => s.bg(t.hover))
          .child(line(`#${p.n}  ${clock(p.at)}`, LINE.meta, 11, t.dim))
          .children(lines.text.map((s) => line(s, LINE.text, 13, t.foreground)))
          .child(line(`${live ? `working · ${took(Date.now() - Date.parse(p.at))}` : `done ${clock(p.done)} · ${took(Date.parse(p.done) - Date.parse(p.at))}`} · ↓ ${count(p.tokens)} tokens · ${p.tools} tools`, LINE.meta, 11, live ? t.ansi3 : t.dim))
          .children(lines.reply.map((s) => line(s, LINE.reply, 12, t.muted))));
    return v_flex().size_full().bg(t.background).text_size(13)
      // The terminal pane's header (mods/pane): 30 high, 12px medium.
      .child(h_flex().h(30).flex_none().px(10).gap(8).items_center().border_b(1).border_color(t.border).text_size(12)
        .child(div().font_medium().text_color(t.foreground).child("Timeline"))
        .when(Boolean(d?.total), (e) => e.child(div().px(5).py(1).rounded(4).border_1().border_color(t.border).text_size(10).text_color(t.muted).child(`${d.total} prompts`)))
        .child(div().flex_1())
        .when(Boolean(d?.context), (e) => e.child(div().text_size(11).text_color(t.dim).child(`context ${count(d.context)}`))))
      // Padding outside the list: the list's own is not counted when it scrolls to the bottom.
      // The bottom clears the toasts that float over this corner.
      .child(div().flex_1().min_h(0).relative().mt(10).mb(100)
        .when(Boolean(note), (e) => e.child(div().p(18).text_color(t.dim).child(note)))
        .when(!note, (e) => e
          .child(v_virtual_list("timeline-list", cards.length, cards.map((c) => c.height), (i) => String(cards[i].p.n),
            (range) => cards.slice(range.start, range.end).map(card))
            .track_scroll(this.scroll).absolute().inset_0().px(10)
            .on_item_click((key, cx) => { const n = Number(key); this.open.has(n) ? this.open.delete(n) : this.open.add(n); cx.notify(); }))
          .child(Scrollbar.vertical("timeline-list").absolute().inset_0())));
  }
}
