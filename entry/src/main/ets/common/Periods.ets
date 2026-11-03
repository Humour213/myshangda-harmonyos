/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */

/**
 * 学校作息表 —— 全工程唯一一份。
 *
 * 之前这份时间表在 `service/Reminders.ets`（发提醒用）和
 * `widget/ScheduleCardAbility.ets`（卡片算「还剩几分钟」用）各硬编码了一遍，
 * 内容完全一样。学校一调作息就要改两个地方，漏掉一处的结果是**卡片和提醒时间对不上**，
 * 而且症状很隐蔽：卡片显示 08:05 上课，提醒却在别的点响。
 *
 * 数组下标是「第几节 - 1」，即 PERIOD_START[0] 是第 1 节的上课时间。
 */
export const PERIOD_START: string[] = [
  '08:05', '08:50', '09:50', '10:40', '11:30', '13:40',
  '14:35', '15:30', '16:25', '18:30', '19:25', '20:20'
];

export const PERIOD_END: string[] = [
  '08:50', '09:35', '10:35', '11:25', '12:15', '14:25',
  '15:20', '16:15', '17:10', '19:15', '20:10', '21:05'
];

/** 一天排到第几节（超出这个范围的课次视为脏数据，各处统一跳过） */
export const PERIOD_COUNT: number = PERIOD_START.length;

/** 'HH:mm' → 当天的分钟数；格式不对返回 -1 */
export function toMinutes(hm: string): number {
  const parts: string[] = hm.split(':');
  if (parts.length !== 2) {
    return -1;
  }
  const h: number = parseInt(parts[0]);
  const m: number = parseInt(parts[1]);
  if (isNaN(h) || isNaN(m)) {
    return -1;
  }
  return h * 60 + m;
}
