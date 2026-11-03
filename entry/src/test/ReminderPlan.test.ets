/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { describe, it, expect } from '@ohos/hypium';
import { uniqueCourses, courseFingerprint, countableCount } from '../main/ets/service/ReminderPlan';
import { CourseItem } from '../main/ets/common/ScheduleTypes';
import { PERIOD_COUNT } from '../main/ets/common/Periods';

function course(day: number, start: number, span: number, name: string, place: string): CourseItem {
  const c: CourseItem = { day: day, start: start, span: span, name: name, place: place };
  return c;
}

/**
 * 提醒排班策略的单测。
 *
 * 这三条判断直接决定「会不会重复响」「课表变了会不会漏重建」「缺了几门要不要补」，
 * 都是纯函数，最适合卡在 CI 里。
 */
export default function reminderPlanTest() {
  describe('reminderPlan', () => {
    it('同一格（星期+节次）只保留第一门课', 0, () => {
      const list: CourseItem[] = [
        course(0, 1, 2, '单周课', 'A101'),
        course(0, 1, 2, '双周课', 'A102'),
        course(1, 1, 2, '另一天的课', 'B201')
      ];
      const uniq: CourseItem[] = uniqueCourses(list);
      expect(uniq.length).assertEqual(2);
      expect(uniq[0].name).assertEqual('单周课');
    });

    it('结果按星期再按节次排序（截断时才不会漏掉周一）', 0, () => {
      const list: CourseItem[] = [
        course(4, 10, 2, '周五第10节', 'X'),
        course(0, 8, 2, '周一第8节', 'X'),
        course(0, 1, 2, '周一第1节', 'X')
      ];
      const uniq: CourseItem[] = uniqueCourses(list);
      expect(uniq[0].name).assertEqual('周一第1节');
      expect(uniq[1].name).assertEqual('周一第8节');
      expect(uniq[2].name).assertEqual('周五第10节');
    });

    it('指纹：同样的课表得出同样的值', 0, () => {
      const a: CourseItem[] = [course(0, 1, 2, '课A', 'A101')];
      const b: CourseItem[] = [course(0, 1, 2, '课A', 'A101')];
      expect(courseFingerprint(a)).assertEqual(courseFingerprint(b));
    });

    it('指纹：换教室就算变了（提醒必须重建）', 0, () => {
      const a: CourseItem[] = [course(0, 1, 2, '课A', 'A101')];
      const b: CourseItem[] = [course(0, 1, 2, '课A', 'A102')];
      expect(courseFingerprint(a) === courseFingerprint(b)).assertFalse();
    });

    it('指纹：顺序不同但内容相同视为同一份课表', 0, () => {
      const a: CourseItem[] = [course(0, 1, 2, '课A', 'A101'), course(1, 3, 2, '课B', 'B101')];
      const b: CourseItem[] = [course(1, 3, 2, '课B', 'B101'), course(0, 1, 2, '课A', 'A101')];
      // 指纹按传入顺序拼，所以这两个不同；但 sync 里是先 uniq（会排序）再算指纹，
      // 因此这里断言「排序后一致」这个真实前提。
      expect(courseFingerprint(uniqueCourses(a))).assertEqual(courseFingerprint(uniqueCourses(b)));
    });

    it('可发条数：节次越界的课不计入', 0, () => {
      const list: CourseItem[] = [
        course(0, 1, 2, '正常', 'A'),
        course(0, PERIOD_COUNT + 3, 2, '越界', 'A'),
        course(0, 0, 2, '零节', 'A')
      ];
      expect(countableCount(list)).assertEqual(1);
    });
  });
}
