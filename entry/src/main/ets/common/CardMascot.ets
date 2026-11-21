/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */

/**
 * 桌面卡片的贴纸资源选择 —— 集中在这里，4 个 widget 只管调用。
 *
 * 为什么集中：ArkTS 的 $r('app.media.xxx') 只认字面量，不能拼字符串，
 * 所以没法像应用内 MascotPool 那样按主题查表自动取图。这里用 if 分支穷举，
 * 每加一个带贴纸的主题，只在 pick() 里加一个分支即可，widget 不用动。
 *
 * 吉蛙 13 张已入库，卡片按 rest / success / passive 三个语义各取一张。
 */
export class CardMascot {
  /**
   * 取某个主题、某个贴纸语义（rest / success / passive）的卡片贴纸。
   * 返回 undefined 表示该主题暂无卡片贴纸，组件就不渲染 Image。
   */
  static pick(theme: string, mascot: string): Resource | undefined {
    if (theme === 'douni') {
      if (mascot === 'rest') {
        return $r('app.media.douni_rest_01');
      }
      if (mascot === 'success') {
        return $r('app.media.douni_success_01');
      }
      return $r('app.media.douni_passive_01');
    }
    if (theme === 'jiwa') {
      if (mascot === 'rest') {
        return $r('app.media.jiwa_05');
      }
      if (mascot === 'success') {
        return $r('app.media.jiwa_08');
      }
      return $r('app.media.jiwa_01');
    }
    return undefined;
  }
}
