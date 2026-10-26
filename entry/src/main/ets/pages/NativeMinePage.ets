import { NativeApi, BasicInfo } from '../common/NativeApi';
import { Router } from '../common/Nav';
import { PrefsStore } from '../common/PrefsStore';
import { webview } from '@kit.ArkWeb';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';

class MineItem {
  title: string = '';
  color: string = '#4285F4';
  glyph: string = '✉';
  url: string = '';
  action: string = '';
}

@Component
export struct NativeMinePage {
  @State info: BasicInfo = new BasicInfo();
  @State loading: boolean = true;
  @StorageLink('dsh_session_ready') @Watch('onSessionReady') sessionReady: number = 0;
  private items: MineItem[] = [];

  onSessionReady(): void {
    NativeApi.fetchBasicInfo().then((i: BasicInfo) => {
      this.info = i;
      this.loading = false;
    });
  }

  aboutToAppear(): void {
    this.buildItems();
    NativeApi.fetchBasicInfo().then((i: BasicInfo) => {
      this.info = i;
      this.loading = false;
    });
    setTimeout(() => {
      this.loading = false;
    }, 8000);
  }

  buildItems(): void {
    this.items = [];
    const it = (t: string, c: string, g: string, u: string, a?: string): void => {
      const m = new MineItem();
      m.title = t;
      m.color = c;
      m.glyph = g;
      m.url = u;
      m.action = a ?? '';
      this.items.push(m);
    };
    it('我的邮箱', '#4285F4', '✉', 'https://myapp.zjgsu.edu.cn/my/email-center');
    it('个人数字档案', '#FF9800', '✉', 'https://myapp.zjgsu.edu.cn/my/profile');
    it('安全中心', '#4CAF50', '✓', 'https://myapp.zjgsu.edu.cn/my/safety');
    it('数字金点子', '#FFC107', '…', 'https://myapp.zjgsu.edu.cn/my/index');
    it('我的收藏', '#F44336', '★', 'https://myapp.zjgsu.edu.cn/my/collect');
    it('邮箱中心', '#FFC107', '✉', 'https://myapp.zjgsu.edu.cn/my/email-center');
  }

  async doLogout(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    try {
      webview.WebCookieManager.clearAllCookiesSync();
    } catch (e) {
    }
    await PrefsStore.clearLogin(ctx);
    promptAction.showToast({ message: '已退出登录', duration: 1800 });
    ctx.terminateSelf();
  }

  @Builder
  mineRow(item: MineItem) {
    Row({ space: 14 }) {
      Text(item.glyph)
        .fontSize(18)
        .fontColor(Color.White)
        .width(32)
        .height(32)
        .textAlign(TextAlign.Center)
        .borderRadius(8)
        .backgroundColor(item.color)
      Text(item.title)
        .fontSize(16)
        .fontColor('#333333')
        .layoutWeight(1)
      Text(' >')
        .fontSize(16)
        .fontColor('#CCCCCC')
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 15, bottom: 15 })
    .onClick(() => {
      if (item.action === 'logout') {
        this.doLogout();
      } else if (item.url !== '') {
        Router.openSub(item.url);
      }
    })
  }

  build() {
    Scroll() {
      Column() {
        // 用户卡片
        Row({ space: 18 }) {
          Stack() {
            Circle()
              .width(64)
              .height(64)
              .fill('#E0E0E0')
            Text(this.info.name !== '' ? this.info.name.substring(0, 1) : '?')
              .fontSize(26)
              .fontColor('#BDBDBD')
          }
          .width(64)
          .height(64)

          Text(this.loading ? '加载中…' : (this.info.name !== '' ? this.info.name : '未登录'))
            .fontSize(20)
            .fontColor('#222222')
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .padding(20)
        .borderRadius(12)
        .backgroundColor(Color.White)
        .margin({ top: 12, left: 12, right: 12 })

        // 菜单
        Column() {
          ForEach(this.items, (item: MineItem) => {
            this.mineRow(item)
            Divider().color('#F5F5F5').strokeWidth(0.8).margin({ left: 64 })
          }, (item: MineItem) => item.title)
          this.mineRow(((): MineItem => {
            const m = new MineItem();
            m.title = '退出登录';
            m.color = '#FF9800';
            m.glyph = '←';
            m.action = 'logout';
            return m;
          })())
        }
        .width('100%')
        .borderRadius(12)
        .backgroundColor(Color.White)
        .margin({ top: 12, left: 12, right: 12 })
        .padding({ top: 4, bottom: 4 })

        Text('本应用为第三方社区适配版本')
          .fontSize(10.5)
          .fontColor('#B7BDC4')
          .margin({ top: 20 })
          .onClick(() => {
            Router.stack.pushPathByName('about', '', false);
          })
      }
      .constraintSize({ minWidth: '100%' })
      .padding({ bottom: 90 })
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
