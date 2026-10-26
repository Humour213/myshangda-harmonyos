import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { ScheduleData, CourseItem } from '../common/ScheduleTypes';
import { parseSchedule } from '../service/ScheduleParse';

/** 卡片数据：状态 + 剩余课程（最多 8 节，字段平铺便于卡片渲染） */
class CardData {
  date: string = '';
  weekday: string = '';
  /** now=上课中 / next=课间 / done=已上完 / none=今天没课 / tomorrow=明天预告 */
  state: string = 'none';
  status: string = '';
  /** 副标题：现在/下一节的时间地点 */
  detail: string = '';
  summary: string = '';
  /** 明天预告：分组标签（「明天 · 共 3 节」）、第一节时间/课名/地点 */
  tmLabel: string = '';
  tmTime: string = '';
  tmName: string = '';
  tmPlace: string = '';
  t0: string = ''; n0: string = ''; p0: string = ''; b0: string = ''; f0: string = '';
  t1: string = ''; n1: string = ''; p1: string = ''; b1: string = ''; f1: string = '';
  t2: string = ''; n2: string = ''; p2: string = ''; b2: string = ''; f2: string = '';
  t3: string = ''; n3: string = ''; p3: string = ''; b3: string = ''; f3: string = '';
  t4: string = ''; n4: string = ''; p4: string = ''; b4: string = ''; f4: string = '';
  t5: string = ''; n5: string = ''; p5: string = ''; b5: string = ''; f5: string = '';
  t6: string = ''; n6: string = ''; p6: string = ''; b6: string = ''; f6: string = '';
  t7: string = ''; n7: string = ''; p7: string = ''; b7: string = ''; f7: string = '';
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

const BG: string[] = ['#D6E9FF', '#D6F5EA', '#D6E4FF', '#FFE7D1', '#E3DDFF',
  '#D9F7D0', '#FFD9D9', '#FFE9B8'];
const FG: string[] = ['#1E63B4', '#12806A', '#2B57C6', '#B4531A', '#5A3EBA',
  '#3F7A22', '#B02A2A', '#8A5B00'];

/** 明天预告用同一套靛蓝色，整组是"同一块内容"，不再是一条条彩色卡片 */
const TM_BG: string = '#E5EBFA';
const TM_FG: string = '#3A568C';

/**
 * 课表桌面卡片的数据提供者（小卡 2×2、大卡 2×4 共用）。
 *
 * 语义：
 *   - 上课中：status = 「上课中 · 课程名」
 *   - 课间：  status = 「下节 13:30 综合商务英语(3)」
 *   - 今天结束：state = tomorrow，status = 「今天的课上完了」，
 *               tmLabel = 「明天 · 共 3 节」，列表整块换成明天的课
 *               （卡片背景同时换成淡靛蓝，见 ScheduleSmall/Large）
 *   - 完成：  state = done，status = 「今天的课上完了，休息吧」
 *   - 没课：  state = none，status = 「今天没有课」
 * 列表里只放「还没上完」的课，上完一节就少一条。
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

  private buildData(): CardData {
    const d: CardData = new CardData();
    d.date = this.dateText();
    d.weekday = this.weekdayText();
    d.state = 'none';
    d.status = '今天没有课';
    try {
      const path: string = this.context.filesDir + '/schedule.json';
      if (!fileIo.accessSync(path)) {
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
        d.summary = '好好休息';
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
        if (this.fillTomorrow(d, s, today, '今天没有课')) {
          return d;
        }
        d.summary = '好好休息';
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
        d.state = 'now';
        d.status = `上课中 · ${current.name}`;
        d.detail = `${this.timeRange(current.start, current.span)}  ${current.place}`;
      } else if (remaining.length > 0) {
        const nxt: CourseItem = remaining[0];
        d.state = 'next';
        d.status = `下节 ${this.timeRange(nxt.start, nxt.span).substring(0, 5)} ${nxt.name}`;
        d.detail = `${nxt.place}`;
      } else {
        // 今天的课上完了：整张卡切到"明天预告"，而不是把明天的课混进今天的列表
        const totalAll: number = todayList.length;
        if (this.fillTomorrow(d, s, today, '今天的课上完了')) {
          return d;
        }
        d.state = 'done';
        d.status = '今天的课上完了，休息吧';
        d.detail = '';
        d.summary = `共 ${totalAll} 节 · 全部上完`;
        return d;
      }

      const total: number = todayList.length;
      const left: number = remaining.length;
      if (left > 0) {
        d.summary = `共 ${total} 节 · 还剩 ${left} 节`;
      } else {
        d.summary = `共 ${total} 节 · 全部上完`;
      }
      // 课间时"下节"已经写在状态行，列表从再下一节开始
      if (current === null && remaining.length > 0) {
        remaining.shift();
      }
      // 正在上的课已经在状态行里，列表里去掉，避免重复
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

      for (let i = 0; i < remaining.length && i < 8; i++) {
        const c: CourseItem = remaining[i];
        this.setSlot(d, i, this.timeRange(c.start, c.span), c.name, c.place,
          BG[i % BG.length], FG[i % FG.length]);
      }
      return d;
    } catch (err) {
      return d;
    }
  }

  /**
   * 把卡片切到"明天预告"：状态行保留今天的结论，明天整组课改由一个
   * 标签（tmLabel）引领，列表块统一用靛蓝色，视觉上和"今天的剩余课程"
   * 明确区分开，不会显得突兀。
   *
   * @returns 明天确实有课才返回 true
   */
  private fillTomorrow(d: CardData, s: ScheduleData, today: number, status: string): boolean {
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
    d.status = status;
    d.detail = '';
    d.summary = '';
    d.tmLabel = `明天 · 共 ${list.length} 节`;
    d.tmTime = this.timeRange(first.start, first.span).substring(0, 5);
    d.tmName = first.name;
    d.tmPlace = first.place;
    for (let i = 0; i < list.length && i < 8; i++) {
      const c: CourseItem = list[i];
      this.setSlot(d, i, this.timeRange(c.start, c.span), c.name, c.place, TM_BG, TM_FG);
    }
    return true;
  }

  private setSlot(d: CardData, i: number, t: string, n: string, p: string, bg: string, fg: string): void {
    if (i === 0) {
      d.t0 = t; d.n0 = n; d.p0 = p; d.b0 = bg; d.f0 = fg;
    } else if (i === 1) {
      d.t1 = t; d.n1 = n; d.p1 = p; d.b1 = bg; d.f1 = fg;
    } else if (i === 2) {
      d.t2 = t; d.n2 = n; d.p2 = p; d.b2 = bg; d.f2 = fg;
    } else if (i === 3) {
      d.t3 = t; d.n3 = n; d.p3 = p; d.b3 = bg; d.f3 = fg;
    } else if (i === 4) {
      d.t4 = t; d.n4 = n; d.p4 = p; d.b4 = bg; d.f4 = fg;
    } else if (i === 5) {
      d.t5 = t; d.n5 = n; d.p5 = p; d.b5 = bg; d.f5 = fg;
    } else if (i === 6) {
      d.t6 = t; d.n6 = n; d.p6 = p; d.b6 = bg; d.f6 = fg;
    } else if (i === 7) {
      d.t7 = t; d.n7 = n; d.p7 = p; d.b7 = bg; d.f7 = fg;
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
