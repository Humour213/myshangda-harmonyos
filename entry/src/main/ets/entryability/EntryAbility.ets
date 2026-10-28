/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { isHttpUrl } from '../common/Constants';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility';

export function consumeTargetUrl(want: Want | undefined): void {
  const uri = want?.uri ?? '';
  if (uri && isHttpUrl(uri)) {
    AppStorage.setOrCreate('dsh_targetUrl', uri);
  }
  // 桌面课表卡片点击：postCardAction 带过来的是 tab，直接落到对应底栏
  const tab = (want?.parameters?.tab ?? '') as string;
  if (tab !== '') {
    AppStorage.setOrCreate('dsh_targetTab', tab);
  }
  const sc = (want?.parameters?.shortcut ?? '') as string;
  if (sc !== '') {
    const map: Record<string, string> = {
      'scan': 'dsh://scan',
      'grade': 'https://jwxt.zjgsu.edu.cn/jwglxt/cjcx/cjcx_cxDgXscj.html?gnmkdm=N305005',
      'schedule': 'https://myapp.zjgsu.edu.cn/kb/index.html',
      'code': 'https://myapp.zjgsu.edu.cn/xyk/index.html'
    };
    const target = map[sc];
    if (target !== undefined) {
      AppStorage.setOrCreate('dsh_targetUrl', target);
    }
  }
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
    try {
      webview.WebviewController.initializeWebEngine();
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'init web engine failed %{public}s', JSON.stringify(e));
    }
    consumeTargetUrl(want);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    consumeTargetUrl(want);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading the content.');
      try {
        const win = windowStage.getMainWindowSync();
        win.setWindowSystemBarProperties({
          statusBarColor: '#2D8CFA',
          statusBarContentColor: '#FFFFFF'
        });
      } catch (e) {
      }
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }
}
