/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { themePalette } from './ThemeConfig';

/**
 * 应用外壳（状态栏 / 标题栏 / 页面底 / 强调色）的配色。
 *
 * 这里只做门面：真正的色值放在 ThemeConfig 的 PALETTES 表，
 * 每个主题一套 token。页面只管问「当前主题的页面底是什么色」，
 * 加主题不用改这里，更不用改页面 —— 只要在 ThemeConfig 里加一条记录。
 *
 * 历史取值说明（豆泥主题的来源，方便日后微调时对照）：
 *   体色 #F0E4D8（奶油）｜毛发 #9C846C / #A89078（灰棕）｜勾线 #2E2A26（墨）
 *   页面底/标题栏从奶油往亮处提，强调色往暗处压，保证对比度又不跳出蓝。
 */
export class Palette {
  /** 页面底色（设置页、关于页这类原生页的整页背景） */
  static page(theme: string): string {
    return themePalette(theme).page;
  }

  /** 标题栏底色 */
  static bar(theme: string): string {
    return themePalette(theme).bar;
  }

  /**
   * 底栏 / 手势条区域底色。
   * 原生样式下这块是窗口底层画出来的，要跟悬浮 Tab 的材质底色对齐才不会出现小白条。
   */
  static barSoft(theme: string): string {
    return themePalette(theme).barSoft;
  }

  static ink(theme: string): string {
    return themePalette(theme).ink;
  }

  static subInk(theme: string): string {
    return themePalette(theme).subInk;
  }

  /** 强调色：链接文字、选中态、图标描边 */
  static accent(theme: string): string {
    return themePalette(theme).accent;
  }

  /** 主按钮底色 */
  static primary(theme: string): string {
    return themePalette(theme).primary;
  }

  /** 网页灰边映射：深 / 中 / 浅三档，保持原网页边框的层次 */
  static line(theme: string): string {
    return themePalette(theme).line;
  }

  static lineSoft(theme: string): string {
    return themePalette(theme).lineSoft;
  }

  static lineFaint(theme: string): string {
    return themePalette(theme).lineFaint;
  }
}
