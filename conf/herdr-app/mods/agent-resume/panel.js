// The panel of agent-resume: the config and the list of recorded sessions.
// main.js shows it when the mod opens as a popup with props { panel: true }.

import { div } from "gpui-kit";
import { h_flex, v_flex } from "gpui-base";
import { theme, props, closeOverlay } from "herdr";
import {
  AGENTS, config, setConfig, labeled, inspect, sessionState, resumeNow, forget,
  SETTLE_MIN_MS, SETTLE_MAX_MS,
} from "./resume.js";

const REFRESH_MS = 2000;

const STATE_TEXT = {
  active: "active",
  waiting: "waiting for resume",
  failed: "resume failed",
  stopped: "stopped",
};

export class Panel {
  constructor(cx) {
    this.infos = {}; // address -> full terminal record
    this.busy = {}; // address -> true while a button runs
    this.message = null;
    cx.timer.every(REFRESH_MS, (cx) => this.refresh(cx));
    this.refresh(cx);
  }

  refresh(cx) {
    cx.spawn(async (cx) => {
      const next = {};
      for (const t of labeled()) {
        const info = await inspect(t.address);
        if (info) next[t.address] = info;
      }
      this.infos = next;
      cx.notify();
    });
  }

  act(cx, address, fn, done) {
    if (this.busy[address]) return;
    this.busy[address] = true;
    cx.notify();
    cx.spawn(async (cx) => {
      let ok = false;
      try {
        ok = await fn(address);
      } finally {
        this.busy[address] = false;
      }
      this.message = ok ? done : "The command did not run. Is a shell open in that terminal?";
      this.refresh(cx);
    });
  }

  render(_cx) {
    const t = theme();
    const c = config();
    const rows = labeled().map((term) => this.infos[term.address] ?? term);

    return v_flex()
      .id("agent-resume-panel")
      .size_full()
      .bg(t.popover)
      .text_size(12.5)
      .text_color(t.foreground)
      .child(this.header(t))
      .child(this.section(t, "Settings"))
      .child(this.settingRow(t, "Auto resume", "Type the resume command in each new shell after a reboot.",
        this.toggle(t, "set-enabled", c.enabled, () => setConfig({ enabled: !c.enabled }))))
      .child(this.settingRow(t, "Shell wait", "Time a new shell gets before the mod types in it.",
        this.stepper(t, c.settleMs)))
      .child(this.settingRow(t, "Toast", "Show a notification after a resume.",
        this.toggle(t, "set-toast", c.toast, () => setConfig({ toast: !c.toast }))))
      .child(this.settingRow(t, "Agents without a hook", "Record them too, and resume the last session in the folder.",
        this.toggle(t, "set-nohook", c.noHook, () => setConfig({ noHook: !c.noHook }))))
      .child(this.section(t, `Monitored sessions (${rows.length})`))
      .child(
        v_flex()
          .id("agent-resume-list")
          .flex_1()
          .overflow_y_scrollbar()
          .px(14)
          .pb(8)
          .gap(6)
          .when(rows.length === 0, (el) => el.child(
            div().py(10).text_color(t.muted)
              .child("No agent session is recorded. Start an agent in a terminal of Herdr."),
          ))
          .children(rows.map((info) => this.sessionRow(t, info))),
      )
      .child(
        div().px(14).py(8).border_t(1).border_color(t.border).text_size(11.5).text_color(t.dim)
          .child(this.message ?? "Without a hook, the mod resumes the last session in the folder."),
      );
  }

  header(t) {
    return h_flex()
      .px(14).py(10).items_center().justify_between()
      .border_b(1).border_color(t.border)
      .child(
        h_flex().gap(8).items_center()
          .child(div().size(8).rounded(4).bg(config().enabled ? t.ansi2 : t.dim))
          .child(div().font_semibold().text_size(13.5).child("Agent Resume")),
      )
      .child(
        div().id("close").px(6).rounded(4).text_color(t.muted).cursor_pointer()
          .hover((s) => s.bg(t.hover).text_color(t.foreground))
          .on_click(() => closeOverlay(props().overlay))
          .child("✕"),
      );
  }

  section(t, title) {
    return div().px(14).pt(12).pb(6).text_size(11).font_semibold().text_color(t.muted).child(title.toUpperCase());
  }

  settingRow(t, title, hint, control) {
    return h_flex()
      .px(14).py(5).gap(12).items_center().justify_between()
      .child(
        v_flex().flex_1().gap(1)
          .child(div().child(title))
          .child(div().text_size(11.5).text_color(t.dim).child(hint)),
      )
      .child(control);
  }

  toggle(t, id, on, onClick) {
    return div()
      .id(id).flex_none().w(34).h(18).rounded(9).p(2).cursor_pointer()
      .bg(on ? t.accent : t.input)
      .on_click(onClick)
      .child(
        h_flex().size_full().when(on, (el) => el.justify_end())
          .child(div().size(14).rounded(7).bg(on ? t.accent_foreground : t.muted)),
      );
  }

  stepper(t, ms) {
    const set = (v) => setConfig({ settleMs: Math.min(SETTLE_MAX_MS, Math.max(SETTLE_MIN_MS, v)) });
    const button = (id, label, delta) => div()
      .id(id).w(22).h(22).rounded(4).flex().items_center().justify_center().cursor_pointer()
      .border(1).border_color(t.border).text_color(t.muted)
      .hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_click(() => set(ms + delta))
      .child(label);
    return h_flex().flex_none().gap(6).items_center()
      .child(button("settle-down", "−", -1000))
      .child(div().w(34).flex().justify_center().child(`${Math.round(ms / 1000)} s`))
      .child(button("settle-up", "+", 1000));
  }

  sessionRow(t, info) {
    const l = info.labels ?? {};
    const address = info.address;
    const state = info.pid !== undefined ? sessionState(info) : "active";
    const color = { active: t.ansi2, waiting: t.working, failed: t.blocked, stopped: t.dim }[state];
    const agent = AGENTS[l["resume.agent"]]?.name ?? l["resume.agent"];
    const sid = l["resume.session"] ? l["resume.session"].slice(0, 8) : "last session";
    const flags = l["resume.args"] ? ` · ${l["resume.args"]}` : "";
    const busy = this.busy[address];

    return h_flex()
      .id(`row-${address}`)
      .px(10).py(7).gap(10).items_center()
      .rounded(6).bg(t.surface).border(1).border_color(t.border)
      .child(
        v_flex().flex_1().gap(2).overflow_hidden()
          .child(h_flex().gap(6).items_center()
            .child(div().flex_none().size(7).rounded(4).bg(color))
            .child(div().truncate().font_semibold().child(l.where ?? address)))
          .child(div().truncate().text_size(11.5).text_color(t.muted).child(`${agent} · ${address}`))
          .child(div().truncate().text_size(11.5).text_color(t.dim).child(`${sid}${flags}`))
          .child(div().text_size(11.5).text_color(color).child(STATE_TEXT[state])),
      )
      .child(
        h_flex().flex_none().gap(6)
          .when(state !== "active", (el) => el.child(
            this.button(t, `resume-${address}`, busy ? "…" : "Resume", true,
              (_e, cx) => this.act(cx, address, resumeNow, "The resume command was typed.")),
          ))
          .child(this.button(t, `forget-${address}`, "Forget", false,
            (_e, cx) => this.act(cx, address, forget, "The session is not monitored now."))),
      );
  }

  button(t, id, label, primary, onClick) {
    return div()
      .id(id).px(8).py(3).rounded(5).cursor_pointer().text_size(11.5)
      .bg(primary ? t.solid : t.raised)
      .text_color(primary ? t.solid_foreground : t.foreground)
      .hover((s) => s.bg(primary ? t.accent : t.hover))
      .on_click(onClick)
      .child(label);
  }
}
