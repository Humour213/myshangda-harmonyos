import scheduleParseTest from './ScheduleParse.test';
import periodsTest from './Periods.test';
import reminderPlanTest from './ReminderPlan.test';

/**
 * 本机单元测试入口（不依赖设备，跑在开发机上）。
 * DevEco 里右键本文件运行，或命令行 `hvigorw test`。
 */
export default function testsuite() {
  scheduleParseTest();
  periodsTest();
  reminderPlanTest();
}
