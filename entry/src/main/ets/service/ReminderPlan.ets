/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { CourseItem } from '../common/ScheduleTypes';
import { PERIOD_COUNT } from '../common/Periods';

/**
 * 提醒的「排班策略」——纯函数，不碰系统 API、不读文件。
 *
 * 这些判断原来写在 Reminders 里，和 publishReminder / preferences 混在一个类，
 * 想单独验证「去重对不对」「指纹变了没有」只能整机跑一遍。抽出来之后可以直接单测。
 */

/**
 * 同一格（星期 + 节次）只留一门课。
 *
 * 单双周会在同一格里叠两门课，提醒只需要响一次 —— 重复发既烦，又会白占系统 30 条配额。
 * 保留先出现的那个，然后按时间排序，这样条数超上限被截断时不会漏掉周一的课。
 */
export function uniqueCourses(courses: CourseItem[]): CourseItem[] {
  const out: CourseItem[] = [];
  const seen: string[] = [];
  for (let i = 0; i < courses.length; i++) {
    const c: CourseItem = courses[i];
    const key: string = `${c.day}-${c.start}`;
    if (seen.indexOf(key) >= 0) {
      continue;
    }
    seen.push(key);
    out.push(c);
  }
  out.sort((a: CourseItem, b: CourseItem): number => {
    if (a.day !== b.day) {
      return a.day - b.day;
    }
    return a.start - b.start;
  });
  return out;
}

/**
 * 课表指纹。课名、地点、星期、节次任何一项变了都算变 ——
 * 调课、换教室、换老师都会让已排的提醒过期，必须重建。
 */
export function courseFingerprint(courses: CourseItem[]): string {
  let fp: string = '';
  for (let i = 0; i < courses.length; i++) {
    const c: CourseItem = courses[i];
    fp += `${c.day}:${c.start}:${c.name}:${c.place};`;
  }
  return fp;
}

/**
 * 其中有多少条是能真发出去的（节次在作息表范围内的）。
 *
 * 用来和「系统里还活着的提醒条数」比对：少了就说明被系统回收或被用户删了，要补发。
 */
export function countableCount(courses: CourseItem[]): number {
  let n: number = 0;
  for (let i = 0; i < courses.length; i++) {
    const idx: number = courses[i].start - 1;
    if (idx >= 0 && idx < PERIOD_COUNT) {
      n++;
    }
  }
  return n;
}
