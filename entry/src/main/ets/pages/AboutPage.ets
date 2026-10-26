import { Router } from '../common/Nav';
import { BarUtil } from '../common/Nav';
import { HdsNavDestination, hdsMaterial } from '@kit.UIDesignKit';
import { ClassicHeader } from '../view/ClassicHeader';
import { NAV_STYLE_CLASSIC } from '../common/PrefsStore';
import { bundleManager } from '@kit.AbilityKit';

@Component
export struct AboutPage {
  @State url: string = '';
  @State appVersion: string = '';
  @StorageLink('dsh_nav_style') navStyle: string = 'native';

  aboutToAppear(): void {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.appVersion = `社区适配版 V${info.versionName}`;
    } catch (e) {
      this.appVersion = '社区适配版';
    }
  }

  build() {
    HdsNavDestination() {
      Column() {
        if (this.navStyle === NAV_STYLE_CLASSIC) {
          ClassicHeader({
            title: '关于与隐私说明',
            onBack: () => {
              Router.pop();
            }
          })
        }
        Scroll() {
          Column({ space: 16 }) {
            Column({ space: 10 }) {
              Image($r('app.media.app_logo'))
                .width(72)
                .height(72)
                .borderRadius(36)
                .objectFit(ImageFit.Contain)
              Text('我的商大')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#222222')
              Text(this.appVersion)
                .fontSize(12)
                .fontColor('#999999')
            }
            .width('100%')
            .margin({ top: 12 })

            Column({ space: 12 }) {
              Text('关于本应用')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#222222')
              Text('本应用是由学生社区基于学校官方“我的商大”移动门户开发的第三方非官方适配版本，旨在为 HarmonyOS（鸿蒙）设备提供可用的校园客户端。')
                .fontSize(13.5)
                .fontColor('#555555')
                .lineHeight(22)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 12 }) {
              Text('隐私与数据说明')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#222222')
              this.bullet('本应用不收集、不上传您的个人信息；登录凭据与页面缓存仅保存在本机，开发者与任何第三方均无法获取。')
              this.bullet('您的统一身份认证账号与密码仅保存在本机应用私有存储中，仅用于自动登录学校官方门户，可随时在本机清除。')
              this.bullet('课表、成绩、校园卡等全部业务均由本应用直接与学校官方系统交互，本应用不篡改、不中转任何通信数据。')
              this.bullet('本应用不包含任何统计、广告或跟踪组件。')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column({ space: 12 }) {
              Text('免责声明')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#222222')
              this.bullet('本应用与浙江工商大学及正方软件股份有限公司无任何隶属或合作关系，仅为学习交流用途。')
              this.bullet('请遵守学校相关管理规定，因使用本应用产生的后果由使用者自行承担。')
              this.bullet('如本应用涉及侵权，请联系开发者，我们将及时处理并删除相关内容。')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Text('继续使用即表示您已阅读并同意以上说明')
              .fontSize(11)
              .fontColor('#AAAAAA')
              .margin({ top: 6 })

            Row() {
              Text('下载与源码、联系作者')
                .fontSize(13)
                .fontColor('#2D8CFA')
              Text(' >')
                .fontSize(13)
                .fontColor('#2D8CFA')
            }
            .margin({ top: 4, bottom: 20 })
            .onClick(() => {
              Router.stack.pushPathByName('community', '', true);
            })
          }
          .padding({ left: 20, right: 20 })
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
        title: { mainTitle: '关于与隐私说明' }
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
        .fontSize(13.5)
        .fontColor('#555555')
        .lineHeight(21)
        .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Top)
    .width('100%')
  }
}
