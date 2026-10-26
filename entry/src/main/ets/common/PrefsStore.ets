import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const PREF_NAME = 'dsh_prefs';
const KEY_USER = 'login_user';
const KEY_PASS = 'login_pass';
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
    try {
      const store = await PrefsStore.getStore(ctx);
      const user = (await store.get(KEY_USER, '')) as string;
      const pass = (await store.get(KEY_PASS, '')) as string;
      const l = new SavedLogin();
      l.user = user;
      l.pass = pass;
      return l;
    } catch (e) {
      return new SavedLogin();
    }
  }

  static async saveLogin(ctx: common.UIAbilityContext, user: string, pass: string): Promise<void> {
    const store = await PrefsStore.getStore(ctx);
    await store.put(KEY_USER, user);
    await store.put(KEY_PASS, pass);
    await store.put(KEY_ONBOARDED, true);
    await store.flush();
  }

  static async clearLogin(ctx: common.UIAbilityContext): Promise<void> {
    const store = await PrefsStore.getStore(ctx);
    await store.delete(KEY_USER);
    await store.delete(KEY_PASS);
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

  static async getLastTab(ctx: common.UIAbilityContext): Promise<number> {
    try {
      const store = await PrefsStore.getStore(ctx);
      return (await store.get(KEY_LAST_TAB, 0)) as number;
    } catch (e) {
      return 0;
    }
  }
}
