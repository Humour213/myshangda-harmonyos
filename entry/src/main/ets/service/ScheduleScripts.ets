/**
 * 从门户首页抓取课表结构（dl.week / dd.tN.cN.kN）。
 *
 * 实测结构：
 *   <div class="schedule-table">
 *     <dl class="week"><dt>星期一</dt>
 *       <dd class="t3 c0 k3"><p>课程名</p><p class="js">教室</p></dd>
 *     </dl>
 *   </div>
 *   t = 起始节次，k = 跨几节，c = 配色序号
 *
 * 历史教训：不要用 MutationObserver 去撑高 dl.week，和页面自身绝对定位打架，
 * 切几次周次课表就空了。这里只读取，不改布局。
 */
export const SCHEDULE_SCRAPE_JS: string = '(function(){try{' +
  'var st=document.querySelector(".schedule-table");' +
  'if(!st){return "";}' +
  'var term="";var wk="";' +
  'var area=document.querySelector(".schedule-stu-area");' +
  'if(area){' +
  'var more=area.querySelector(".schedule-date .more");' +
  'if(more){term=(more.innerText||"").trim();}' +
  'var ds=area.querySelectorAll(".schedule-date span");' +
  'if(ds.length>1){wk=(ds[ds.length-1].innerText||"").trim();}}' +
  'var out=[];' +
  'var dls=st.querySelectorAll("dl.week");' +
  'for(var i=0;i<dls.length;i++){' +
  'var dd=dls[i].querySelectorAll("dd");' +
  'for(var j=0;j<dd.length;j++){' +
  'var e=dd[j];var cl=e.className||"";' +
  'var mt=cl.match(/\\bt(\\d+)\\b/);var mk=cl.match(/\\bk(\\d+)\\b/);' +
  'var ps=e.querySelectorAll("p");' +
  'var nm=ps.length>0?(ps[0].innerText||"").trim():"";' +
  'var pl=ps.length>1?(ps[1].innerText||"").trim():"";' +
  'if(!nm){continue;}' +
  'out.push({day:i,start:mt?parseInt(mt[1]):1,span:mk?parseInt(mk[1]):1,name:nm,place:pl});}}' +
  'return JSON.stringify({term:term,week:wk,courses:out});' +
  '}catch(e){return "ERR:"+e;}})()';

/** 点网页课表的上一周箭头 */
export const SCHEDULE_PREV_JS: string = '(function(){try{' +
  'var a=document.querySelector(".schedule-date .icon-left-o");' +
  'if(a){a.click();return "ok";}return "no";}catch(e){return "err";}})()';

/** 点网页课表的下一周箭头 */
export const SCHEDULE_NEXT_JS: string = '(function(){try{' +
  'var a=document.querySelector(".schedule-date .icon-right-o");' +
  'if(a){a.click();return "ok";}return "no";}catch(e){return "err";}})()';
