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
      // 旧版本明文凭据：读出来顺手迁移到密文
      const user = (await store.get(KEY_USER, '')) as string;
      const pass = (await store.get(KEY_PASS, '')) as string;
      if (user !== '' && pass !== '') {
        l.user = user;
        l.pass = pass;
        PrefsStore.saveLogin(ctx, user, pass).catch(() => {
        });
      }
      return l;
    } catch (e) {
      return l;
    }
  }

  static async saveLogin(ctx: common.UIAbilityContext, user: string, pass: string): Promise<void> {
    const store = await PrefsStore.getStore(ctx);
    // 加密失败就退回明文存储，保证「记住密码」这个功能本身不失效
    let eu = '';
    let ep = '';
    try {
      eu = await CredVault.encrypt(user);
      ep = await CredVault.encrypt(pass);
      // 立刻解一次做往返校验：HUKS 在某些设备/参数组合下会产出解不回来的密文，
      // 那种情况宁可不加密，也不能让用户每次启动都要重新输密码。
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
    if (eu !== '' && ep !== '') {
      await store.put(KEY_USER_ENC, eu);
      await store.put(KEY_PASS_ENC, ep);
      await store.delete(KEY_USER);
      await store.delete(KEY_PASS);
    } else {
      await store.put(KEY_USER, user);
      await store.put(KEY_PASS, pass);
    }
    await store.put(KEY_ONBOARDED, true);
    await store.flush();
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
}
