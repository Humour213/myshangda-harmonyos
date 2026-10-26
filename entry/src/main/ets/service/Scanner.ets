/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourrier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'Scanner';

/**
 * 扫一扫。
 *
 * 抽成独立服务是因为三个地方都要用：主页顶栏、子页面工具栏、网页桥（H5 里点扫码）。
 * 返回空串表示用户取消或失败，调用方不要弹错误提示——取消是正常操作。
 */
export class Scanner {
  static async scan(ctx: common.UIAbilityContext): Promise<string> {
    try {
      const opts: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.ALL],
        enableMultiMode: false,
        enableAlbum: true
      };
      const res: scanBarcode.ScanResult = await scanBarcode.startScanForResult(ctx, opts);
      const v: string = res.originalValue ?? '';
      hilog.info(DOMAIN, TAG, 'scan result len=%{public}d', v.length);
      return v;
    } catch (e) {
      // 用户取消扫码会走这里，不当成错误
      hilog.info(DOMAIN, TAG, 'scan canceled or failed');
      return '';
    }
  }
}
