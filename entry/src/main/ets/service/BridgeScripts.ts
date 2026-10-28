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
      setInterval(rename, 1200);
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
    setV(u, '__DSH_USER__');
    setV(p, '__DSH_PASS__');
    // 等页面自己的 RSA 公钥（v2/getPubKey）就绪后再提交；过早点击会被 checkForm 的校验挡下且无任何报错
    var tries = 0;
    var submit = function(){
      try {
        var rsaReady = (typeof Modulus !== 'undefined' && Modulus) &&
          (typeof public_exponent !== 'undefined' && public_exponent);
        var cap = document.getElementById('kaptcha');
        var capVisible = false;
        if (cap) {
          var cs = window.getComputedStyle(cap);
          capVisible = cs.display !== 'none' && cs.visibility !== 'hidden';
        }
        if (rsaReady && !capVisible) {
          var b = document.getElementById('dl');
          if (b) {
            b.click();
            console.log('[dsh] auto-login submitted');
          }
          return;
        }
        if (tries++ < 30) {
          setTimeout(submit, 200);
        } else {
          console.log('[dsh] auto-login blocked rsa=' + !!rsaReady + ' captcha=' + capVisible);
        }
      } catch (e) {
        console.log('[dsh] auto-login error ' + e);
      }
    };
    setTimeout(submit, 150);
    return 'ok';
  } catch (e) { return 'err'; }
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
