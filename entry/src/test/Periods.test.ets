/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { describe, it, expect } from '@ohos/hypium';
import { PERIOD_START, PERIOD_END, PERIOD_COUNT, toMinutes, startOf, endOf } from '../main/ets/common/Periods';

/**
 * 作息表的单测。
 *
 * 这张表同时决定「卡片显示几点上课」和「提醒提前 10 分钟在几点响」，
 * 任何一处越界都会让两边对不上，所以边界值单独测。
 */
export default function periodsTest() {
  describe('periods', () => {
    it('起止时间表长度一致', 0, () => {
      expect(PERIOD_START.length).assertEqual(PERIOD_END.length);
      expect(PERIOD_COUNT).assertEqual(PERIOD_START.length);
    });

    it('toMinutes 换算正确', 0, () => {
      expect(toMinutes('08:05')).assertEqual(485);
      expect(toMinutes('00:00')).assertEqual(0);
      expect(toMinutes('21:05')).assertEqual(1265);
    });

    it('toMinutes 对坏输入返回 -1', 0, () => {
      expect(toMinutes('')).assertEqual(-1);
      expect(toMinutes('0805')).assertEqual(-1);
      expect(toMinutes('aa:bb')).assertEqual(-1);
    });

    it('startOf 第 1 节与越界', 0, () => {
      expect(startOf(1)).assertEqual('08:05');
      expect(startOf(0)).assertEqual('');
      expect(startOf(PERIOD_COUNT + 1)).assertEqual('');
    });

    it('endOf 按起始节 + 跨节数算下课时间', 0, () => {
      // 第 1 节连上 2 节 → 08:05-09:35
      expect(endOf(1, 2)).assertEqual('09:35');
      // 第 1 节只上 1 节 → 08:05-08:50
      expect(endOf(1, 1)).assertEqual('08:50');
      // 最后一节
      expect(endOf(PERIOD_COUNT, 1)).assertEqual('21:05');
    });

    it('endOf 越界返回空串', 0, () => {
      expect(endOf(PERIOD_COUNT, 2)).assertEqual('');
      expect(endOf(0, 1)).assertEqual('');
    });
  });
}
