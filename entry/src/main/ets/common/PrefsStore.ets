/*
 * 我的商大 · HarmonyOS 社区适配版
 * 原始框架 © Courier — https://github.com/ZHOUcourier/myshangda-harmonyos
 * 本仓库改动 © Humour213 — https://github.com/Humour213/myshangda-harmonyos
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CredVault } from './CredVault';
import { CredStore, CredPair } from './CredStore';

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
      // 首选系统的资产存储。这条路是 0.2.24 起的主路径，
      // 因为 HUKS 自拼 AES-GCM 在实测设备上往返校验从来没通过过。
      const pair: CredPair = await CredStore.load();
      if (pair.user !== '' && pair.pass !== '') {
        l.user = pair.user;
        l.pass = pair.pass;
        return l;
      }
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
        // 有密文却解不回来：密钥被换过、或者当初写进去的就是解不开的。
        // 这条日志是「记住密码突然失效」唯一能对得上的线索，别省。
        hilog.warn(0x0001, 'PrefsStore', 'ciphertext present but decrypt failed: %{public}d/%{public}d chars',
          l.user.length, l.pass.length);
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
   * 把遗留的明文凭据迁到系统资产存储，返回是否迁移成功。
   *
   * 迁不动（资产存储不可用）时原样保留明文，先保住自动登录；
   * 等用户下次真正登录时再由 saveLogin 统一处理。
   */
  static async migrateLegacy(ctx: common.UIAbilityContext): Promise<boolean> {
    try {
      const store = await PrefsStore.getStore(ctx);
      const user = (await store.get(KEY_USER, '')) as string;
      const pass = (await store.get(KEY_PASS, '')) as string;
      if (user === '' || pass === '') {
        return false;
      }
      if (!(await CredStore.save(user, pass))) {
        return false;
      }
      // 回读校验通过才删明文，否则明文先留着 —— 不能因为迁移把用户唯一的凭据搞丢
      const back: CredPair = await CredStore.load();
      if (back.user !== user || back.pass !== pass) {
        return false;
      }
      await store.delete(KEY_USER);
      await store.delete(KEY_PASS);
      await store.delete(KEY_USER_ENC);
      await store.delete(KEY_PASS_ENC);
      await store.flush();
      hilog.info(0x0001, 'PrefsStore', 'legacy plaintext migrated to asset store');
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
    await store.put(KEY_ONBOARDED, true);
    // 主路径：系统资产存储。存下了就把 preferences 里可能残留的四份历史凭据清掉，
    // 免得日后读的时候被旧数据盖住（getLogin 是先读资产、再回退到这里的）。
    if (await CredStore.save(user, pass)) {
      await store.delete(KEY_USER);
      await store.delete(KEY_PASS);
      await store.delete(KEY_USER_ENC);
      await store.delete(KEY_PASS_ENC);
      await store.flush();
      hilog.info(0x0001, 'PrefsStore', 'login saved (asset store)');
      return true;
    }
    // 资产存储不可用（少见）：退回自己拼的 HUKS 加密
    hilog.warn(0x0001, 'PrefsStore', 'asset store unavailable, try HUKS');
    let ok: boolean = await PrefsStore.tryStoreEncrypted(store, user, pass);
    if (!ok) {
      // 往返校验没过。最常见的原因是设备上那把密钥跟现在的参数对不上
      // （早期版本的别名沿用到今天），删掉重建一把再试一次就能过。
      // 这一步不丢任何有效数据 —— 此刻本来就没存成功。
      hilog.warn(0x0001, 'PrefsStore', 'encrypt roundtrip failed, reset key and retry');
      await CredVault.resetKey();
      ok = await PrefsStore.tryStoreEncrypted(store, user, pass);
    }
    if (ok) {
      await store.flush();
      hilog.info(0x0001, 'PrefsStore', 'login saved (huks)');
      return true;
    }
    // 两条路都不通：一个字节的凭据都不留，绝不落明文
    hilog.warn(0x0001, 'PrefsStore', 'no secure store available, credentials NOT saved');
    await store.delete(KEY_USER);
    await store.delete(KEY_PASS);
    await store.delete(KEY_USER_ENC);
    await store.delete(KEY_PASS_ENC);
    await store.flush();
    return false;
  }

  /**
   * 加密 + 往返校验 + 写盘，三步都过才算成功。
   *
   * 往返校验不能省：HUKS 在某些设备/参数组合下会产出解不回来的密文，
   * 那种密文写进去等于没记住（下次读到空串）。宁可这次不存，也不能存一份解不开的。
   */
  private static async tryStoreEncrypted(store: preferences.Preferences, user: string,
    pass: string): Promise<boolean> {
    let eu = '';
    let ep = '';
    try {
      eu = await CredVault.encrypt(user);
      ep = await CredVault.encrypt(pass);
      if (eu === '' || ep === '') {
        return false;
      }
      const vu = await CredVault.decrypt(eu);
      const vp = await CredVault.decrypt(ep);
      if (vu !== user || vp !== pass) {
        hilog.warn(0x0001, 'PrefsStore', 'roundtrip mismatch: got %{public}d/%{public}d chars',
          vu.length, vp.length);
        return false;
      }
    } catch (e) {
      hilog.warn(0x0001, 'PrefsStore', 'encrypt threw');
      return false;
    }
    await store.put(KEY_USER_ENC, eu);
    await store.put(KEY_PASS_ENC, ep);
    await store.delete(KEY_USER);
    await store.delete(KEY_PASS);
    return true;
  }

  static async clearLogin(ctx: common.UIAbilityContext): Promise<void> {
    // 资产存储与 preferences 两处都要清：任一处留着都会让「退出登录」变成假的
    await CredStore.clear();
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
