/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { webview } from '@kit.ArkWeb';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { preferences } from '@kit.ArkData';
import { formProvider, formBindingData } from '@kit.FormKit';
import { ScheduleData } from '../common/ScheduleTypes';
import { parseSchedule } from './ScheduleParse';
import { SCHEDULE_SCRAPE_JS } from './ScheduleScripts';
import { Reminders } from './Reminders';
import { PrefsStore } from '../common/PrefsStore';
import { THEME_DEFAULT, themeDef } from '../common/ThemeConfig';

const DOMAIN = 0x0000;
const TAG = 'CardSync';
/** 存 formId 列表的偏好文件名，和主题偏好分开，避免互相干扰 */
const PREF_FORMS: string = 'dsh_forms';
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

  /** 读缓存原文，用来判断课表有没有变化（判断变化比重新解析便宜） */
  private static readRaw(ctx: common.UIAbilityContext): string {
    try {
      const path: string = CardSync.filePath(ctx);
      if (!fileIo.accessSync(path)) {
        return '';
      }
      const size: number = fileIo.statSync(path).size;
      if (size <= 0) {
        return '';
      }
      const buf: ArrayBuffer = new ArrayBuffer(size);
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file);
      return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf));
    } catch (err) {
      return '';
    }
  }

  /** 读取缓存；没有缓存时返回空课表 */
  static load(ctx: common.UIAbilityContext): ScheduleData {
    const txt: string = CardSync.readRaw(ctx);
    if (txt === '') {
      const empty: ScheduleData = { term: '', week: '', courses: [] };
      return empty;
    }
    return parseSchedule(txt);
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
        // 课程列表为空就一律不落盘，哪怕周次文本抓到了。
        // 放假周、开学前、以及页面还没渲染完（抓取是延时 3.5 秒的一次性动作）都会出现
        // 「有周次、没课程」，这种空表一旦写进去，桌面卡片会一直显示「今天没课」，
        // 而且没有任何机制能自己纠正，只能等下次抓取成功。
        if (d.courses.length === 0) {
          if (!quiet) {
            hilog.warn(DOMAIN, TAG, 'no schedule scraped');
          }
          resolve(false);
          return;
        }
        CardSync.save(ctx, d);
        // 提醒改成按周重复发布后，一次就够整学期用。sync 自己会用「课表指纹 + 现存提醒数」
        // 判断该不该重建，所以这里每次都叫它 —— 提醒被系统回收或被用户手动删掉后，才能补回来。
        // （以前是 txt !== before 才调用，等于课表不变就永远不重排，3 天窗口一过就彻底不响了。）
        Reminders.sync(ctx, d).catch(() => {
        });
        resolve(true);
      }).catch(() => {
        resolve(false);
      });
    });
  }

  /** 存已加桌卡片 formId 的偏好键（onAddForm 加、onRemoveForm 删） */
  private static readonly KEY_FORM_IDS: string = 'dsh_form_ids';

  /**
   * 记录一个已加桌的 formId。getFormsInfo() 只返回卡片元信息、不含运行时 formId，
   * 所以只能在 onAddForm 时自己存，onRemoveForm 时删 —— 留着的才是当前桌面上的卡。
   */
  static addFormId(ctx: common.Context, formId: string): void {
    try {
      const store = preferences.getPreferencesSync(ctx, { name: PREF_FORMS });
      const ids: string[] = CardSync.readFormIds(ctx);
      if (ids.indexOf(formId) < 0) {
        ids.push(formId);
      }
      store.putSync(CardSync.KEY_FORM_IDS, JSON.stringify(ids));
      store.flushSync();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'addFormId failed %{public}s', JSON.stringify(err));
    }
  }

  /** 卡片被移除时清掉 formId，避免刷新已经不存在的卡 */
  static removeFormId(ctx: common.Context, formId: string): void {
    try {
      const store = preferences.getPreferencesSync(ctx, { name: PREF_FORMS });
      const ids: string[] = CardSync.readFormIds(ctx).filter((v: string) => v !== formId);
      store.putSync(CardSync.KEY_FORM_IDS, JSON.stringify(ids));
      store.flushSync();
    } catch (err) {
      // 忽略
    }
  }

  private static readFormIds(ctx: common.Context): string[] {
    try {
      const store = preferences.getPreferencesSync(ctx, { name: PREF_FORMS });
      const raw: string = store.getSync(CardSync.KEY_FORM_IDS, '[]') as string;
      const arr: string[] = JSON.parse(raw) as string[];
      return arr instanceof Array ? arr : [];
    } catch (err) {
      return [];
    }
  }

  /**
   * 切换配色主题后立刻刷新桌面卡片（卡片是独立进程，不会自己感知 AppStorage）。
   *
   * 只推"主题相关"的几个字段：theme / mascot / tint / accent / ink。
   * formBindingData 的更新是增量合并，卡片其余字段（课名、时间、进度等）保持原值不变。
   * 精确按 state 配的色值由卡片下次定时刷新(onUpdateForm)校正，这里先给一套通用暖色，
   * 保证切完主题当下就是豆泥色，不用等半小时。
   */
  static refreshAllForms(ctx: common.Context, theme?: string): void {
    try {
      // 主题必须由调用方显式传入（设置页刚 setOrCreate 到 AppStorage 的那个值）。
      // 之前这里读 getThemeSync(preferences)，而设置页的 setTheme 是异步落盘、
      // refreshAllForms 紧跟其后调用 —— 读到的还是旧主题，推给卡片的是旧颜色，
      // 表现就是"切了主题卡片没反应"。只在没传时才回退到同步读盘。
      const target: string = (theme !== undefined && theme !== '')
        ? theme : PrefsStore.getThemeSync(ctx);
      const def = themeDef(target);
      // 默认主题沿用空 theme（widget 里 '' 即默认），保证老的 form 数据兼容；
      // 装饰主题下发自己的 id，widget 据此查 ThemeConfig 拿到整套色板。
      const themeValue: string = target === THEME_DEFAULT ? '' : target;
      const ids: string[] = CardSync.readFormIds(ctx);
      for (let i = 0; i < ids.length; i++) {
        // 即时兜底色取 card.none：切完当下就换色，精确按 state 的色值由下次 onUpdateForm 校正。
        // 切默认也要显式推三色，否则 formBindingData 增量合并会残留上一个主题的色。
        const patch: Record<string, Object> = {
          'theme': themeValue,
          'mascot': def.decorated ? 'passive' : '',
          'tint': def.card.none.tint,
          'accent': def.card.none.accent,
          'ink': def.card.none.ink
        };
        const obj: formBindingData.FormBindingData = formBindingData.createFormBindingData(patch);
        const fid: string = ids[i];
        formProvider.updateForm(fid, obj).catch((err: Object) => {
          // 单张失败不影响其它卡片；失败通常意味着这个 formId 已经失效
          // （卡片被删/应用重装后系统重新分配），顺手从列表里清掉。
          CardSync.removeFormId(ctx, fid);
        });
      }
    } catch (err) {
      // 卡片刷新是锦上添花，绝不能影响切主题本身
    }
  }
}
