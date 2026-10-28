/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
/**
 * 课表共享类型。
 *
 * 桌面卡片（FormExtensionAbility）、卡片 UI、上课提醒和网页抓取脚本
 * 都围绕这份结构转，字段改这里就行。
 */

/** 一次课（可能跨多节） */
export interface CourseItem {
  /** 星期几：0=周一 */
  day: number;
  /** 起始节次，从 1 开始 */
  start: number;
  /** 跨几节 */
  span: number;
  /** 课程名 */
  name: string;
  /** 上课地点 */
  place: string;
}

/** 一整周的课表 */
export interface ScheduleData {
  /** 学期，如「2026-2027 第一学期」 */
  term: string;
  /** 周次，如「第七周 (2026-10-26 ~ 2026-10-30)」 */
  week: string;
  courses: CourseItem[];
}
