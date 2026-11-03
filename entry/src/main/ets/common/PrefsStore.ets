/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { CredVault } from './CredVault';

const PREF_NAME = 'dsh_prefs';
const KEY_USER = 'login_user';
const KEY_PASS = 'login_pass';
// HUKS 加密后的凭据（AES-256-GCM，密钥由系统保管、不可导出）
const KEY_USER_ENC = 'login_user_enc';
const KEY_PASS_ENC = 'login_pass_enc';
const KEY_LAST_TAB = 'last_tab';
const KEY_ONBOARDED = 'onboarded';
const KEY_AGREED = 'statement_agreed_v1';
const KEY_NAV_STYLE = 'nav_style';
/** 上课提醒总开关 */
const KEY_REMIND_ON = 'remind_on';

export const NAV_STYLE_NATIVE = 'native';
export const NAV_STYLE_CLASSIC = 'classic';

export class SavedLogin {
  user: string = '';
  pass: string = '';
}

export class PrefsStore {
  static async getStore(ctx: common.UIAbilityContext): Promise<preferences.Preferences> {
    return preferences.getPreferences(ctx, { name: PREF_NAME });
  }

  static async getLogin(ctx: common.UIAbilityContext): Promise<SavedLogin> {
    const l = new SavedLogin();
    try {
      const store = await PrefsStore.getStore(ctx);
      // 优先读 HUKS 密文
      const eu = (await store.get(KEY_USER_ENC, '')) as string;
      const ep = (await store.get(KEY_PASS_ENC, '')) as string;
      if (eu !== '' && ep !== '') {
        l.user = await CredVault.decrypt(eu);
        l.pass = await CredVault.decrypt(ep);
        if (l.user !== '' && l.pass !== '') {
          return l;
        }
      }
      // 旧版本留下的明文凭据：读出来顺手迁到密文。
      // 迁移**不能**走 saveLogin —— 那条路在加密不可用时会把四个键全清掉，
      // 等于在这次启动里把用户唯一的凭据抹了；这里用非破坏性的 migrateLegacy。
      const user = (await store.get(KEY_USER, '')) as string;
      const pass = (await store.get(KEY_PASS, '')) as string;
      if (user !== '' && pass !== '') {
        l.user = user;
        l.pass = pass;
        PrefsStore.migrateLegacy(ctx).catch(() => {
        });
      }
      return l;
    } catch (e) {
      return l;
    }
  }

  /**
   * 把遗留的明文凭据迁移成密文，返回是否迁移成功。
   *
   * 迁不动（本机 HUKS 不可用）时原样保留明文，先保住自动登录；
   * 等用户下次真正登录时再由 saveLogin 统一处理（那时能加密就加密，不能就不存）。
   */
  static async migrateLegacy(ctx: common.UIAbilityContext): Promise<boolean> {
    try {
      const store = await PrefsStore.getStore(ctx);
      const user = (await store.get(KEY_USER, '')) as string;
      const pass = (await store.get(KEY_PASS, '')) as string;
      if (user === '' || pass === '') {
        return false;
      }
      const eu = await CredVault.encrypt(user);
      const ep = await CredVault.encrypt(pass);
      if (eu === '' || ep === '') {
        return false;
      }
      // 往返校验通过才落盘，否则明文先留着
      if ((await CredVault.decrypt(eu)) !== user || (await CredVault.decrypt(ep)) !== pass) {
        return false;
      }
      await store.put(KEY_USER_ENC, eu);
      await store.put(KEY_PASS_ENC, ep);
      await store.delete(KEY_USER);
      await store.delete(KEY_PASS);
      await store.flush();
      return true;
    } catch (e) {
      return false;
    }
  }

  /**
   * 保存账号密码。**加密不可用时宁可不存，也不落明文**，返回是否真的存下了。
   *
   * 以前加密失败会退回到 preferences 明文存一份，理由是「保证记住密码这个功能不失效」。
   * 这个取舍是错的：preferences 是应用沙箱里的普通文件，能被备份、能被三方工具读到，
   * 而这里存的是统一身份认证的密码 —— 一旦泄露，学生所有校内系统（教务、邮箱、一卡通）都跟着失守。
   * 现在改成失败就不存，界面上如实告诉用户「密码没记住」。
   *
   * 注意：调用方要处理返回 false 的情况，不能一律提示「已记住账号密码」。
   */
  static async saveLogin(ctx: common.UIAbilityContext, user: string, pass: string): Promise<boolean> {
    const store = await PrefsStore.getStore(ctx);
    // 加密失败就退回明文存储，保证「记住密码」这个功能本身不失效
    let eu = '';
    let ep = '';
    try {
      eu = await CredVault.encrypt(user);
      ep = await CredVault.encrypt(pass);
      // 立刻解一次做往返校验：HUKS 在某些设备/参数组合下会产出解不回来的密文，
      // 那种情况不能写进去，否则用户下次启动读到空串，等于没记住。
      if (eu === '' || ep === '') {
        eu = '';
        ep = '';
      } else {
        const vu = await CredVault.decrypt(eu);
        const vp = await CredVault.decrypt(ep);
        if (vu !== user || vp !== pass) {
          eu = '';
          ep = '';
        }
      }
    } catch (e) {
      eu = '';
      ep = '';
    }
    await store.put(KEY_ONBOARDED, true);
    if (eu !== '' && ep !== '') {
      await store.put(KEY_USER_ENC, eu);
      await store.put(KEY_PASS_ENC, ep);
      await store.delete(KEY_USER);
      await store.delete(KEY_PASS);
      await store.flush();
      return true;
    }
    // 加密这条路不通：把四个键全清掉，一个字节的凭据都不留。
    await store.delete(KEY_USER);
    await store.delete(KEY_PASS);
    await store.delete(KEY_USER_ENC);
    await store.delete(KEY_PASS_ENC);
    await store.flush();
    return false;
  }

  static async clearLogin(ctx: common.UIAbilityContext): Promise<void> {
    const store = await PrefsStore.getStore(ctx);
    await store.delete(KEY_USER);
    await store.delete(KEY_PASS);
    await store.delete(KEY_USER_ENC);
    await store.delete(KEY_PASS_ENC);
    await store.flush();
  }

  static async hasOnboarded(ctx: common.UIAbilityContext): Promise<boolean> {
    try {
      const store = await PrefsStore.getStore(ctx);
      return (await store.get(KEY_ONBOARDED, false)) as boolean;
    } catch (e) {
      return false;
    }
  }

  static async isStatementAgreed(ctx: common.UIAbilityContext): Promise<boolean> {
    try {
      const store = await PrefsStore.getStore(ctx);
      return (await store.get(KEY_AGREED, false)) as boolean;
    } catch (e) {
      return false;
    }
  }

  static async setStatementAgreed(ctx: common.UIAbilityContext): Promise<void> {
    const store = await PrefsStore.getStore(ctx);
    await store.put(KEY_AGREED, true);
    await store.flush();
  }

  static async getNavStyle(ctx: common.UIAbilityContext): Promise<string> {
    try {
      const store = await PrefsStore.getStore(ctx);
      const v = (await store.get(KEY_NAV_STYLE, NAV_STYLE_NATIVE)) as string;
      return v === NAV_STYLE_CLASSIC ? NAV_STYLE_CLASSIC : NAV_STYLE_NATIVE;
    } catch (e) {
      return NAV_STYLE_NATIVE;
    }
  }

  static async setNavStyle(ctx: common.UIAbilityContext, style: string): Promise<void> {
    try {
      const store = await PrefsStore.getStore(ctx);
      await store.put(KEY_NAV_STYLE, style);
      await store.flush();
    } catch (e) {
    }
  }

  static async saveLastTab(ctx: common.UIAbilityContext, tab: number): Promise<void> {
    try {
      const store = await PrefsStore.getStore(ctx);
      await store.put(KEY_LAST_TAB, tab);
      await store.flush();
    } catch (e) {
    }
  }

  /**
   * 上次停留的 Tab。
   * 默认返回 -1 表示「没记录过」，由调用方决定落哪个 Tab
   * （不能用 0 当默认值，否则首启会落到第一个 Tab 而不是主页）。
   */
  static async getLastTab(ctx: common.UIAbilityContext): Promise<number> {
    try {
      const store = await PrefsStore.getStore(ctx);
      return (await store.get(KEY_LAST_TAB, -1)) as number;
    } catch (e) {
      return -1;
    }
  }

  /** 上课提醒是否开启。默认开启（这个功能原本就有，给的是「关掉」的选项） */
  static async isRemindOn(ctx: common.UIAbilityContext): Promise<boolean> {
    try {
      const store = await PrefsStore.getStore(ctx);
      return (await store.get(KEY_REMIND_ON, true)) as boolean;
    } catch (e) {
      return true;
    }
  }

  static async setRemindOn(ctx: common.UIAbilityContext, on: boolean): Promise<void> {
    try {
      const store = await PrefsStore.getStore(ctx);
      await store.put(KEY_REMIND_ON, on);
      await store.flush();
    } catch (e) {
    }
  }
}
