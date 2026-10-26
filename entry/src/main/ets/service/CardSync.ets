import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ScheduleData } from '../common/ScheduleTypes';
import { parseSchedule } from './ScheduleParse';
import { SCHEDULE_SCRAPE_JS } from './ScheduleScripts';
import { Reminders } from './Reminders';

const DOMAIN = 0x0000;
const TAG = 'CardSync';
/** 课表缓存文件名：桌面卡片（FormExtensionAbility）也读这一份 */
const FILE_NAME: string = 'schedule.json';

/**
 * 课表缓存与桌面卡片的同步。
 *
 * 分工：
 *   - 这里负责「从网页抓 → 落盘 → 重排上课提醒」；
 *   - 卡片 Ability 只负责「读盘 → 算当前状态 → 渲染」。
 * 两边都读写 filesDir 下的 schedule.json，属于同一模块的 el2 沙箱，路径一致。
 */
export class CardSync {
  static filePath(ctx: common.UIAbilityContext): string {
    return `${ctx.filesDir}/${FILE_NAME}`;
  }

  /** 写入缓存（卡片下一次刷新即可看到） */
  static save(ctx: common.UIAbilityContext, data: ScheduleData): void {
    try {
      const path: string = CardSync.filePath(ctx);
      const file = fileIo.openSync(path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(file.fd, JSON.stringify(data));
      fileIo.closeSync(file);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'save schedule failed %{public}s', JSON.stringify(err));
    }
  }

  /** 读取缓存；没有缓存时返回空课表 */
  static load(ctx: common.UIAbilityContext): ScheduleData {
    const empty: ScheduleData = { term: '', week: '', courses: [] };
    try {
      const path: string = CardSync.filePath(ctx);
      if (!fileIo.accessSync(path)) {
        return empty;
      }
      const size: number = fileIo.statSync(path).size;
      if (size <= 0) {
        return empty;
      }
      const buf: ArrayBuffer = new ArrayBuffer(size);
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file);
      const txt: string = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf));
      return parseSchedule(txt);
    } catch (err) {
      return empty;
    }
  }

  /**
   * 从门户首页抓一次课表并落盘。
   *
   * 课表在首页那个 WebView 里，所以调用方要把首页的 controller 传进来；
   * quiet=true 时不动界面、不弹提示（开机静默同步用）。
   */
  static scrape(ctrl: webview.WebviewController, ctx: common.UIAbilityContext,
    quiet: boolean): Promise<boolean> {
    return new Promise<boolean>((resolve: (v: boolean) => void) => {
      let raw: Promise<string>;
      try {
        raw = ctrl.runJavaScript(SCHEDULE_SCRAPE_JS) as Promise<string>;
      } catch (err) {
        resolve(false);
        return;
      }
      raw.then((res: string) => {
        const d: ScheduleData = parseSchedule(String(res));
        if (d.courses.length === 0 && d.week.length === 0) {
          if (!quiet) {
            hilog.warn(DOMAIN, TAG, 'no schedule scraped');
          }
          resolve(false);
          return;
        }
        CardSync.save(ctx, d);
        // 顺手把接下来三天的上课提醒排好；用户没给通知权限就算了
        Reminders.sync(d).catch(() => {
        });
        resolve(true);
      }).catch(() => {
        resolve(false);
      });
    });
  }
}
