/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourrier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
export const BRAND_BLUE = '#2D8CFA';

// 统一认证
export const LOGIN_HOST = 'uia.zjgsu.edu.cn';
export const CAS_LOGIN_URL = `https://${LOGIN_HOST}/cas/login`;

// 门户
export const BASE_URL = 'https://myapp.zjgsu.edu.cn';
export const CONTACT_URL = 'https://txl.zjgsu.edu.cn';

// 官方 Android 版安装包下载地址（设置/隐私弹窗中"官方App"跳转）
export const OFFICIAL_APK_URL =
  'https://portal.zfsoft.com:6643/public/pkg/download/AE79A745A3C1779DE0538713470A4D9F';
export const COMMUNITY_URL = 'https://sydxky.cn/';

// ===== 社区适配版信息（关于 / 社区适配页展示） =====
/** 应用分发页（下载站） */
export const COMMUNITY_DOWNLOAD_URL = 'https://www.sydxky.cn/detail.php?id=1068';
/** 本仓库（当前维护版本，源码与 issue 都在这儿） */
export const COMMUNITY_REPO_URL = 'https://github.com/Humour213/myshangda-harmonyos';
/** 上游 GitHub 仓库（原始框架，作者 Courier） */
export const COMMUNITY_UPSTREAM_URL = 'https://github.com/ZHOUcourrier/myshangda-harmonyos';

// ===== 署名：上游与当前维护各一位，关于页与社区页都要露出 =====
/** 原始框架作者 */
export const AUTHOR_UPSTREAM_NAME = 'Courier';
export const AUTHOR_UPSTREAM_URL = 'https://github.com/ZHOUcourrier';
/** 本仓库维护者 */
export const AUTHOR_SELF_NAME = 'Humour213';
export const AUTHOR_SELF_URL = 'https://github.com/Humour213';
/** 作者联系邮箱：域名部分请按实际补全，补全后本行注释可删 */
export const COMMUNITY_EMAIL = 'minchincherrylips6@';

// 门户 H5 只有在 UA 含 zfsoft 时才进入 App 分支（我的页会多出 App 专属菜单）
export const MOBILE_UA =
  'Mozilla/5.0 (Linux; Android 13; HarmonyOS) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Mobile Safari/537.36 zfsoft_zjgs/7.1.25';

export const TAB_HOME = 0;
export const TAB_WORK = 1;
export const TAB_APPROVE = 2;
export const TAB_CONTACT = 3;
export const TAB_MSG = 4;
export const TAB_ME = 5;

/**
 * 底栏 Tab 定义。
 *
 * 图标有两套：
 *   iconOn/iconOff         —— HDS 悬浮底栏用，选中近黑实心 / 未选中中灰线框
 *   iconOnClassic/...      —— 原版样式（蓝色悬浮胶囊）用，选中品牌蓝 / 未选中浅灰
 * 一律 96×96 px（底栏按 24vp 渲染，3x 屏要 72px，位图小于该值会发虚）。
 * 选中/未选中必须形状不同（实心 vs 线框），不能只靠颜色区分。
 */
export class TabDef {
  id: number = 0;
  label: string = '';
  title: string = '';
  iconOn: Resource = $r('app.media.tab_home_on_black');
  iconOff: Resource = $r('app.media.tab_home_off_black');
  iconOnClassic: Resource = $r('app.media.tab_home_on');
  iconOffClassic: Resource = $r('app.media.tab_home_off');
  url: string = BASE_URL;
  needLogin: boolean = true;
}

// 原版底栏（依据官方 iOS 截图）：消息 · 审批 · 首页(居中) · 通讯录 · 我的
export function buildTabs(): TabDef[] {
  const list: TabDef[] = [];

  const msg = new TabDef();
  msg.id = 0;
  msg.label = '消息';
  msg.title = '消息';
  msg.iconOn = $r('app.media.tab_msg_on_black');
  msg.iconOff = $r('app.media.tab_msg_off_black');
  msg.iconOnClassic = $r('app.media.tab_msg_on');
  msg.iconOffClassic = $r('app.media.tab_msg_off');
  msg.url = `${BASE_URL}/message/index2`;
  list.push(msg);

  const approve = new TabDef();
  approve.id = 1;
  approve.label = '审批';
  approve.title = '审批';
  approve.iconOn = $r('app.media.tab_approve_on_black');
  approve.iconOff = $r('app.media.tab_approve_off_black');
  approve.iconOnClassic = $r('app.media.tab_approve_on');
  approve.iconOffClassic = $r('app.media.tab_approve_off');
  approve.url = `${BASE_URL}/message/approveList`;
  list.push(approve);

  const home = new TabDef();
  home.id = 2;
  home.label = '主页';
  home.title = '主页';
  home.iconOn = $r('app.media.tab_home_on_black');
  home.iconOff = $r('app.media.tab_home_off_black');
  home.iconOnClassic = $r('app.media.tab_home_on');
  home.iconOffClassic = $r('app.media.tab_home_off');
  home.url = `${BASE_URL}/home/index`;
  list.push(home);

  const contact = new TabDef();
  contact.id = 3;
  contact.label = '通讯录';
  contact.title = '通讯录';
  contact.iconOn = $r('app.media.tab_contact_on_black');
  contact.iconOff = $r('app.media.tab_contact_off_black');
  contact.iconOnClassic = $r('app.media.tab_contact_on');
  contact.iconOffClassic = $r('app.media.tab_contact_off');
  contact.url = CONTACT_URL;
  list.push(contact);

  const me = new TabDef();
  me.id = 4;
  me.label = '我的';
  me.title = '我的';
  me.iconOn = $r('app.media.tab_me_on_black');
  me.iconOff = $r('app.media.tab_me_off_black');
  me.iconOnClassic = $r('app.media.tab_me_on');
  me.iconOffClassic = $r('app.media.tab_me_off');
  me.url = `${BASE_URL}/my/index`;
  list.push(me);

  return list;
}

export function isLoginUrl(url: string): boolean {
  if (!url) {
    return false;
  }
  const u = url.toLowerCase();
  return u.includes(`://${LOGIN_HOST}/cas/login`);
}

export function isPortalUrl(url: string): boolean {
  if (!url) {
    return false;
  }
  const u = url.toLowerCase();
  return u.includes('://myapp.zjgsu.edu.cn');
}

// 通讯录（zfsoft 通讯录）也走 app-UAH5 分支，二级页依赖 window.android.openWeb
export function isContactUrl(url: string): boolean {
  if (!url) {
    return false;
  }
  return url.toLowerCase().includes('://txl.zjgsu.edu.cn');
}

export function isHttpUrl(url: string): boolean {
  if (!url) {
    return false;
  }
  const u = url.toLowerCase();
  return u.startsWith('http://') || u.startsWith('https://');
}

export function hostOf(url: string): string {
  const m = url.match(/^[a-z]+:\/\/([^/?#]+)/i);
  return m ? m[1].toLowerCase() : '';
}
