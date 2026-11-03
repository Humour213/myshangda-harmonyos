/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { MainShell } from './Index';

/**
 * 与 `pages/Index` 一模一样的页面，唯一区别是路由名。
 *
 * 为什么需要它：系统密码保险箱只在**页面跳转**那一刻去读用户名/密码两个输入框，
 * 判断该弹「保存密码」还是「更新密码」；同一个页面里把界面换掉，它什么都看不到。
 * 所以登录成功时在 `pages/Index` 与 `pages/Main` 之间 replaceUrl ——
 * 界面完全相同、用户无感、栈深度还是 1，但系统实打实看到了一次跳转。
 */
@Entry
@Component
struct MainPage {
  build() {
    Column() {
      MainShell()
    }
    .width('100%')
    .height('100%')
  }
}
