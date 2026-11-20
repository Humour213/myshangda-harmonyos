/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { THEME_DOUNI } from './PrefsStore';

/**
 * 应用外壳（状态栏 / 标题栏 / 页面底 / 强调色）的配色。
 *
 * 为什么集中在这里而不是各处写死：
 * 原来这些颜色是散在 Index / Settings / About / Nav 里的字面量，
 * 想换个色系要翻六七个文件，改漏一处就会出现"标题栏暖了、页面还是冷灰"的割裂。
 * 现在只有这一张表，页面只管问"当前主题的页面底是什么色"。
 *
 * 豆泥主题的取值不是凭空调的，是从素材里采样出来的：
 *   体色 #F0E4D8（奶油）｜毛发 #9C846C / #A89078（灰棕）｜勾线 #2E2A26（墨）
 * 页面底和标题栏都从这个奶油往亮处提，强调色往暗处压 —— 保证有对比度，
 * 又不会跳出一条跟插画无关的蓝。
 */

/** 页面底色 */
const DOUNI_PAGE = '#FAF4EC';
/** 标题栏底色：比页面再亮一档，靠这点差分层，不需要额外分割线 */
const DOUNI_BAR = '#FDF8F2';
/** 底栏/手势条区域底色：比页面深一档，和悬浮底栏的材质底色接住 */
const DOUNI_BAR_SOFT = '#F2E9DC';
/** 主文字 */
const DOUNI_INK = '#3A322B';
/** 次文字 */
const DOUNI_SUB_INK = '#8B7C6B';
/** 强调（链接、图标、描边）。压在奶油底上对比度约 5:1 */
const DOUNI_ACCENT = '#8F6A45';
/** 主按钮底色。配白字，按钮字号够大，3:1 以上即可读 */
const DOUNI_PRIMARY = '#94714C';

/** 默认主题：沿用原来的冷灰 + 蓝，一个字都没改 */
const DEF_PAGE = '#F7F8FA';
const DEF_BAR = '#F7F8FA';
const DEF_BAR_SOFT = '#F4F5F7';
const DEF_INK = '#1A1A1A';
const DEF_SUB_INK = '#8A8F99';
const DEF_ACCENT = '#2D8CFA';
const DEF_PRIMARY = '#3D6BE5';

export class Palette {
  static isDouni(theme: string): boolean {
    return theme === THEME_DOUNI;
  }

  /** 页面底色（设置页、关于页这类原生页的整页背景） */
  static page(theme: string): string {
    return Palette.isDouni(theme) ? DOUNI_PAGE : DEF_PAGE;
  }

  /** 标题栏底色 */
  static bar(theme: string): string {
    return Palette.isDouni(theme) ? DOUNI_BAR : DEF_BAR;
  }

  /**
   * 底栏 / 手势条区域底色。
   *
   * 原生样式下这块是窗口底层画出来的，要跟悬浮 Tab 的材质底色对齐才不会出现小白条；
   * 豆泥主题给一个比页面深一点的暖色，正好接在奶油底下面。
   */
  static barSoft(theme: string): string {
    return Palette.isDouni(theme) ? DOUNI_BAR_SOFT : DEF_BAR_SOFT;
  }

  static ink(theme: string): string {
    return Palette.isDouni(theme) ? DOUNI_INK : DEF_INK;
  }

  static subInk(theme: string): string {
    return Palette.isDouni(theme) ? DOUNI_SUB_INK : DEF_SUB_INK;
  }

  /** 强调色：链接文字、选中态、图标描边 */
  static accent(theme: string): string {
    return Palette.isDouni(theme) ? DOUNI_ACCENT : DEF_ACCENT;
  }

  /** 主按钮底色 */
  static primary(theme: string): string {
    return Palette.isDouni(theme) ? DOUNI_PRIMARY : DEF_PRIMARY;
  }
}
