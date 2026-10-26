/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourrier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { CourseItem, ScheduleData } from '../common/ScheduleTypes';

/**
 * 解析从网页抓到的课表 JSON。
 *
 * 抓取脚本返回的是 JSON.stringify 的结果，runJavaScript 又给外层加了引号，
 * 所以要先去掉外层引号、还原转义，再解析。
 */
export function parseSchedule(raw: string): ScheduleData {
  const empty: ScheduleData = { term: '', week: '', courses: [] };
  let s: string = raw.trim();
  if (s.length === 0) {
    return empty;
  }
  if (s.length > 1 && s.startsWith('"') && s.endsWith('"')) {
    s = s.substring(1, s.length - 1);
  }
  s = s.split('\\"').join('"');
  s = s.split('\\\\').join('\\');
  if (s.indexOf('{') < 0) {
    return empty;
  }
  try {
    const obj: ScheduleData = JSON.parse(s) as ScheduleData;
    if (obj.courses === undefined || obj.courses === null) {
      return empty;
    }
    const list: CourseItem[] = [];
    for (let i = 0; i < obj.courses.length; i++) {
      const c: CourseItem = obj.courses[i];
      if (c.name === undefined || c.name === null || c.name.length === 0) {
        continue;
      }
      const item: CourseItem = {
        day: c.day === undefined ? 0 : c.day,
        start: c.start === undefined ? 1 : c.start,
        span: c.span === undefined ? 1 : c.span,
        name: c.name,
        place: c.place === undefined ? '' : c.place
      };
      list.push(item);
    }
    const out: ScheduleData = {
      term: obj.term === undefined ? '' : obj.term,
      week: obj.week === undefined ? '' : obj.week,
      courses: list
    };
    return out;
  } catch (err) {
    return empty;
  }
}
