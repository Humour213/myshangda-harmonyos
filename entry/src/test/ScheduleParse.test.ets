/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { describe, it, expect } from '@ohos/hypium';
import { parseSchedule } from '../main/ets/service/ScheduleParse';
import { ScheduleData, CourseItem } from '../main/ets/common/ScheduleTypes';

/**
 * 课表解析的单测。
 *
 * 这个函数是「网页 → 卡片 / 提醒」的唯一入口，解析错了整条链路都错，
 * 而它又最容易受抓取格式变化影响（外层引号、转义、字段缺失），所以先测它。
 */
export default function scheduleParseTest() {
  describe('parseSchedule', () => {
    it('空串返回空课表', 0, () => {
      const d: ScheduleData = parseSchedule('');
      expect(d.courses.length).assertEqual(0);
      expect(d.term).assertEqual('');
      expect(d.week).assertEqual('');
    });

    it('非 JSON 内容返回空课表而不是抛异常', 0, () => {
      const d: ScheduleData = parseSchedule('<html>登录页</html>');
      expect(d.courses.length).assertEqual(0);
    });

    it('能还原 runJavaScript 的外层引号与转义', 0, () => {
      // runJavaScript 拿到的是 JSON.stringify 的结果，外面又裹了一层引号、内部引号被转义
      const json: string = '{"term":"2026-2027 第一学期","week":"第八周 (2026-11-02 ~ 2026-11-06)",' +
        '"courses":[{"day":0,"start":1,"span":2,"name":"商务英语阅读","place":"外语楼121"}]}';
      const wrapped: string = '"' + json.split('"').join('\\"') + '"';
      const d: ScheduleData = parseSchedule(wrapped);
      expect(d.courses.length).assertEqual(1);
      expect(d.term).assertEqual('2026-2027 第一学期');
      expect(d.courses[0].name).assertEqual('商务英语阅读');
      expect(d.courses[0].place).assertEqual('外语楼121');
      expect(d.courses[0].start).assertEqual(1);
      expect(d.courses[0].span).assertEqual(2);
    });

    it('courses 缺失时返回空课表', 0, () => {
      const d: ScheduleData = parseSchedule('{"term":"2026","week":"第八周"}');
      expect(d.courses.length).assertEqual(0);
    });

    it('没有课名的条目被丢弃，其余保留', 0, () => {
      const raw: string = '{"courses":[{"day":0,"start":1,"name":""},{"day":1,"start":2,"name":"管理学"}]}';
      const d: ScheduleData = parseSchedule(raw);
      expect(d.courses.length).assertEqual(1);
      expect(d.courses[0].name).assertEqual('管理学');
    });

    it('缺省字段有兜底值', 0, () => {
      const raw: string = '{"courses":[{"name":"只有名字"}]}';
      const d: ScheduleData = parseSchedule(raw);
      const c: CourseItem = d.courses[0];
      expect(c.day).assertEqual(0);
      expect(c.start).assertEqual(1);
      expect(c.span).assertEqual(1);
      expect(c.place).assertEqual('');
    });
  });
}
