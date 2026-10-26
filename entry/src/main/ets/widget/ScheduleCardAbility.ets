import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { ScheduleData, CourseItem } from '../common/ScheduleTypes';
import { parseSchedule } from '../service/ScheduleParse';

/**
 * 卡片数据。版式是「整卡浅色底 + 一张白卡承载此刻」：
 *   - head / hero* 回答"现在该上什么课"，是主视觉，字号最大、唯一白底；
 *   - slots 是之后还有的课，退为次要信息，只剩圆点 + 课名 + 时间；
 *   - accent / tint / ink 由 state 决定（按状态配色，见 paint()）。
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
  /** 主视觉下方的小标题，如「还有 2 节」（已经不含主视觉那一节） */
  restLabel: string = '';
  /** 大卡右上角统计，如「共 6 节 · 还剩 3 节」 */
  summary: string = '';
  /** 状态色：accent 用于标签/圆点/进度条，tint 为整卡底色，ink 为卡内正文色 */
  accent: string = '#8A94A6';
  tint: string = '#F0F2F6';
  ink: string = '#232A36';
  t0: string = ''; n0: string = ''; p0: string = ''; f0: string = '';
  t1: string = ''; n1: string = ''; p1: string = ''; f1: string = '';
  t2: string = ''; n2: string = ''; p2: string = ''; f2: string = '';
  t3: string = ''; n3: string = ''; p3: string = ''; f3: string = '';
  t4: string = ''; n4: string = ''; p4: string = ''; f4: string = '';
  t5: string = ''; n5: string = ''; p5: string = ''; f5: string = '';
  t6: string = ''; n6: string = ''; p6: string = ''; f6: string = '';
  t7: string = ''; n7: string = ''; p7: string = ''; f7: string = '';
}

/** 每一节的起止时间（学校作息）。注意课表里的 start 是"第几节"，不是两节一组 */
const PERIOD_START: string[] = [
  '08:05', '08:50', '09:50', '10:40', '11:30', '13:40',
  '14:35', '15:30', '16:25', '18:30', '19:25', '20:20'
];

const PERIOD_END: string[] = [
  '08:50', '09:35', '10:35', '11:25', '12:15', '14:25',
  '15:20', '16:15', '17:10', '19:15', '20:10', '21:05'
];

const FG: string[] = ['#1E63B4', '#12806A', '#2B57C6', '#B4531A', '#5A3EBA',
  '#3F7A22', '#B02A2A', '#8A5B00'];

/** 明天预告统一用靛蓝，整组是"同一块内容" */
const TM_FG: string = '#3A568C';

/**
 * 课表桌面卡片的数据提供者（迷你 1×2、小卡 2×2、大卡 2×4 共用）。
 *
 * 主视觉区回答"此刻"，五个状态共用一套规则，只换文案和配色：
 *   - 上课中：heroTag「上课中」+ 课名 + 时段 + 「还剩 N 分钟」+ 进度条
 *   - 课间：  heroTag「下节」  + 课名 + 时段 + 「还有 N 分钟」
 *   - 今天上完：切到明天预告，head 改成「今天上完了」，heroTag「明天」
 *   - 今天没课：切到明天预告，head「今天没课」；明天也没课则 heroTag「没课」
 *   - 还没导入：heroTag「空课表」，提示点开导入
 * 列表只放「主视觉之后」的课，上完一节就少一条。
 */
export default class ScheduleCardAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData(this.buildData());
  }

  onUpdateForm(formId: string): void {
    try {
      const obj: formBindingData.FormBindingData =
        formBindingData.createFormBindingData(this.buildData());
      formProvider.updateForm(formId, obj).catch(() => {
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
    return d;
  }

  private buildDataInner(): CardData {
    const d: CardData = new CardData();
    d.head = `${this.dateText()} ${this.weekdayText()}`;
    d.state = 'none';
    d.heroTag = '没课';
    d.heroName = '今天没有课';
    d.heroNote = '好好休息';
    try {
      const path: string = this.context.filesDir + '/schedule.json';
      if (!fileIo.accessSync(path)) {
        d.heroTag = '空课表';
        d.heroName = '还没导入课表';
        d.heroNote = '点开导入';
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
      // 周末不预告"明天"（周六的明天是周日、周日的明天是周一，容易误导）
      if (today < 0) {
        d.head = `${this.dateText()} ${this.weekdayText()}`;
        d.heroTag = '周末';
        d.heroNote = '好好休息';
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
        // 今天整天没课：直接把明天预告顶上来，总比一句"今天没有课"有用
        if (this.fillTomorrow(d, s, today, '今天没课')) {
          return d;
        }
        return d;
      }

      const now: number = this.nowMinutes();
      const remaining: CourseItem[] = [];
      let current: CourseItem | null = null;
      for (let i = 0; i < todayList.length; i++) {
        const c: CourseItem = todayList[i];
        const end: number = this.endMinutes(c);
        if (end <= now) {
          continue;
        }
        remaining.push(c);
        if (this.startMinutes(c) <= now) {
          current = c;
        }
      }

      if (current !== null) {
        const start: number = this.startMinutes(current);
        const end: number = this.endMinutes(current);
        d.state = 'now';
        d.heroTag = '上课中';
        d.heroName = current.name;
        d.heroTime = this.timeRange(current.start, current.span);
        d.heroPlace = current.place;
        d.heroNote = `还剩 ${this.durText(end - now)}`;
        if (end > start) {
          d.progress = Math.min(100, Math.max(0, Math.round((now - start) * 100 / (end - start))));
        }
      } else if (remaining.length > 0) {
        const nxt: CourseItem = remaining[0];
        d.state = 'next';
        d.heroTag = '下节';
        d.heroName = nxt.name;
        d.heroTime = this.timeRange(nxt.start, nxt.span);
        d.heroPlace = nxt.place;
        d.heroNote = `还有 ${this.durText(this.startMinutes(nxt) - now)}`;
      } else {
        // 今天的课上完了：整张卡切到"明天预告"，而不是把明天的课混进今天的列表
        if (this.fillTomorrow(d, s, today, '今天上完了')) {
          return d;
        }
        d.state = 'done';
        d.heroTag = '已结束';
        d.heroName = '今天的课上完了';
        d.heroNote = `共 ${todayList.length} 节`;
        d.summary = `共 ${todayList.length} 节 · 全部上完`;
        return d;
      }

      const total: number = todayList.length;
      d.summary = `共 ${total} 节 · 还剩 ${remaining.length} 节`;
      // 课间时"下节"已经占用了主视觉，列表从再下一节开始
      if (current === null && remaining.length > 0) {
        remaining.shift();
      }
      // 正在上的课已经在主视觉里，列表里去掉，避免重复
      if (current !== null) {
        const rest: CourseItem[] = [];
        for (let j = 0; j < remaining.length; j++) {
          if (remaining[j] !== current) {
            rest.push(remaining[j]);
          }
        }
        remaining.length = 0;
        for (let j = 0; j < rest.length; j++) {
          remaining.push(rest[j]);
        }
      }

      let cnt: number = 0;
      for (let i = 0; i < remaining.length && i < 8; i++) {
        const c: CourseItem = remaining[i];
        this.setSlot(d, i, this.timeRange(c.start, c.span), c.name, c.place, FG[i % FG.length]);
        cnt++;
      }
      if (cnt > 0) {
        d.restLabel = `还有 ${cnt} 节`;
      }
      return d;
    } catch (err) {
      return d;
    }
  }

  /**
   * 把卡片切到"明天预告"：主视觉换成明天第一节，head 说明今天的情况，
   * 下面的列表只放明天"其余"的课，不重复第一节。
   *
   * @param head 卡片顶部小字，用来交代今天为什么没课了
   * @returns 明天确实有课才返回 true
   */
  private fillTomorrow(d: CardData, s: ScheduleData, today: number, head: string): boolean {
    const day: number = this.tomorrowIndex(today);
    const list: CourseItem[] = [];
    for (let i = 0; i < s.courses.length; i++) {
      if (s.courses[i].day === day) {
        list.push(s.courses[i]);
      }
    }
    if (list.length === 0) {
      return false;
    }
    list.sort((a: CourseItem, b: CourseItem): number => a.start - b.start);
    const first: CourseItem = list[0];
    d.state = 'tomorrow';
    d.head = head;
    d.heroTag = '明天';
    d.heroName = first.name;
    d.heroTime = this.timeRange(first.start, first.span);
    d.heroPlace = first.place;
    d.heroNote = `共 ${list.length} 节`;
    d.summary = `明天共 ${list.length} 节`;
    let cnt: number = 0;
    for (let i = 1; i < list.length && cnt < 8; i++) {
      const c: CourseItem = list[i];
      this.setSlot(d, cnt, this.timeRange(c.start, c.span), c.name, c.place, TM_FG);
      cnt++;
    }
    if (cnt > 0) {
      d.restLabel = `明天还有 ${cnt} 节`;
    }
    return true;
  }

  /** 按状态配色：上课中=绿、下节=靛蓝、已结束=灰蓝、没课=中性灰、明天=淡蓝 */
  private paint(d: CardData): void {
    if (d.state === 'now') {
      d.accent = '#2E9E63';
      d.tint = '#E9F5EE';
      d.ink = '#16301F';
    } else if (d.state === 'next') {
      d.accent = '#4A5CD0';
      d.tint = '#ECF0FC';
      d.ink = '#1A2138';
    } else if (d.state === 'tomorrow') {
      d.accent = '#3A568C';
      d.tint = '#E8EEF9';
      d.ink = '#22304D';
    } else if (d.state === 'done') {
      d.accent = '#6B7A99';
      d.tint = '#EDF0F6';
      d.ink = '#232A36';
    } else {
      d.accent = '#8A94A6';
      d.tint = '#F0F2F6';
      d.ink = '#232A36';
    }
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

  /** 明天（跳过周末）的星期索引 */
  private tomorrowIndex(today: number): number {
    if (today < 0) {
      return 0;
    }
    return today >= 4 ? 0 : today + 1;
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
