/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourrier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { HdsNavDestination, hdsMaterial } from '@kit.UIDesignKit';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { bundleManager } from '@kit.AbilityKit';
import { Router, BarUtil } from '../common/Nav';
import { NAV_STYLE_CLASSIC } from '../common/PrefsStore';
import { ClassicHeader } from '../view/ClassicHeader';
import {
  COMMUNITY_DOWNLOAD_URL, COMMUNITY_REPO_URL, COMMUNITY_UPSTREAM_URL, COMMUNITY_EMAIL,
  AUTHOR_UPSTREAM_NAME, AUTHOR_UPSTREAM_URL, AUTHOR_SELF_NAME, AUTHOR_SELF_URL
} from '../common/Constants';

/**
 * 社区适配说明页。
 *
 * 放三样东西：装包去哪儿、源码在哪儿、怎么找作者。
 * 之所以单独成页而不是塞进「关于」：这三条都是外部链接，混在隐私说明里容易被当成免责条款忽略。
 */
@Component
export struct CommunityPage {
  @StorageLink('dsh_nav_style') navStyle: string = 'native';
  @State version: string = '';

  aboutToAppear(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.version = info.versionName ?? '';
    } catch (e) {
      this.version = '';
    }
  }

  /** 邮箱只有补全域名后才是可用的地址 */
  private emailReady(): boolean {
    return COMMUNITY_EMAIL.indexOf('.') > 0;
  }

  private copy(text: string): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      pasteboard.getSystemPasteboard().setDataSync(data);
      promptAction.showToast({ message: '链接已复制', duration: 1500 });
    } catch (e) {
      promptAction.showToast({ message: '复制失败', duration: 1500 });
    }
  }

  private openInApp(url: string): void {
    Router.openSub(url);
  }

  private openInBrowser(url: string): void {
    Router.openExternal(url);
  }

  private mailTo(): void {
    if (!this.emailReady()) {
      promptAction.showToast({ message: '作者邮箱尚未补全，请先填写邮箱域名', duration: 2200 });
      return;
    }
    Router.openExternal(`mailto:${COMMUNITY_EMAIL}`);
  }

  /** 一行「角色 + 署名」，点名字跳主页 */
  @Builder
  authorRow(role: string, name: string, url: string) {
    Row() {
      Text(role)
        .fontSize(15)
        .fontColor('#1A1A1A')
        .layoutWeight(1)
      Text(name)
        .fontSize(13)
        .fontColor('#2D8CFA')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => {
      this.openInBrowser(url);
    })
  }

  /** 一行「标题 + 地址 + 复制」 */
  @Builder
  linkRow(title: string, url: string, hint: string, onOpen: () => void) {
    Column({ space: 4 }) {
      Row() {
        Text(title)
          .fontSize(15)
          .fontColor('#1A1A1A')
          .layoutWeight(1)
        Text('打开 >')
          .fontSize(13)
          .fontColor('#2D8CFA')
          .onClick(() => {
            onOpen();
          })
        Text('复制')
          .fontSize(13)
          .fontColor('#9AA0A6')
          .margin({ left: 14 })
          .onClick(() => {
            this.copy(url);
          })
      }
      .width('100%')

      Text(url)
        .fontSize(11.5)
        .fontColor('#8A8F98')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (hint.length > 0) {
        Text(hint)
          .fontSize(11)
          .fontColor('#B0B6BF')
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(Color.White)
    .onClick(() => {
      onOpen();
    })
  }

  @Builder
  card(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor('#8A8F98')
      .margin({ left: 6, top: 10, bottom: 6 })
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.navStyle === NAV_STYLE_CLASSIC) {
          ClassicHeader({
            title: '社区适配',
            onBack: () => {
              Router.pop();
            }
          })
        }
        Scroll() {
          Column() {
            // 头部
            Column({ space: 8 }) {
              Image($r('app.media.app_logo'))
                .width(64)
                .height(64)
                .borderRadius(16)
                .objectFit(ImageFit.Contain)
              Text('我的商大 · 鸿蒙社区适配版')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A1A1A')
              Text(this.version === '' ? '社区维护' : `版本 ${this.version} · 社区维护`)
                .fontSize(12)
                .fontColor('#9AA0A6')
            }
            .width('100%')
            .padding({ top: 18, bottom: 6 })
            .alignItems(HorizontalAlign.Center)

            // 作者：上游与当前维护各一行，两边的名字都要在
            this.card('作者')
            Column() {
              this.authorRow('原始框架', AUTHOR_UPSTREAM_NAME, AUTHOR_UPSTREAM_URL)
              Divider().color('#F0F0F0').strokeWidth(0.5).margin({ left: 16 })
              this.authorRow('本仓库维护', AUTHOR_SELF_NAME, AUTHOR_SELF_URL)
            }
            .width('100%')
            .borderRadius(12)
            .clip(true)
            .backgroundColor(Color.White)

            // 下载与源码
            this.card('下载与源码')
            Column() {
              this.linkRow('应用下载页', COMMUNITY_DOWNLOAD_URL, '包含最新安装包与更新说明', () => {
                this.openInBrowser(COMMUNITY_DOWNLOAD_URL);
              })
              Divider().color('#F0F0F0').strokeWidth(0.5).margin({ left: 16 })
              this.linkRow('开源仓库', COMMUNITY_REPO_URL, '当前版本源码，由 Humour213 维护', () => {
                this.openInBrowser(COMMUNITY_REPO_URL);
              })
              Divider().color('#F0F0F0').strokeWidth(0.5).margin({ left: 16 })
              this.linkRow('上游 GitHub 仓库', COMMUNITY_UPSTREAM_URL, '原始框架，由 Courier 维护', () => {
                this.openInBrowser(COMMUNITY_UPSTREAM_URL);
              })
            }
            .width('100%')
            .borderRadius(12)
            .clip(true)
            .backgroundColor(Color.White)

            // 联系作者
            this.card('联系作者')
            Column() {
              Row() {
                Text('作者邮箱')
                  .fontSize(15)
                  .fontColor('#1A1A1A')
                  .layoutWeight(1)
                Text(this.emailReady() ? COMMUNITY_EMAIL : '待补全')
                  .fontSize(12.5)
                  .fontColor(this.emailReady() ? '#2D8CFA' : '#C0C4CC')
                  .onClick(() => {
                    this.mailTo();
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .onClick(() => {
                this.mailTo();
              })
              if (!this.emailReady()) {
                Text('邮箱域名尚未补全，补全后会显示为可点击的邮件入口')
                  .fontSize(11)
                  .fontColor('#B0B6BF')
                  .width('100%')
                  .padding({ left: 16, right: 16, bottom: 12 })
              }
            }
            .width('100%')
            .borderRadius(12)
            .clip(true)
            .backgroundColor(Color.White)

            // 说明
            this.card('说明')
            Column({ space: 8 }) {
              this.bullet('本应用由社区爱好者适配，并非浙江工商大学官方发布，也不代表学校立场。')
              this.bullet('账号、密码与页面缓存只保存在本机；所有业务请求直连学校官方系统，不经过任何第三方服务器。')
              this.bullet('课表桌面卡片、上课提醒等增强功能同样在本地计算，不上传任何数据。')
              this.bullet('二次分发请保留本页信息与仓库地址，便于使用者溯源与反馈。')
            }
            .width('100%')
            .padding(16)
            .borderRadius(12)
            .alignItems(HorizontalAlign.Start)
            .backgroundColor(Color.White)

            Text('感谢所有参与测试与反馈的同学')
              .fontSize(11)
              .fontColor('#AAAAAA')
              .margin({ top: 18, bottom: 24 })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .constraintSize({ minWidth: '100%' })
        }
        .layoutWeight(1)
        .align(Alignment.Top)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F8FA')
    }
    .titleBar({
      enableComponentSafeArea: true,
      style: {
        originalStyle: {
          backgroundStyle: {
            backgroundColor: '#F7F8FA'
          }
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
      content: {
        title: { mainTitle: '社区适配' }
      }
    })
    .hideTitleBar(this.navStyle === NAV_STYLE_CLASSIC)
    .onShown(() => {
      if (this.navStyle !== NAV_STYLE_CLASSIC) {
        BarUtil.gray();
      }
    })
    .onHidden(() => {
      if (this.navStyle !== NAV_STYLE_CLASSIC) {
        BarUtil.gray();
      }
    })
  }

  @Builder
  bullet(text: string) {
    Row() {
      Text('·')
        .fontSize(14)
        .fontColor('#3D6BE5')
        .fontWeight(FontWeight.Bold)
        .margin({ right: 6 })
      Text(text)
        .fontSize(13)
        .fontColor('#555555')
        .lineHeight(21)
        .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
  }
}
