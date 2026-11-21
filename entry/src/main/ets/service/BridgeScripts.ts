// 注入到每个页面的 document-start 脚本：滚动/路由桥接 + 退出登录接管。
// 优先使用 registerJavaScriptProxy 注入的 window.__dshNative；注册晚于脚本执行时先排队。
export const PAGE_BRIDGE_JS = `(function(){
  // 页面 JS 异常转 console，方便 hilog 侧定位 H5 点击无反应的根因
  try {
    window.addEventListener('error', function(e){
      try { console.log('[dsh-err] ' + (e && e.message) + ' @' + (e && e.filename) + ':' + (e && e.lineno)); } catch (x) {}
    });
    window.addEventListener('unhandledrejection', function(e){
      try { console.log('[dsh-rej] ' + (e && e.reason)); } catch (x) {}
    });
  } catch (e) {}
  // zfsoft H5 的 isAppType 分支会调原生桥（flutter_inappwebview/WebViewJavascriptBridge），
  // 有 window.android 时转给它执行，没有则记到原生日志，避免点击被吞
  function forward(name, arg, cb){
    try {
      var a = window.android;
      if (a && typeof a[name] === 'function') {
        if (arg && arg.length !== undefined) { a[name].apply(a, arg); } else if (arg !== undefined) { a[name](arg); } else { a[name](); }
      } else if (window.__dshNative && typeof window.__dshNative.onJsBridge === 'function') {
        window.__dshNative.onJsBridge(name + ' ' + JSON.stringify(arg === undefined ? null : arg));
      }
    } catch (e) {}
    if (typeof cb === 'function') { cb(undefined); }
  }
  try {
    if (!window.flutter_inappwebview) {
      window.flutter_inappwebview = { callHandler: function(name, arg){ forward(name, arg); return Promise.resolve(undefined); } };
    }
    if (!window.WebViewJavascriptBridge) {
      window.WebViewJavascriptBridge = { callHandler: function(n, d, cb){ forward(n, d, cb); }, registerHandler: function(){}, init: function(){}, send: function(){}, ready: function(){ if (typeof arguments[0] === 'function') { arguments[0](); } } };
    }
  } catch (e) {}
  function nativeReady(){ return typeof window.__dshNative !== 'undefined' && window.__dshNative; }
  var queue = [];
  function send(method, arg){
    if (nativeReady()) {
      try { window.__dshNative[method](arg); } catch (e) {}
    } else {
      queue.push([method, arg]);
    }
  }
  window.__dshNav = {
    onScroll: function(y){ send('onScroll', y); },
    onRoute: function(u){ send('onRoute', u); }
  };
  // 供原生扫码完成后回传结果：H5 侧注册了回调就回调，同时派发自定义事件
  window.__dshScanResult = function(text){
    try {
      window.dispatchEvent(new CustomEvent('dshscan', { detail: { text: text } }));
    } catch (e) {}
    if (typeof window.__dshScanCallback === 'function') {
      try { window.__dshScanCallback(text); } catch (e) {}
    }
  };
  window.addEventListener('scroll', function(){
    try { window.__dshNav.onScroll(window.scrollY || document.documentElement.scrollTop || 0); } catch (e) {}
  }, { passive: true });
  function route(){ try { window.__dshNav.onRoute(location.href); } catch (e) {} }
  try {
    var hs = window.history;
    if (hs && hs.pushState) {
      var op = hs.pushState.bind(hs);
      hs.pushState = function(){ var r = op.apply(null, arguments); setTimeout(route, 80); return r; };
      var orp = hs.replaceState.bind(hs);
      hs.replaceState = function(){ var r = orp.apply(null, arguments); setTimeout(route, 80); return r; };
    }
  } catch (e) {}
  window.addEventListener('popstate', function(){ setTimeout(route, 80); });
  window.addEventListener('load', function(){ setTimeout(route, 150); });
  var timer = setInterval(function(){
    if (nativeReady()) {
      for (var i = 0; i < queue.length; i++) {
        try { window.__dshNative[queue[i][0]](queue[i][1]); } catch (e) {}
      }
      queue = [];
      clearInterval(timer);
    }
  }, 300);
  setTimeout(function(){ clearInterval(timer); }, 8000);

  // ===== 退出登录接管 =====
  // 门户「我的」页原本叫「身份切换」，点开是个抽屉，抽屉里还有一条会跳到二级首页的账号行。
  // 这里做两件事：
  //   1. 文案统一成「退出登录」，让用户知道点了会发生什么；
  //   2. 捕获阶段拦下点击，交给原生清 Cookie 并回到登录页。
  // 用事件委托而不是逐个绑定，抽屉是动态插入的也能命中。
  try {
    if (!window.__dshLogoutHooked) {
      window.__dshLogoutHooked = true;
      var norm = function(s){ return String(s || '').replace(/\\s/g, ''); };
      var isLogoutText = function(t){
        var n = norm(t);
        if (n.length === 0 || n.length > 12) { return false; }
        return n.indexOf('退出登录') >= 0 || n.indexOf('身份切换') >= 0 ||
          n.indexOf('安全退出') >= 0 || n.indexOf('注销登录') >= 0;
      };
      document.addEventListener('click', function(e){
        var t = e.target;
        for (var k = 0; k < 5 && t && t !== document.documentElement; k++) {
          if (isLogoutText(t.innerText)) {
            e.preventDefault();
            e.stopPropagation();
            if (e.stopImmediatePropagation) { e.stopImmediatePropagation(); }
            send('onLogout', '');
            return;
          }
          t = t.parentElement;
        }
      }, true);
      var renamed = false;
      var rename = function(){
        if (renamed) { return; }
        var els = document.querySelectorAll('div,span,a,li,button,p');
        for (var i = 0; i < els.length; i++) {
          if (els[i].children.length > 2) { continue; }
          if (norm(els[i].innerText) === '身份切换') {
            els[i].innerText = '退出登录';
            renamed = true;
            return;
          }
        }
      };
      // 只负责首屏文案替换；找到后或最多扫 36 秒就停，避免页面生命周期里一直空转
      var renameTicks = 0;
      var renameTimer = setInterval(function(){
        renameTicks++;
        rename();
        if (renamed || renameTicks >= 30) { clearInterval(renameTimer); }
      }, 1200);
      // 抽屉里那条「2507090113(本科生)」会把页面带去二级首页，不是用户想要的行为，直接吞掉
      var acctPat = /^[0-9A-Za-z]{6,}\\s*[（(]\\s*(本科生|研究生|专科生|教职工|学生|教师)\\s*[)）]$/;
      document.addEventListener('click', function(e){
        var t = e.target;
        for (var k = 0; k < 5 && t && t !== document.documentElement; k++) {
          var tx = String(t.innerText || '').trim();
          if (tx.length > 0 && tx.length < 30 && acctPat.test(tx)) {
            e.preventDefault();
            e.stopPropagation();
            if (e.stopImmediatePropagation) { e.stopImmediatePropagation(); }
            return;
          }
          t = t.parentElement;
        }
      }, true);
    }
  } catch (e) {}
})();`;

// 离线数据缓存：在线时记录 GET 的 fetch/XHR 响应，离线时直接回放。
// 门户/校园码这类“壳能缓存、数据请求失败”的页面，靠它保住最后一次可用的内容。
export const NET_CACHE_JS = `(function(){
  if (window.__dshNetCache) { return; }
  window.__dshNetCache = true;
  var PREFIX = '__dsh_http_cache_v1__';
  var MAX_ENTRIES = 40;
  var MAX_BODY = 400 * 1024;
  function absUrl(u){
    try { return new URL(u, location.href).href; } catch (e) { return u; }
  }
  function offline(){
    try { return navigator.onLine === false || window.__dshOffline === true; } catch (e) { return false; }
  }
  function cacheGet(u){
    try { var s = localStorage.getItem(PREFIX + u); return s ? JSON.parse(s) : null; } catch (e) { return null; }
  }
  function prune(){
    try {
      var arr = [];
      for (var i = 0; i < localStorage.length; i++) {
        var k = localStorage.key(i);
        if (k && k.indexOf(PREFIX) === 0) {
          var v = cacheGet(k.substring(PREFIX.length));
          arr.push([k, v ? v.t : 0]);
        }
      }
      if (arr.length <= MAX_ENTRIES) { return; }
      arr.sort(function(a, b){ return a[1] - b[1]; });
      var del = arr.length - MAX_ENTRIES;
      for (var j = 0; j < del; j++) { localStorage.removeItem(arr[j][0]); }
    } catch (e) {}
  }
  function cachePut(u, body, status, type){
    try {
      if (!u || !body || body.length > MAX_BODY) { return; }
      localStorage.setItem(PREFIX + u, JSON.stringify({ t: Date.now(), s: status || 200, c: type || '', b: body }));
      if (Math.random() < 0.2) { prune(); }
    } catch (e) {}
  }
  var of = window.fetch;
  if (of) {
    window.fetch = function(input, init){
      var url = (typeof input === 'string') ? input : (input && input.url ? input.url : '');
      var method = ((init && init.method) || (input && input.method) || 'GET').toUpperCase();
      if (method !== 'GET' || !url) { return of.apply(this, arguments); }
      url = absUrl(url);
      var hit = cacheGet(url);
      if (hit && offline()) {
        return Promise.resolve(new Response(hit.b, {
          status: hit.s, headers: { 'Content-Type': hit.c || 'application/json' }
        }));
      }
      return of.apply(this, arguments).then(function(r){
        try {
          if (r && r.ok) {
            r.clone().text().then(function(t){ cachePut(url, t, r.status, r.headers.get('content-type')); }).catch(function(){});
          }
        } catch (e) {}
        return r;
      }).catch(function(err){
        var c = cacheGet(url);
        if (c) {
          return new Response(c.b, { status: c.s, headers: { 'Content-Type': c.c || 'application/json' } });
        }
        throw err;
      });
    };
  }
  var X = window.XMLHttpRequest;
  if (X && X.prototype) {
    var origOpen = X.prototype.open;
    var origSend = X.prototype.send;
    X.prototype.open = function(method, url){
      try { this.__dshUrl = absUrl(url); this.__dshMethod = (method || 'GET').toUpperCase(); } catch (e) {}
      return origOpen.apply(this, arguments);
    };
    X.prototype.send = function(body){
      var xhr = this;
      var url = this.__dshUrl;
      var method = this.__dshMethod;
      var hit = (method === 'GET' && url) ? cacheGet(url) : null;
      if (hit && offline()) {
        setTimeout(function(){
          try {
            var parsed = (xhr.responseType === 'json') ? JSON.parse(hit.b) : hit.b;
            Object.defineProperty(xhr, 'readyState', { configurable: true, get: function(){ return 4; } });
            Object.defineProperty(xhr, 'status', { configurable: true, get: function(){ return hit.s; } });
            Object.defineProperty(xhr, 'statusText', { configurable: true, get: function(){ return 'OK'; } });
            Object.defineProperty(xhr, 'responseText', { configurable: true, get: function(){ return hit.b; } });
            Object.defineProperty(xhr, 'response', { configurable: true, get: function(){ return parsed; } });
            Object.defineProperty(xhr, 'responseURL', { configurable: true, get: function(){ return url; } });
            xhr.getAllResponseHeaders = function(){ return 'content-type: ' + (hit.c || 'application/json') + '\\r\\n'; };
            xhr.getResponseHeader = function(n){ return (n && n.toLowerCase() === 'content-type') ? (hit.c || 'application/json') : null; };
            xhr.dispatchEvent(new Event('readystatechange'));
            xhr.dispatchEvent(new ProgressEvent('load'));
            xhr.dispatchEvent(new ProgressEvent('loadend'));
          } catch (e) {}
        }, 0);
        return;
      }
      if (method === 'GET' && url) {
        xhr.addEventListener('load', function(){
          try {
            if (xhr.status >= 200 && xhr.status < 300) {
              var body = (xhr.responseType === 'json') ? JSON.stringify(xhr.response) : xhr.responseText;
              cachePut(url, body, xhr.status, xhr.getResponseHeader('content-type'));
            }
          } catch (e) {}
        });
      }
      return origSend.apply(xhr, arguments);
    };
  }
})();`;

// 页面加载完成后再装 android 兼容桥：document-start 装会让 zfsoft H5 进入半初始化的原生分支导致白屏。
// H5 点击时才会读取 window.android，因此 onPageEnd 注入既不影响首屏渲染，又能恢复点击。
export const ANDROID_BRIDGE_JS = `(function(){
  if (window.__dshAndroidInstalled) { return 'ok'; }
  window.__dshAndroidInstalled = true;
  var pending = [];
  var timer = 0;
  function flush(){
    timer = 0;
    if (!window.__dshNative) {
      if (pending.length > 0) { timer = setTimeout(flush, 200); }
      return;
    }
    for (var i = 0; i < pending.length; i++) {
      try { window.__dshNative[pending[i][0]](pending[i][1]); } catch (e) {}
    }
    pending = [];
  }
  function call(method, arg){
    try {
      if (window.__dshNative && typeof window.__dshNative[method] === 'function') {
        window.__dshNative[method](arg);
        return;
      }
    } catch (e) {}
    pending.push([method, arg]);
    if (!timer) { timer = setTimeout(flush, 200); }
  }
  function abs(url){
    if (typeof url !== 'string' || !url) { return ''; }
    // Android 壳里的本地页面路径，映射到鸿蒙的 rawfile 资源
    if (url.indexOf('file:///android_asset/') === 0) {
      return 'resource://rawfile/' + url.substring('file:///android_asset/'.length);
    }
    try { return new URL(url, location.href).href; } catch (e) { return url; }
  }
  function openWeb(title, url){
    var u = abs(url);
    if (!u) { return; }
    call('openWith', u);
  }
  // 附件类：H5 只传 url（或 url + 文件名），原生负责下载并按类型预览。
  // 学生手册、校车时刻表这类条目走的就是这条路径，缺了它 H5 只会提示“无效的文件参数”。
  function openFile(url, name){
    var u = abs(url);
    if (!u) { return; }
    var payload = { u: u, n: (typeof name === 'string' ? name : '') };
    try { call('onOpenFile', JSON.stringify(payload)); } catch (e) {}
  }
  function scan(cb){
    if (typeof cb === 'function') {
      window.__dshScanCallback = cb;
      try { window.__dshScanCallbackName = 'cb'; } catch (e) {}
    }
    call('onScan', '');
  }
  window.__dshSetScanCallback = function(cb){ if (typeof cb === 'function') { window.__dshScanCallback = cb; } };
  var bridge = {
    openWeb: function(title, url){ openWeb(title, url); },
    openWebWithRefresh: function(title, url){ openWeb(title, url); },
    openWebWithFlag: function(title, url){ openWeb(title, url); },
    GoBack: function(){ try { window.history.back(); } catch (e) {} },
    closeOrigin: function(){ call('closePage', ''); },
    closeOriginWithMsg: function(){ call('closePage', ''); },
    openSetting: function(){},
    openAppOrSmallProgram: function(){},
    addDesktop: function(){},
    APPShare: function(){ call('onShareApp', ''); },
    checkVersion: function(){ call('onCheckVersion', ''); },
    createCalendar: function(){},
    // 退出登录：由原生清 Cookie、清本地凭据并回到登录页
    exitLogin: function(){ call('onLogout', ''); },
    logout: function(){ call('onLogout', ''); },
    signOut: function(){ call('onLogout', ''); },
    // 扫码：多类别名，覆盖不同版本 H5 的写法
    scan: function(cb){ scan(cb); },
    scanCode: function(cb){ scan(cb); },
    scanQRCode: function(cb){ scan(cb); },
    startScan: function(cb){ scan(cb); },
    openScan: function(cb){ scan(cb); },
    // 文件/附件
    openFile: function(url, name){ openFile(url, name); },
    previewFile: function(url, name){ openFile(url, name); },
    viewFile: function(url, name){ openFile(url, name); },
    getFile: function(url, name){ openFile(url, name); },
    openDocument: function(url, name){ openFile(url, name); },
    openAttachment: function(url, name){ openFile(url, name); },
    downLoadFile: function(url, name){ openFile(url, name); },
    downloadFile: function(url, name){ openFile(url, name); },
    // 明确要求“用外部浏览器打开”的入口
    openByBrowser: function(url){ if (typeof url === 'string' && url) { call('onOpenBrowser', abs(url)); } },
    openBrowser: function(url){ if (typeof url === 'string' && url) { call('onOpenBrowser', abs(url)); } },
    openUrl: function(url){ openWeb('', url); },
    gotoLogin: function(){ call('onLogout', ''); },
    setBadge: function(){},
    updateBadgeNew: function(){}
  };
  try { window.android = bridge; } catch (e) {}
  return 'ok';
})();`;

/**
 * 首页搜索框「只跳转、不聚焦」。
 *
 * 学校 H5 原本是：搜索框拿到焦点 → onfocus 里自己跳 /home/search。
 * 这条链导致子页返回后内核又把焦点还给搜索框，软键盘和跳转都跟着回来。
 * 这里在 document-start 抢先拦住搜索框的按下/点击，直接让原生开子页，
 * 从源头不给它聚焦机会。只在门户首页启用，搜索页自己仍可正常输入。
 */
export const SEARCH_NO_FOCUS_JS = `(function(){
  if (window.__dshSearchNoFocus) { return 'ok'; }
  window.__dshSearchNoFocus = true;
  try {
    var p = (location.pathname || '').toLowerCase();
    if (p.indexOf('/home/index') < 0 && p !== '/' && p !== '/home') { return 'skip'; }
    var url = '/home/search';
    try { url = new URL('/home/search', location.href).href; } catch (e) {}
    var last = 0;
    function isSearchBox(el) {
      if (!el || el.nodeType !== 1) { return false; }
      var tag = String(el.tagName || '').toUpperCase();
      if (tag !== 'INPUT' && tag !== 'TEXTAREA' && el.getAttribute('contenteditable') !== 'true') { return false; }
      var s = [el.getAttribute('placeholder'), el.getAttribute('aria-label'), el.getAttribute('name'), el.getAttribute('id')].join(' ');
      if (s.indexOf('搜索') >= 0 || String(el.getAttribute('type') || '').toLowerCase() === 'search') { return true; }
      // 兜底：首页顶部那条搜索框的 placeholder 是「搜索应用、通知」；
      // 站点哪天把属性换空了，就按可见文案再认一次。
      try { if ((el.innerText || el.value || '').indexOf('搜索') >= 0) { return true; } } catch (e) {}
      return false;
    }
    function openSearch() {
      var now = Date.now();
      if (now - last < 1200) { return; }
      last = now;
      if (window.__dshNative && typeof window.__dshNative.openWith === 'function') {
        try { window.__dshNative.openWith(url); } catch (e) {}
        return;
      }
      // document-start 时原生桥可能还没注册；排队等它就绪，期间不碰输入框焦点。
      var tries = 0;
      var timer = setInterval(function(){
        if (window.__dshNative && typeof window.__dshNative.openWith === 'function') {
          clearInterval(timer);
          try { window.__dshNative.openWith(url); } catch (e) {}
          return;
        }
        if (++tries > 40) { clearInterval(timer); }
      }, 100);
    }
    function hook(e) {
      var el = e.target;
      for (var k = 0; k < 4 && el && el.nodeType === 1; k++) {
        if (isSearchBox(el)) {
          try { el.blur(); } catch (e2) {}
          try { e.preventDefault(); } catch (e3) {}
          try { e.stopPropagation(); } catch (e4) {}
          if (e.stopImmediatePropagation) { try { e.stopImmediatePropagation(); } catch (e5) {} }
          openSearch();
          return;
        }
        el = el.parentElement;
      }
    }
    document.addEventListener('touchstart', hook, true);
    document.addEventListener('mousedown', hook, true);
    document.addEventListener('click', hook, true);
    return 'ok';
  } catch (e) { return 'fail'; }
})();`;

// 课表页面周表容器高度修复（ArkWeb 渲染与原壳不一致导致格子重叠/裁切）
export const SCHEDULE_FIX_JS = `(function(){
  try {
    var dds = document.querySelectorAll('dl.week dd');
    if (!dds || dds.length === 0) { return; }
    var maxB = 0;
    for (var i = 0; i < dds.length; i++) {
      var r = dds[i].getBoundingClientRect();
      var b = r.top + (window.scrollY || 0) + r.height;
      if (b > maxB) { maxB = b; }
    }
    if (maxB <= 0) { return; }
    var host = document.querySelector('.schedule-stu-area') || document.body;
    var top = host.getBoundingClientRect().top + (window.scrollY || 0);
    var need = maxB + 12 - top;
    var cur = parseFloat(getComputedStyle(host).height) || 0;
    if (need > cur) { host.style.height = need + 'px'; }
  } catch (e) {}
})();`;

// CAS 登录页自动填充并提交（占位符由 ArkTS 侧替换）
export const AUTO_LOGIN_JS = `(function(){
  try {
    if (window.__dshAutoDone) { return 'ok'; }
    var U = '__DSH_USER__', P = '__DSH_PASS__';
    var u = document.getElementById('username');
    var p = document.getElementById('ppassword') || document.getElementById('password');
    if (!u || !p) { return 'no-form'; }
    window.__dshAutoDone = true;
    var setV = function(el, v){
      var d = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value');
      d.set.call(el, v);
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    };
    setV(u, U);
    setV(p, P);
    // 等页面自己的 RSA 公钥（v2/getPubKey）就绪后再提交；过早点击会被 checkForm 的校验挡下且无任何报错
    var tries = 0;
    var submit = function(){
      try {
        // 每轮提交前重新断言一次输入值。
        // 这个登录页在 ready 里有一句 $("#ppassword").val($("#password").val())，
        // 而 $("#password") 是新页面里的空隐藏域 —— 只要它比我们晚执行，刚填进去的密码就被清成空串，
        // 提交上去等于空密码，服务器必然打回。表现就是「同一组密码刚才还能登，这次却说密码错」。
        if (p.value !== P) { setV(p, P); }
        if (u.value !== U) { setV(u, U); }
        var rsaReady = (typeof Modulus !== 'undefined' && Modulus) &&
          (typeof public_exponent !== 'undefined' && public_exponent);
        var cap = document.getElementById('kaptcha');
        var capVisible = false;
        if (cap) {
          var cs = window.getComputedStyle(cap);
          capVisible = cs.display !== 'none' && cs.visibility !== 'hidden';
        }
        if (capVisible) {
          // 验证码一露头就不能硬提交：checkForm 里会直接 return false，页面纹丝不动，
          // 外面只会看到「一直没反应」，最后被当成密码错误。
          window.__dshProbe = 'captcha';
          return;
        }
        if (rsaReady) {
          var b = document.getElementById('dl');
          if (b) {
            b.click();
            window.__dshProbe = 'submitted';
            console.log('[dsh] auto-login submitted');
          }
          return;
        }
        if (tries++ < 30) {
          setTimeout(submit, 200);
        } else {
          window.__dshProbe = 'blocked';
          console.log('[dsh] auto-login blocked rsa=0');
        }
      } catch (e) {
        window.__dshProbe = 'error';
        console.log('[dsh] auto-login error ' + e);
      }
    };
    setTimeout(submit, 150);
    return 'ok';
  } catch (e) { return 'err'; }
})();`;

/**
 * 读回统一身份认证页的现场状态，用来给失败原因定性。
 *
 * 以前只要提交后被送回登录页，一律报「账号或密码错误」。但同一个 URL 底下可能是三件完全不同的事：
 * 密码真的错、学校要求输验证码、脚本压根没提交上去。三种情况都翻译成同一句话，
 * 用户除了反复重输没有任何可做的动作 —— 真正的验证码被说成密码错误，最误导。
 *
 * 返回 JSON：`e` 页面自己的错误文案（`#errormsg`）、`m` 另一种提示（`#msg`）、
 * `c` 验证码是否可见、`s` 脚本自报的进度（submitted / captcha / blocked / error）、
 * `u` 用户名框里还有几个字符、`p` 密码框里还有几个字符。
 * 密码只报长度、不报内容。
 */
export const PROBE_STATE_JS = `(function(){
  try {
    var g = function(id){ var e = document.getElementById(id); return e ? (e.innerText || e.textContent || '') : ''; };
    var cap = document.getElementById('kaptcha');
    var vis = false;
    if (cap) {
      var cs = window.getComputedStyle(cap);
      vis = cs.display !== 'none' && cs.visibility !== 'hidden';
    }
    var u = document.getElementById('username');
    var p = document.getElementById('ppassword');
    return JSON.stringify({
      e: g('errormsg').replace(/\\s+/g, ' ').trim(),
      m: g('msg').replace(/\\s+/g, ' ').trim(),
      c: vis ? '1' : '0',
      s: window.__dshProbe || '',
      u: u ? String(u.value || '').length : 0,
      p: p ? String(p.value || '').length : 0
    });
  } catch (x) { return '{}'; }
})();`;

// 点击反馈：门户页里的服务图标、列表项按下去原来毫无动静，点没点中全靠猜。
// 用事件委托给被手指按住的那个元素临时加一个 class，`touchend` 后撤掉。
// 只动 transform / opacity —— 两个都不参与布局，不会把页面顶歪。
// 元素自己带 transform（靠位移定位的那种）时退化成只变透明度，免得把它挪回原位。
export const PRESS_FEEDBACK_JS = `(function(){
  try {
    if (window.__dshPressReady) { return 'ok'; }
    window.__dshPressReady = 1;
    var css = '.dsh-press-scale{transform:scale(.94)!important;opacity:.78!important;' +
      'transition:transform .1s ease,opacity .1s ease!important;}' +
      '.dsh-press-fade{opacity:.55!important;transition:opacity .1s ease!important;}';
    var st = document.createElement('style');
    st.setAttribute('data-dsh', 'press');
    st.appendChild(document.createTextNode(css));
    (document.head || document.documentElement).appendChild(st);
    var cur = null;
    function release() {
      if (cur) {
        try { cur.el.classList.remove(cur.cls); } catch (e) {}
        cur = null;
      }
    }
    function pick(t) {
      var el = t, n = 0;
      while (el && el.nodeType === 1 && n < 6) {
        var tag = el.tagName;
        if (tag === 'A' || tag === 'BUTTON' || el.getAttribute('role') === 'button') { return el; }
        try { if (getComputedStyle(el).cursor === 'pointer') { return el; } } catch (e) {}
        el = el.parentElement;
        n++;
      }
      return null;
    }
    document.addEventListener('touchstart', function(e){
      var el = pick(e.target);
      if (!el || el === document.body || el === document.documentElement) { return; }
      if (cur && cur.el === el) { return; }
      release();
      var cls = 'dsh-press-scale';
      try {
        var tr = el.style && el.style.transform;
        if (tr && tr !== 'none') { cls = 'dsh-press-fade'; }
      } catch (e2) {}
      try { el.classList.add(cls); cur = { el: el, cls: cls }; } catch (e3) {}
    }, { passive: true, capture: true });
    document.addEventListener('touchend', function(){ setTimeout(release, 70); }, { passive: true, capture: true });
    document.addEventListener('touchcancel', release, { passive: true, capture: true });
    document.addEventListener('scroll', release, { passive: true, capture: true });
    return 'ok';
  } catch (e) { return 'fail'; }
})();`;
/**
 * 「我的」页去重：藏掉学校网页自带的「退出登录」「APP分享」，以及「推荐软件」整块。
 *
 * 为什么要藏：这些全是门户 H5 自己画的，不是我们写的 ArkTS 组件。退出登录最终也走
 * `Session.confirmAndClear()`，跟设置页底部那个按钮是同一条路；APP分享在设置里给了
 * 官方版 + 社区版，网页那个只会跳 zfsoft 的安卓 APK 下载页，鸿蒙上装不上；
 * 「推荐软件」是推广别的 App 的区块，跟本应用没关系。三样都是纯冗余。
 *
 * 注入点：`WebTab` 的 `javaScriptOnDocumentStart`。0.2.28 挂在 `onPageEnd` 上，
 * 杀后台走缓存恢复时 onPageEnd 可能很早就来过、或者来得比按钮渲染还早，而扫描窗口
 * （4 秒）一过就收工 —— 用户「杀完后台立马点我的」正好落在窗口外面，于是还能看见。
 * 挪到 document-start + 常驻 MutationObserver，节点插进 DOM 的那一下就会被标记。
 *
 * 两类目标，藏的范围不一样：
 *   row   —— 单独一行（退出登录这种按钮）。往上找「这一行除了它没别的文案」的容器，
 *            抓到就藏；抓大了退回只藏文字本身。
 *   block —— 带内容的区块（推荐软件 = 标题 + 一串 App）。判据正好相反：标题的**同级里
 *            还有带文字的兄弟**，说明它是区块标题，连标题带列表一起藏 ——
 *            只藏标题会留下一截孤零零的 App 图标。
 *
 * 仍然不认 id / class，只认文案（学校改版换 class 常见、换文案不常见）。
 * 字体图标（私有区字符）和箭头不算文案，否则 `<i class="icon">&#xe600;</i>退出登录`
 * 这种最常见写法会被判成「这一行还有别的东西」而爬不上去。
 *
 * 诊断：第一次在 /my 页跑起来 1.5 秒后，把页面上「看着能点」的文字打到 console
 * （会被 WebTab 的 onConsole 转到 hilog，tag = WebTabJS）。以后学校换文案导致没藏掉，
 * 看这条 `[dsh-mine]` 日志就知道它现在叫什么，不用再猜。
 *
 * 安全边界：整段包在 try 里，匹配不到就什么都不做（最坏结果＝没生效，不会弄坏页面）；
 * 只在 /my 路径下跑，其它页面直接 return。
 */
export const HIDE_MINE_EXTRA_JS = `(function(){
  try {
    var p = (location.pathname || '').toLowerCase();
    if (p.indexOf('/my') < 0) { return 'skip'; }

    // k = 认得的文案（去空白后全等）；m = 藏的范围
    var RULES = [
      { k: ['退出登录', '退出登陆', '退出'], m: 'row' },
      { k: ['APP分享', 'App分享', '分享APP', 'APP分享给好友'], m: 'row' },
      { k: ['推荐软件', '推荐应用', '应用推荐', '软件推荐'], m: 'block' }
    ];

    function norm(t) { return String(t == null ? '' : t).replace(/[\\s\\u3000]+/g, ''); }
    function glyph(k) {
      return /^[\\uE000-\\uF8FF\\u2190-\\u21FF\\u25A0-\\u25FF\\u2022\\u00B7>»‹·•\\-—|]+$/.test(k);
    }
    function ruleOf(t) {
      var k = norm(t);
      if (k === '') { return null; }
      for (var i = 0; i < RULES.length; i++) {
        if (RULES[i].k.indexOf(k) >= 0) { return RULES[i]; }
      }
      return null;
    }

    // 容器内的可见文字（只看叶子文本节点）。已隐藏的不统计 —— 否则藏过一次之后
    // 容器会显得"空了"，下一次扫描就会继续往上罩，一路罩到整页。
    function texts(root) {
      var out = [], w = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null), n;
      while ((n = w.nextNode())) {
        var k = norm(n.nodeValue);
        if (k === '' || glyph(k)) { continue; }
        var pe = n.parentElement;
        if (pe && pe.offsetParent === null) { continue; }
        out.push(k);
      }
      return out;
    }

    function rowOf(el) {
      var cur = el;
      for (var i = 0; i < 4 && cur && cur.parentElement; i++) {
        var pr = cur.parentElement;
        if (pr === document.body || pr === document.documentElement) { break; }
        var wide = false;
        try {
          var r = pr.getBoundingClientRect();
          wide = r.width >= window.innerWidth * 0.6 && r.height > 0;
        } catch (e) { wide = false; }
        if (!wide) { break; }
        var ts = texts(pr);
        if (ts.length === 0) { break; }
        var other = 0;
        for (var j = 0; j < ts.length; j++) { if (!ruleOf(ts[j])) { other++; } }
        if (other > 0) { break; }
        cur = pr;
      }
      return cur;
    }

    // 区块：标题的父容器里，除了标题这条分支，还有别的带文字的兄弟 —— 那就是它下面的内容。
    // 只认第一次命中的容器，再往上就是整页了。
    // 两个数量闸都是保险，宁可只藏标题，也不能把整页藏了：
    //   sibs <= 8 —— 兄弟一多，说明这不是「标题 + 内容」，而是页面根容器把标题和一堆东西平铺在一起；
    //   texts <= 40 —— 同理，文案条数多到这个程度已经不是区块了。
    function blockOf(el) {
      var cur = el;
      for (var i = 0; i < 3 && cur && cur.parentElement; i++) {
        var pr = cur.parentElement;
        if (pr === document.body || pr === document.documentElement) { break; }
        var sibs = 0;
        try {
          for (var j = 0; j < pr.children.length; j++) {
            var ch = pr.children[j];
            if (ch === cur) { continue; }
            if (norm(ch.textContent) !== '') { sibs++; }
          }
        } catch (e) { sibs = 0; }
        if (sibs > 0 && sibs <= 8) {
          var ts = texts(pr);
          if (ts.length <= 40) { return pr; }
        }
        cur = pr;
      }
      return null;
    }

    function hide(el) {
      if (!el || !el.style || !el.getAttribute) { return 0; }
      if (el.getAttribute('data-dsh-gone') === '1') { return 0; }
      el.setAttribute('data-dsh-gone', '1');
      el.style.setProperty('display', 'none', 'important');
      return 1;
    }

    function invisible(el) {
      try {
        var r = el.getBoundingClientRect();
        return r.width === 0 && r.height === 0;
      } catch (e) { return false; }
    }

    function sweep() {
      var n = 0;
      var all = document.querySelectorAll('body *');
      for (var i = 0; i < all.length; i++) {
        var el = all[i];
        if (el.children && el.children.length > 0) { continue; }
        if (el.getAttribute && el.getAttribute('data-dsh-gone') === '1') { continue; }
        if (invisible(el)) { continue; }
        var r = ruleOf(el.textContent);
        if (!r) { continue; }
        n += hide(r.m === 'block' ? (blockOf(el) || rowOf(el)) : rowOf(el));
      }
      return n;
    }

    // 诊断：把「看着能点」的文字打出来。以后学校换文案导致没藏掉，看这条日志即可。
    function dump() {
      try {
        var out = [], all = document.querySelectorAll('body *');
        for (var i = 0; i < all.length && out.length < 60; i++) {
          var e = all[i];
          if (e.children && e.children.length > 0) { continue; }
          var t = norm(e.textContent);
          if (t === '' || t.length > 10 || glyph(t)) { continue; }
          var ok = false;
          try { ok = getComputedStyle(e).cursor === 'pointer'; } catch (x) {}
          if (!ok && e.tagName && (e.tagName === 'A' || e.tagName === 'BUTTON')) { ok = true; }
          if (!ok && e.parentElement) {
            try { ok = getComputedStyle(e.parentElement).cursor === 'pointer'; } catch (x) {}
          }
          if (!ok) { continue; }
          out.push(t);
        }
        console.log('[dsh-mine] n=' + out.length + ' |' + out.join('|') + '|');
      } catch (e) {}
    }

    if (window.__dshMineReady) {
      // document-start 已经跑过并挂好监听；onPageEnd 会再补注入一次
      // （SPA 内部导航不会重跑 document-start），这里立刻补扫一遍就够了。
      return 'ok:' + sweep();
    }
    window.__dshMineReady = 1;

    // document-start 阶段 documentElement / body 可能都还没长出来，
    // 挂到 document 上，subtree 会覆盖之后出现的一切。
    var root = document.documentElement || document;

    // document-start 时 body 多半还没长出来，这一扫通常是空转；但缓存恢复、页面已经
    // 渲染完才注入的情况（onPageEnd 补注入）就靠它立刻生效，不能省。
    sweep();

    var timer = 0;
    function later() {
      if (timer) { return; }
      timer = setTimeout(function(){ timer = 0; sweep(); }, 120);
    }
    try {
      var mo = new MutationObserver(later);
      mo.observe(root, { childList: true, subtree: true });
    } catch (e) {}

    // 兜底补扫：有些框架靠改 class / 改 innerText 更新界面，不产生节点增删，
    // MutationObserver 收不到。首屏这几轮把这种情况盖住，之后交给 observer 常驻。
    var left = 12;
    var iv = setInterval(function(){ sweep(); if (--left <= 0) { clearInterval(iv); } }, 350);

    setTimeout(dump, 1500);
    return 'ok';
  } catch (e) { return 'fail'; }
})();`;

/**
 * 把网页内容也拉进豆泥主题的色系里。
 *
 * 为什么必须注入：外壳（状态栏 / 标题栏 / 页面底）全在原生侧，改一下 Palette 就行；
 * 但屏幕中间那一大块是学校的 H5，它自己用白底 + 品牌蓝。外壳换成暖奶油之后，
 * 中间还是冷白冷蓝，接缝一眼就看得出来 —— 用户要的"同一个色系"只能进网页里改。
 *
 * 为什么不直接写死 CSS 选择器：门户是登录后的 SPA，抓不到静态 HTML，类名不可知，
 * 而且学校随时改版。所以走"扫一遍 DOM、按**计算样式**打标记类"这条路：
 *   白底 → 打 dshTintW；蓝底 → dshTintB；蓝字 → dshTintT；蓝边框 → dshTintD
 * 再注入一张只管这四个类的样式表。好处是：
 *   1. 不碰元素原本的 inline style（打 class 而不是 setProperty，撤销时干干净净）；
 *   2. 类名带前缀，跟站点自己的类不会撞；
 *   3. 撤销只要删掉 <style> 和那几个 class，网页立刻回到原样。
 *
 * 代价是要逐元素 getComputedStyle，所以限了 5000 个元素、只跑几个时间点，
 * 并且已经打过标记的立刻跳过（SPA 二次渲染时只处理新增的）。
 */
export function themeTintJs(pageBg: string, surface: string, accent: string,
  line: string, lineSoft: string, lineFaint: string): string {
  return `(function(){
  try {
    var PAGE = '${pageBg}', PRI = '${surface}', ACC = '${accent}';
    var LINE = '${line}', LINE_S = '${lineSoft}', LINE_F = '${lineFaint}';
    var SET = { dshTintW: 1, dshTintB: 1, dshTintT: 1, dshTintD: 1,
                dshTintN1: 1, dshTintN2: 1, dshTintN3: 1 };
    var st = document.getElementById('dsh-tint');
    if (!st) {
      st = document.createElement('style');
      st.id = 'dsh-tint';
      (document.head || document.documentElement).appendChild(st);
    }
    st.textContent =
      'html,body{background-color:' + PAGE + ' !important;}' +
      // background-image:none 很关键：站点大量白色块其实是渐变/背景图，不改 backgroundColor 不生效
      '.dshTintW{background-color:' + PAGE + ' !important;background-image:none !important;}' +
      '.dshTintB{background-color:' + PRI + ' !important;background-image:none !important;}' +
      '.dshTintW::before,.dshTintW::after{background-color:' + PAGE + ' !important;}' +
      '.dshTintB::before,.dshTintB::after{background-color:' + PRI + ' !important;}' +
      '.dshTintT{color:' + ACC + ' !important;}' +
      '.dshTintD{border-color:' + ACC + ' !important;}' +
      // 灰边按原深浅映射到主题的三档中性色，保留层次而不是一律染成强调色
      '.dshTintN1{border-color:' + LINE + ' !important;}' +
      '.dshTintN2{border-color:' + LINE_S + ' !important;}' +
      '.dshTintN3{border-color:' + LINE_F + ' !important;}';

    function rgb(c) {
      var m = /rgba?\\((\\d+),\\s*(\\d+),\\s*(\\d+)(?:,\\s*([\\d.]+))?/.exec(c || '');
      if (!m) { return null; }
      var a = m[4] === undefined ? 1 : parseFloat(m[4]);
      if (a < 0.5) { return null; }
      return [+m[1], +m[2], +m[3]];
    }
    function isWhite(c) {
      var v = rgb(c); if (!v) { return false; }
      // 站点里很多"白块"是 #F7F7F7 / #FAFAFA，不是纯白，原来一律漏掉
      return v[0] >= 235 && v[1] >= 235 && v[2] >= 235;
    }
    function isWhiteImage(s) {
      var bi = s.backgroundImage || '';
      if (bi === 'none') { return false; }
      return /rgb\\(\\s*2[3-5]\\d,\\s*2[3-5]\\d,\\s*2[3-5]\\d/.test(bi) ||
             /#fff(?:fff)?\\b|white/i.test(bi);
    }
    function isBlue(c) {
      var v = rgb(c); if (!v) { return false; }
      return v[2] > 110 && (v[2] - Math.max(v[0], v[1])) > 40;
    }
    function tag(el, cls) {
      if (!el.classList || el.classList.contains(cls)) { return; }
      el.classList.add(cls);
    }

    // 课表格子（dl.week dd）保留站点的背景和文字色，避免"棕底棕字"看不清；
    // 边框则按原色系处理：蓝色→强调色，灰色→主题的三档中性灰。
    function inScheduleCell(el) {
      return !!(el.closest && el.closest('dl.week dd'));
    }
    // 取第一条真正可见的边框颜色，避免 border:none 的元素被误判
    function borderColor(s) {
      var w = [s.borderTopWidth, s.borderRightWidth, s.borderBottomWidth, s.borderLeftWidth];
      var c = [s.borderTopColor, s.borderRightColor, s.borderBottomColor, s.borderLeftColor];
      for (var i = 0; i < w.length; i++) {
        if (parseFloat(w[i]) > 0) { return c[i]; }
      }
      return null;
    }
    // 灰色按明暗分三档：深边→LINE，中边→LINE_S，浅边→LINE_F；
    // 彩色（饱和度高）返回 0，交给别的规则处理。
    function grayTier(color) {
      var v = rgb(color); if (!v) { return 0; }
      var hi = Math.max(v[0], v[1], v[2]);
      var lo = Math.min(v[0], v[1], v[2]);
      if (hi - lo > 20) { return 0; }
      var avg = (v[0] + v[1] + v[2]) / 3;
      if (avg >= 250) { return 0; }
      if (avg < 205) { return 1; }
      if (avg < 232) { return 2; }
      return 3;
    }

    var done = 0;
    function paint() {
      if (!document.body) { return done; }
      var all = document.body.getElementsByTagName('*');
      var lim = Math.min(all.length, 5000);
      for (var i = 0; i < lim; i++) {
        var el = all[i];
        if (el.tagName === 'SCRIPT' || el.tagName === 'STYLE') { continue; }
        if (el.getAttribute('data-dsh-tint') === '1') { continue; }
        var s = getComputedStyle(el);
        var inCell = inScheduleCell(el);
        if (!inCell) {
          if (isWhite(s.backgroundColor) || isWhiteImage(s)) { tag(el, 'dshTintW'); }
          else if (isBlue(s.backgroundColor)) { tag(el, 'dshTintB'); }
          if (isBlue(s.color)) { tag(el, 'dshTintT'); }
        }
        // 只动 border-color，不动背景和文字；
        // 蓝色边→强调色，灰色边按原先深浅映射到主题三档中性色。
        var bc = borderColor(s);
        if (bc) {
          if (isBlue(bc)) {
            tag(el, 'dshTintD');
          } else {
            var tier = grayTier(bc);
            if (tier === 1) { tag(el, 'dshTintN1'); }
            else if (tier === 2) { tag(el, 'dshTintN2'); }
            else if (tier === 3) { tag(el, 'dshTintN3'); }
          }
        }
        el.setAttribute('data-dsh-tint', '1');
        done++;
      }
      return done;
    }

    paint();
    setTimeout(paint, 300);
    setTimeout(paint, 900);
    // 后续插入的节点交给下面的 MutationObserver 补扫，不再固定多跑两轮
    // SPA 后续插入的节点不会再走上面几个时间点，挂一个只监听 childList 的观察者补刀。
    // 不监听 attributes，避免 paint() 自己打的 class 触发无限循环。
    if (window.__dshTintObserver) { window.__dshTintObserver.disconnect(); }
    try {
      var pending = null;
      var mo = new MutationObserver(function (records) {
        var added = false;
        for (var i = 0; i < records.length; i++) {
          if (records[i].addedNodes && records[i].addedNodes.length) { added = true; break; }
        }
        if (!added) { return; }
        if (pending) { clearTimeout(pending); }
        pending = setTimeout(paint, 120);
      });
      mo.observe(document.documentElement || document.body, { childList: true, subtree: true });
      window.__dshTintObserver = mo;
    } catch (e) { /* 老内核没有 MutationObserver 就退回到定时扫描 */ }
    return 'ok';
  } catch (e) { return 'fail'; }
})();`;
}

/**
 * 撤销上面的染色，把网页恢复原样。
 *
 * 切回默认主题时必须跑：只删样式表是不够的 —— 标记类留着虽然没人管，
 * 但下次再染色时会被"已处理"的判定跳过，颜色就永远回不来了。
 * 所以这里连 data 标记一起清，让下一次染色从零开始。
 */
export const THEME_UNTINT_JS = `(function(){
  try {
    if (window.__dshTintObserver) { window.__dshTintObserver.disconnect(); window.__dshTintObserver = null; }
    var st = document.getElementById('dsh-tint');
    if (st && st.parentNode) { st.parentNode.removeChild(st); }
    var cls = ['dshTintW', 'dshTintB', 'dshTintT', 'dshTintD',
               'dshTintN1', 'dshTintN2', 'dshTintN3'];
    var hit = document.querySelectorAll('.dshTintW,.dshTintB,.dshTintT,.dshTintD,.dshTintN1,.dshTintN2,.dshTintN3');
    for (var i = 0; i < hit.length; i++) {
      for (var j = 0; j < cls.length; j++) { hit[i].classList.remove(cls[j]); }
    }
    var marked = document.querySelectorAll('[data-dsh-tint]');
    for (var k = 0; k < marked.length; k++) { marked[k].removeAttribute('data-dsh-tint'); }
    return 'ok';
  } catch (e) { return 'fail'; }
})();`;
