/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
﻿import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { ScheduleData, CourseItem } from '../common/ScheduleTypes';
import { parseSchedule } from '../service/ScheduleParse';
import { PERIOD_START, PERIOD_END } from '../common/Periods';
import { PrefsStore } from '../common/PrefsStore';
import { THEME_DEFAULT, isDecoratedTheme, themeDef } from '../common/ThemeConfig';
import { CardSync } from '../service/CardSync';

/**
 * 卡片数据，一套数据供两族卡片渲染：
 *
 * 「此刻卡」ScheduleTiny / ScheduleSmall / ScheduleLarge
 *   整卡浅色底 + 一张白卡，用 hero* 回答"现在或下一节上什么"，
 *   下面的 slots 只是陪衬（会自动跳过主视觉那一条）。
 *
 * 「列表卡」ScheduleListSmall / ScheduleListLarge
 *   旧版白底 + 彩色块的版式，不显示任何"上课中/下节"的结论，
 *   只按时间顺序列出「还没上完的课」，上完一节少一条；
 *   今天的课上完了，整卡切到明天（state = tomorrow）。
 *
 * slots 的语义统一是「还没上完的全部课程（含正在上的那一节）」，
 * 列表卡直接用，此刻卡自己跳过第一条。
 */
class CardData {
  /** 顶部小字：默认「10月29日 周三」，切到明天预告时改成「今天上完了」 */
  head: string = '';
  /** now=上课中 / next=课间 / done=已上完 / none=今天没课 / tomorrow=明天预告 */
  state: string = 'none';
  /** 主视觉：左上标签（上课中/下节/明天…） */
  heroTag: string = '';
  heroName: string = '';
  heroTime: string = '';
  heroPlace: string = '';
  /** 主视觉右下角提示：「还剩 55 分钟」「还有 2 小时 35 分」「共 3 节」 */
  heroNote: string = '';
  /** 上课进度 0-100；-1 表示不显示进度条 */
  progress: number = -1;
  /** 列表卡抬头，如「今天还有 3 节」「明天 · 共 4 节」 */
  listLabel: string = '';
  /** 大卡右上角统计，如「共 6 节 · 还剩 3 节」 */
  summary: string = '';
  /** 状态色：accent 用于标签/圆点/进度条，tint 为整卡底色，ink 为卡内正文色 */
  accent: string = '#8A94A6';
  tint: string = '#F0F2F6';
  ink: string = '#232A36';
  /** 豆泥主题时为 'douni'：卡片跟着换暖色系并显示贴纸；默认主题为空 */
  theme: string = '';
  /** 贴纸槽位（卡片侧据此选图，资源名不能拼接所以只能传语义）：rest/empty/success/passive */
  mascot: string = 'passive';
  /** 下一次该刷新卡片的分钟数（下课那一刻），<=0 表示不用单独定时 */
  nextMin: number = -1;
  t0: string = ''; n0: string = ''; p0: string = ''; f0: string = '';
  t1: string = ''; n1: string = ''; p1: string = ''; f1: string = '';
  t2: string = ''; n2: string = ''; p2: string = ''; f2: string = '';
  t3: string = ''; n3: string = ''; p3: string = ''; f3: string = '';
  t4: string = ''; n4: string = ''; p4: string = ''; f4: string = '';
  t5: string = ''; n5: string = ''; p5: string = ''; f5: string = '';
  t6: string = ''; n6: string = ''; p6: string = ''; f6: string = '';
  t7: string = ''; n7: string = ''; p7: string = ''; f7: string = '';
}

/** 每一节的起止时间（学校作息）统一放在 common/Periods.ets，提醒模块也用同一份 */
// 课程字色、明天预告色、各状态三色都移到 ThemeConfig 的 CardPalette，按主题查表。

/**
 * 课表桌面卡片的数据提供者（此刻卡 1×2/2×2/2×4 + 列表卡 2×2/2×4 共用）。
 *
 * slots 从索引 0 开始按时间顺序放「还没上完的课」，所以：
 *   - 列表卡：直接整列显示，上完一节就少一条；上完了整列换成明天的课；
 *   - 此刻卡：主视觉已经占用了第 0 条，列表从第 1 条开始渲染。
 */
export default class ScheduleCardAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const d: CardData = this.buildData();
    // 记录 formId：应用侧切主题时要遍历这些 id 主动刷新（getFormsInfo 不含运行时 formId）
    try {
      const id = want.parameters?.['ohos.extra.param.key.form_identity'];
      if (id !== undefined) {
        CardSync.addFormId(this.context, String(id));
      }
    } catch (err) {
      // 忽略
    }
    this.armTimer(want, d.nextMin);
    return formBindingData.createFormBindingData(d);
  }

  onRemoveForm(formId: string): void {
    CardSync.removeFormId(this.context, formId);
  }

  onUpdateForm(formId: string): void {
    try {
      // 补录 formId：老版本添加的卡片没走过新版 onAddForm，id 没进列表，
      // 应用侧切主题 refreshAllForms 就刷不到它。系统定时/下拉刷新会带真实 id 进来，
      // 这里顺势登记，旧卡也能被纳入即时刷新范围。
      CardSync.addFormId(this.context, formId);
      const d: CardData = this.buildData();
      const obj: formBindingData.FormBindingData = formBindingData.createFormBindingData(d);
      formProvider.updateForm(formId, obj).then(() => {
        this.armNext(formId, d.nextMin);
      }).catch(() => {
        // 忽略
      });
    } catch (err) {
      // 忽略
    }
  }

  /** 新增卡片时拿不到 formId，只能从 want 里取，取不到就交给 onUpdateForm 兜底 */
  private armTimer(want: Want, minutes: number): void {
    try {
      const p = want.parameters;
      if (p === undefined) {
        return;
      }
      const id = p['ohos.extra.param.key.form_identity'];
      if (id !== undefined) {
        this.armNext(String(id), minutes);
      }
    } catch (err) {
      // 忽略
    }
  }

  /**
   * 在"下课那一刻"单独排一次刷新，让那一节课准点从列表里消失，
   * 不用等默认的 30 分钟周期。失败（配额/权限）就退回默认周期，不影响显示。
   */
  private armNext(formId: string, minutes: number): void {
    if (minutes <= 0) {
      return;
    }
    try {
      formProvider.setFormNextRefreshTime(formId, minutes).catch(() => {
        // 忽略
      });
    } catch (err) {
      // 忽略
    }
  }

  /** 唯一的对外出口：数据算完再统一上色，避免每个分支各写一遍 */
  private buildData(): CardData {
    const d: CardData = this.buildDataInner();
    this.paint(d);
    // 贴纸按语义槽位走：没课/周末=休息，课表空=空，上完=庆祝，其余=待着。
    if (d.state === 'none' || d.state === 'tomorrow') {
      d.mascot = 'rest';
    } else if (d.state === 'done') {
      d.mascot = 'success';
    } else {
      d.mascot = 'passive';
    }
    return d;
  }

  private buildDataInner(): CardData {
    const d: CardData = new CardData();
    // 卡片进程读不到 AppStorage，主题从共享 preferences 同步读；
    // 拿到后随数据下发给卡片，卡片据此换色 / 显示贴纸 / 选课程色板。
    try {
      const t: string = PrefsStore.getThemeSync(this.context);
      // 默认主题沿用空字符串（widget 里 '' 即默认），其余主题下发 id 供查表
      d.theme = isDecoratedTheme(t) ? t : '';
    } catch (err) {
      // 读不到就当默认主题，卡片照常显示
    }
    d.head = `${this.dateText()} ${this.weekdayText()}`;
    d.state = 'none';
    d.heroTag = '没课';
    d.heroName = '今天没有课';
    d.heroNote = '好好休息';
    d.listLabel = '今天没课';
    try {
      const path: string = this.context.filesDir + '/schedule.json';
      if (!fileIo.accessSync(path)) {
        d.heroTag = '空课表';
        d.heroName = '还没导入课表';
        d.heroNote = '点开导入';
        d.listLabel = '还没导入课表';
        d.summary = d.listLabel;
        return d;
      }
      const size: number = fileIo.statSync(path).size;
      const buf = new ArrayBuffer(size);
      const f = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      fileIo.readSync(f.fd, buf);
      fileIo.closeSync(f);
      const txt: string = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf));
      const s: ScheduleData = parseSchedule(txt);
      const today: number = this.todayIndex();
      // 周末也往后找最近有课的工作日；实在找不到才留一句"最近都没课"
      if (today < 0) {
        if (this.fillNextDay(d, s, '')) {
          return d;
        }
        d.heroTag = '假期';
        d.heroName = '最近都没课';
        d.heroNote = '好好休息';
        d.listLabel = '最近都没课';
        d.summary = d.listLabel;
        return d;
      }
      const todayList: CourseItem[] = [];
      for (let i = 0; i < s.courses.length; i++) {
        if (s.courses[i].day === today) {
          todayList.push(s.courses[i]);
        }
      }
      todayList.sort((a: CourseItem, b: CourseItem): number => a.start - b.start);
      if (todayList.length === 0) {
        // 今天没课就往后找：明天 → 后天 → 下周最近一天，卡片直接显示那天有课。
        if (this.fillNextDay(d, s, '')) {
          return d;
        }
        d.heroTag = '没课';
        d.heroName = '最近都没课';
        d.heroNote = '好好休息';
        d.listLabel = '最近都没课';
        d.summary = d.listLabel;
        return d;
      }

      const now: number = this.nowMinutes();
      const remaining: CourseItem[] = [];
      let current: CourseItem | null = null;
      for (let i = 0; i < todayList.length; i++) {
        const c: CourseItem = todayList[i];
        const end: number = this.endMinutes(c);
        if (end <= now) {
          // 已经上完的课不进列表 —— 这就是"上完一节少一条"
          continue;
        }
        remaining.push(c);
        if (this.startMinutes(c) <= now) {
          current = c;
        }
      }

      if (remaining.length === 0) {
        // 今天的课上完了：整列换成明天的课
        if (this.fillNextDay(d, s, '今天上完了')) {
          return d;
        }
        d.state = 'done';
        d.heroTag = '已结束';
        d.heroName = '今天的课上完了';
        d.heroNote = `共 ${todayList.length} 节`;
        d.listLabel = '今天的课上完了';
        d.summary = `共 ${todayList.length} 节 · 全部上完`;
        return d;
      }

      // 主视觉的文案（此刻卡用，列表卡完全不渲染）
      if (current !== null) {
        const start: number = this.startMinutes(current);
        const end: number = this.endMinutes(current);
        d.state = 'now';
        d.heroTag = '上课中';
        d.heroName = current.name;
        d.heroTime = this.timeRange(current.start, current.span);
        d.heroPlace = current.place;
        d.heroNote = `还剩 ${this.durText(end - now)}`;
        d.nextMin = this.clampMin(end - now + 1);
        if (end > start) {
          d.progress = Math.min(100, Math.max(0, Math.round((now - start) * 100 / (end - start))));
        }
      } else {
        const nxt: CourseItem = remaining[0];
        d.state = 'next';
        d.heroTag = '下节';
        d.heroName = nxt.name;
        d.heroTime = this.timeRange(nxt.start, nxt.span);
        d.heroPlace = nxt.place;
        d.heroNote = `还有 ${this.durText(this.startMinutes(nxt) - now)}`;
        d.nextMin = this.clampMin(this.startMinutes(nxt) - now);
      }

      d.summary = `共 ${todayList.length} 节 · 还剩 ${remaining.length} 节`;
      d.listLabel = `今天还有 ${remaining.length} 节`;

      // 列表：还没上完的全部课程，含正在上/下一节
      const palette: string[] = themeDef(d.theme).card.courseFg;
      for (let i = 0; i < remaining.length && i < 8; i++) {
        const c: CourseItem = remaining[i];
        this.setSlot(d, i, this.timeRange(c.start, c.span), c.name, c.place, palette[i % palette.length]);
      }
      return d;
    } catch (err) {
      return d;
    }
  }

  /** 从明天开始，列出未来两周内所有工作日相对今天的天数 */
  private upcomingOffsets(): number[] {
    const out: number[] = [];
    const base: Date = new Date();
    base.setHours(0, 0, 0, 0);
    for (let step = 1; step <= 14; step++) {
      const dt: Date = new Date(base.getTime());
      dt.setDate(base.getDate() + step);
      const wd: number = dt.getDay();
      if (wd !== 0 && wd !== 6) {
        out.push(step);
      }
    }
    return out;
  }

  private dayLabel(offset: number, day: number): string {
    if (offset === 1) { return '明天'; }
    if (offset === 2) { return '后天'; }
    const names: string[] = ['一', '二', '三', '四', '五'];
    return day >= 0 && day < names.length ? `周${names[day]}` : '下周';
  }

  /**
   * 往后找最近有课的一天：明天 → 后天 → 再往后最近的工作日。
   * 找不到才返回 false，由调用方留一句"最近都没课"。
   *
   * @param head 顶部小字；传空串时用「X天有课」自动描述这一天
   */
  private fillNextDay(d: CardData, s: ScheduleData, head: string): boolean {
    const offsets: number[] = this.upcomingOffsets();
    for (let k = 0; k < offsets.length; k++) {
      const offset: number = offsets[k];
      const dt: Date = new Date();
      dt.setDate(dt.getDate() + offset);
      const day: number = dt.getDay() - 1;
      const list: CourseItem[] = [];
      for (let i = 0; i < s.courses.length; i++) {
        if (s.courses[i].day === day) {
          list.push(s.courses[i]);
        }
      }
      if (list.length === 0) {
        continue;
      }
      list.sort((a: CourseItem, b: CourseItem): number => a.start - b.start);
      const first: CourseItem = list[0];
      const label: string = this.dayLabel(offset, day);
      d.state = 'tomorrow';
      d.head = head.length > 0 ? head : `${label}有课`;
      d.heroTag = label;
      d.heroName = first.name;
      d.heroTime = this.timeRange(first.start, first.span);
      d.heroPlace = first.place;
      d.heroNote = `共 ${list.length} 节`;
      d.listLabel = `${label} · 共 ${list.length} 节`;
      d.summary = `${label}共 ${list.length} 节`;
      for (let i = 0; i < list.length && i < 8; i++) {
        const c: CourseItem = list[i];
        this.setSlot(d, i, this.timeRange(c.start, c.span), c.name, c.place,
          themeDef(d.theme).card.tomorrowFg);
      }
      return true;
    }
    return false;
  }

  /**
   * 按状态配色。所有主题的色板都在 ThemeConfig.CardPalette 里，
   * 这里只按 state 取对应的一组三色 —— 加主题不用改这里。
   */
  private paint(d: CardData): void {
    const card = themeDef(d.theme).card;
    const c = d.state === 'now' ? card.now
      : d.state === 'next' ? card.next
        : d.state === 'tomorrow' ? card.tomorrow
          : d.state === 'done' ? card.done : card.none;
    d.accent = c.accent;
    d.tint = c.tint;
    d.ink = c.ink;
  }

  /** 定时刷新的分钟数：至少 5 分钟（系统下限），最多 12 小时 */
  private clampMin(m: number): number {
    if (m < 5) {
      return 5;
    }
    if (m > 720) {
      return 720;
    }
    return m;
  }

  /** 把分钟差说成人话：45 分钟 / 2 小时 35 分 / 即将开始 */
  private durText(minutes: number): string {
    if (minutes <= 0) {
      return '即将开始';
    }
    if (minutes < 60) {
      return `${minutes} 分钟`;
    }
    const h: number = Math.floor(minutes / 60);
    const m: number = minutes % 60;
    if (m === 0) {
      return `${h} 小时`;
    }
    return `${h} 小时 ${m} 分`;
  }

  private setSlot(d: CardData, i: number, t: string, n: string, p: string, fg: string): void {
    if (i === 0) {
      d.t0 = t; d.n0 = n; d.p0 = p; d.f0 = fg;
    } else if (i === 1) {
      d.t1 = t; d.n1 = n; d.p1 = p; d.f1 = fg;
    } else if (i === 2) {
      d.t2 = t; d.n2 = n; d.p2 = p; d.f2 = fg;
    } else if (i === 3) {
      d.t3 = t; d.n3 = n; d.p3 = p; d.f3 = fg;
    } else if (i === 4) {
      d.t4 = t; d.n4 = n; d.p4 = p; d.f4 = fg;
    } else if (i === 5) {
      d.t5 = t; d.n5 = n; d.p5 = p; d.f5 = fg;
    } else if (i === 6) {
      d.t6 = t; d.n6 = n; d.p6 = p; d.f6 = fg;
    } else if (i === 7) {
      d.t7 = t; d.n7 = n; d.p7 = p; d.f7 = fg;
    }
  }

  private startMinutes(c: CourseItem): number {
    const idx: number = c.start - 1;
    if (idx < 0 || idx >= PERIOD_START.length) {
      return -1;
    }
    return this.toMinutes(PERIOD_START[idx]);
  }

  private endMinutes(c: CourseItem): number {
    const idx: number = c.start + c.span - 2;
    if (idx < 0 || idx >= PERIOD_END.length) {
      return -1;
    }
    return this.toMinutes(PERIOD_END[idx]);
  }

  private toMinutes(hm: string): number {
    const p: string[] = hm.split(':');
    return parseInt(p[0]) * 60 + parseInt(p[1]);
  }

  private nowMinutes(): number {
    const now = new Date();
    return now.getHours() * 60 + now.getMinutes();
  }

  /** 形如 14:25-16:05；异常数据返回 N-M 节 */
  private timeRange(start: number, span: number): string {
    const from: number = start - 1;
    const to: number = start + span - 2;
    if (from < 0 || to < 0 || from >= PERIOD_START.length || to >= PERIOD_END.length) {
      return `${start}-${start + span - 1} 节`;
    }
    return `${PERIOD_START[from]}-${PERIOD_END[to]}`;
  }

  private todayIndex(): number {
    const day: number = new Date().getDay();
    if (day === 0 || day === 6) {
      return -1;
    }
    return day - 1;
  }

  private dateText(): string {
    const now = new Date();
    return `${now.getMonth() + 1}月${now.getDate()}日`;
  }

  private weekdayText(): string {
    const week: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return week[new Date().getDay()];
  }
}
