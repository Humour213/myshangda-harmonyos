/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourrier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CourseItem, ScheduleData } from '../common/ScheduleTypes';

const DOMAIN = 0x0000;
/** 提前几分钟提醒 */
const AHEAD_MIN: number = 10;
/** 往后安排几天（今天 + 明天 + 后天） */
const DAYS_AHEAD: number = 3;
/** 提醒标题，用来识别并清理我们自己发的提醒 */
const TITLE: string = '上课提醒';
/** 点击提醒拉起的包名，必须与本工程一致 */
const PKG_NAME: string = 'com.humour.myshangda';

/** 每一节的开始时间（和桌面卡片保持一致） */
const PERIOD_START: string[] = [
  '08:05', '08:50', '09:50', '10:40', '11:30', '13:40',
  '14:35', '15:30', '16:25', '18:30', '19:25', '20:20'
];

/** 一天的课程 → 未来几天的定时提醒 */
export class Reminders {
  /** 清掉旧的、按最新课表重新排 */
  static async sync(data: ScheduleData): Promise<void> {
    if (data.courses.length === 0) {
      return;
    }
    try {
      await Reminders.cancelAll();
    } catch (err) {
      hilog.warn(DOMAIN, 'reminder', 'cancel failed');
    }
    // 通知权限
    try {
      const enabled: boolean = await notificationManager.isNotificationEnabled();
      if (!enabled) {
        await notificationManager.requestEnableNotification();
      }
    } catch (err) {
      hilog.warn(DOMAIN, 'reminder', 'notification permission not granted');
    }

    const now = new Date();
    for (let d = 0; d < DAYS_AHEAD; d++) {
      const day: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + d);
      const weekday: number = day.getDay();
      if (weekday === 0 || weekday === 6) {
        continue;
      }
      const idx: number = weekday - 1;
      for (let i = 0; i < data.courses.length; i++) {
        const c: CourseItem = data.courses[i];
        if (c.day !== idx) {
          continue;
        }
        const hm: string = c.start - 1 < PERIOD_START.length ? PERIOD_START[c.start - 1] : '';
        if (hm.length === 0) {
          continue;
        }
        const parts: string[] = hm.split(':');
        const startAt: Date = new Date(day.getFullYear(), day.getMonth(), day.getDate(),
          parseInt(parts[0]), parseInt(parts[1]), 0);
        const fireAt: number = startAt.getTime() - AHEAD_MIN * 60 * 1000;
        if (fireAt <= Date.now()) {
          continue;
        }
        Reminders.publish(new Date(fireAt), hm, c);
      }
    }
  }

  private static publish(at: Date, hm: string, c: CourseItem): void {
    const req: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: at.getFullYear(),
        month: at.getMonth() + 1,
        day: at.getDate(),
        hour: at.getHours(),
        minute: at.getMinutes(),
        second: 0
      },
      title: TITLE,
      content: `${hm} 上课 · ${c.name} · ${c.place}`,
      expiredContent: '',
      snoozeTimes: 0,
      timeInterval: 0,
      ringDuration: 1,
      wantAgent: {
        pkgName: PKG_NAME,
        abilityName: 'EntryAbility'
      },
      actionButton: []
    };
    reminderAgentManager.publishReminder(req).then(() => {
      hilog.info(DOMAIN, 'reminder', 'published %{public}s', c.name);
    }).catch((err: Error) => {
      hilog.warn(DOMAIN, 'reminder', 'publish failed: %{public}s', err.message);
    });
  }

  /** 只取消我们自己发的提醒，不动用户自己的日历提醒 */
  static async cancelAll(): Promise<void> {
    const list: reminderAgentManager.ReminderRequest[] = await reminderAgentManager.getValidReminders();
    for (let i = 0; i < list.length; i++) {
      const r: reminderAgentManager.ReminderRequest = list[i];
      if (r.title !== TITLE) {
        continue;
      }
      try {
        // getValidReminders 返回的项带 reminderId，类型声明里没有，放宽后取
        const id: number = (r as object as Record<string, number>)['reminderId'];
        await reminderAgentManager.cancelReminder(id);
      } catch (err) {
        // 忽略单条失败
      }
    }
  }
}
