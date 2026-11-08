/* 고구마 굽기 — 로그인 · 클라우드 저장 · 랭킹 · 클랜 · 선물함
   config.js 에 Supabase 주소/공개 키가 없으면 아무것도 하지 않고, 게임은 이 기기에서만 저장됩니다. */
(function(){
  "use strict";
  var G, sb = null, cfg = window.GOGU_CONFIG || {};
  var U = { ready:false, user:null, profile:null, season:0, items:[], itemsExp:{}, gifts:0, friendIn:0, spun:false, appealOpen:false, loaded:false };
  var cache = {}, busy = {};
  var KST = 9 * 3600 * 1000;

  function el(t,c,x){ return G.el(t,c,x); }
  function toast(m){ G.toast(m); }
  function errMsg(e){ var m=(e&&e.message)||String(e||""); return m.length>60?"잠시 후 다시 시도해 주세요":m; }

  /* ---------- 서버 호출 ---------- */
  function rpc(name,args){
    return sb.rpc(name,args||{}).then(function(r){ if(r.error)throw r.error; return r.data; });
  }

  /* ---------- 시즌 계산 (서버와 같은 규칙) ---------- */
  function seasonEndText(season){
    var endUtc = season<=0 ? Date.UTC(2026,11,1) : Date.UTC(2026,11+3*season,1);
    var left = Math.ceil((endUtc - KST - Date.now())/86400000);
    var name = season<=0 ? "프리 시즌" : "시즌 "+season;
    return name+" · "+(left>0?left+"일 남음":"곧 종료");
  }

  /* ---------- 상태 합치기 ---------- */
  function seasonReset(o,season){
    var n=G.fresh();
    n.shop=(o&&o.shop)||{}; n.skin=o&&o.skin;     // 포인트샵 아이템은 시즌이 바뀌어도 유지
    n.season=season; n.born=Date.now();
    return n;
  }
  function hasProgress(s){ return (s.clicks||0)>0 || (s.total||0)>0; }

  function applyItems(){
    var has=function(i){return U.items.indexOf(i)>=0};
    G.perks.offlineH = has("perk_offline24")?24:has("perk_offline12")?12:8;
    G.perks.couponMax = has("perk_coupon15")?15:10;
    G.owned = U.items.slice(); G.itemsExp = U.itemsExp||{}; if(G.onItems) G.onItems();
    var bt=U.itemsExp&&U.itemsExp.perk_butter7; if(G.setButter)G.setButter(bt?Date.parse(bt):0);   // 7배 버터
  }

  function afterLoad(d){
    U.profile=d.profile; U.season=d.season; U.items=d.items||[]; U.itemsExp=d.items_exp||{}; U.gifts=d.gifts||0; U.loaded=true;
    U.friendIn=d.friend_in||0; U.spun=!!d.spun_today; U.appealOpen=!!d.appeal_open;
    applyItems();
    var local=G.state(), srv=d.save;
    if(srv){
      if(d.save_season!==d.season){
        G.setState(seasonReset(srv,d.season)); toast("새 시즌이 시작됐어요! 진행은 초기화되고 아이템은 유지돼요");
      }else{
        var useServer=true;
        if(hasProgress(local) && (local.total||0)!==(srv.total||0) && (local.season||0)===d.season){
          useServer=(srv.total||0)>(local.total||0);   // 더 많이 진행한 쪽을 자동으로 이어가요
          if(useServer)toast("서버에 저장된 더 높은 기록을 불러왔어요");
        }
        if(useServer){ var base=G.fresh(); for(var k in srv)base[k]=srv[k]; base.season=d.season; if(!base.born)base.born=Date.now(); G.setState(base); }
        else{ local.season=d.season; G.setState(local); sync(true); }
      }
    }else{
      if((local.season||0)!==d.season && hasProgress(local) && d.season>0){ G.setState(seasonReset(local,d.season)); }
      else{ local.season=d.season; G.setState(local); }
      sync(true);
    }
    G.refresh();
    if(window.GoguSocial)window.GoguSocial.onLoad(d);
    afterLogin();
  }

  /* ---------- 초대 코드 · 출석 · 7배 버터 ---------- */
  var PEND="gogu-code";
  function pendingGet(){ try{return localStorage.getItem(PEND)}catch(e){return null} }
  function pendingSet(v){ try{ if(v)localStorage.setItem(PEND,v); else localStorage.removeItem(PEND); }catch(e){} }
  // 주소의 ?from=bread (붕어빵 초대) / ?ref=친구코드 를 저장해 두었다가 로그인 후 자동으로 넣어요
  function captureInvite(){
    try{
      var u=new URL(location.href),from=u.searchParams.get("from"),ref=u.searchParams.get("ref"),code=null;
      if(ref&&/^GOGU-[A-Z0-9]{4}-[A-Z0-9]{4}$/i.test(ref))code=ref.toUpperCase();
      else if(from&&from.toLowerCase()==="bread")code="BUNGEOPPANG";
      if(from!==null||ref!==null){
        u.searchParams.delete("from");u.searchParams.delete("ref");
        history.replaceState(null,"",u.pathname+(u.search||"")+u.hash);
      }
      if(code)pendingSet(code);
    }catch(e){}
  }
  function reloadItems(){
    return rpc("gogu_load").then(function(d){U.items=d.items||[];U.itemsExp=d.items_exp||{};U.gifts=d.gifts||0;applyItems();updateBadge();G.refresh()});
  }
  function butterText(m){ return m>=60?(m%60?Math.floor(m/60)+"시간 "+(m%60)+"분":(m/60)+"시간"):m+"분"; }
  function redeem(code){
    return rpc("gogu_redeem_code",{p_code:code}).then(function(r){
      pendingSet(null);
      reloadItems().catch(function(){});
      if(r.kind==="promo"){
        G.popup({first:true,title:r.label+" 선물 도착!",lines:(r.items||[]).map(function(n){return "· "+n+" (영구)"}).concat(["· 7배 버터 "+butterText(r.minutes)]),msg:"더보기 › 스킨에서 바꿔 보세요",btn:"좋아요"});
      }else{
        G.popup({first:true,title:"초대 완료!",lines:[r.inviter+"님 덕분에 시작해요","7배 버터 "+butterText(r.minutes)+" 적용됐어요"],btn:"좋아요"});
      }
      return r;
    });
  }
  function afterLogin(){
    rpc("gogu_checkin").then(function(r){
      if(r&&r.claimed){
        reloadItems().catch(function(){});
        G.popup({title:"출석 보상",lines:["연속 "+r.streak+"일째예요"],value:"7배 버터 "+butterText(r.minutes),msg:(r.streak%7===0?"7일 연속 달성! 보너스예요":"내일도 오면 이어져요 (7일 연속이면 1시간)"),btn:"받았어요"});
      }
    }).catch(function(){}).then(function(){
      var c=pendingGet();if(!c)return;
      redeem(c).catch(function(e){
        var m=(e&&e.message)||"";
        if(!/fetch|network/i.test(m)){pendingSet(null);toast(m.length>40?"코드를 사용할 수 없어요":m)}
      });
    });
  }

  /* ---------- 저장 동기화 ---------- */
  var lastSyncTotal=-1, syncing=false;
  function sync(force){
    if(!sb||!U.user||!U.loaded||syncing)return;
    var s=G.state();
    var sig=(s.total||0)+"|"+JSON.stringify(s.lv)+"|"+Object.keys(s.shop||{}).length+"|"+Object.keys(s.done||{}).length;
    if(!force&&sig===lastSyncTotal)return;
    syncing=true;
    rpc("gogu_save",{p_data:s,p_born:new Date(s.born||Date.now()).toISOString()})
      .then(function(r){ lastSyncTotal=sig; if(r&&r.season!==U.season){U.season=r.season} cache={}; })
      .catch(function(){})
      .then(function(){syncing=false});
  }

  /* ---------- 화면 도우미 ---------- */
  function seg(parent,opts,cur,on){
    var w=el("div","seg");
    opts.forEach(function(o){
      var b=el("button",null,o[1]);b.type="button";b.setAttribute("aria-pressed",o[0]===cur?"true":"false");
      b.addEventListener("click",function(){on(o[0])});w.appendChild(b);
    });
    parent.appendChild(w);
  }
  function note(p,t){ p.appendChild(el("div","card muted",t)); }
  function needLogin(p){
    var c=el("div","card");
    c.appendChild(el("div",null,"로그인하면 랭킹, 클랜, 선물함을 쓸 수 있고 진행이 서버에 저장돼요."));
    var b=el("button","kakao","카카오로 로그인");b.type="button";b.style.marginTop="10px";
    b.addEventListener("click",login);c.appendChild(b);p.appendChild(c);
  }
  function offline(p){ note(p,"서버 연결을 준비 중이에요. 곧 열려요! 지금은 이 기기에만 저장돼요."); }
  function copy(text){
    try{ navigator.clipboard.writeText(text).then(function(){toast("복사했어요")},function(){toast(text)}); }
    catch(e){ toast(text); }
  }
  function login(){
    sb.auth.signInWithOAuth({provider:"kakao",options:{redirectTo:location.origin+location.pathname,scopes:"profile_nickname"}})
      .then(function(r){ if(r.error)toast("로그인을 시작할 수 없어요"); });
  }
  function logout(){
    sb.auth.signOut().then(function(){ U.user=null;U.profile=null;U.loaded=false;U.items=[];U.itemsExp={};U.gifts=0;U.friendIn=0;applyItems();cache={};G.refresh();toast("로그아웃했어요"); });
  }
  function cached(key,ttl,fn){
    var c=cache[key]; if(c&&Date.now()-c.t<ttl)return Promise.resolve(c.v);
    return fn().then(function(v){cache[key]={t:Date.now(),v:v};return v});
  }

  /* ---------- 랭킹 탭 ---------- */
  var RK={kind:"ps",scope:"all",season:null};
  function tabRank(p){
    if(!U.ready){offline(p);return}
    var cur=U.season;
    p.appendChild(el("div","muted",seasonEndText(cur)+(RK.season!=null?" · 지난 시즌 보는 중":"")));
    p.lastChild.style.margin="0 0 8px";
    seg(p,[["ps","초당 최고"],["pc","터치당 최고"],["cl","클랜"]],RK.kind,function(k){RK.kind=k;G.refresh()});
    if(RK.kind!=="cl"){
      seg(p,[["all","전체"],["new","신규(7일)"]],RK.scope,function(k){RK.scope=k;G.refresh()});
    }
    if(cur>1){
      var opts=[[null,"이번 시즌"]];for(var i=cur-1;i>=Math.max(1,cur-3);i--)opts.push([i,"시즌 "+i]);
      var w=el("div","seg");opts.forEach(function(o){var b=el("button",null,o[1]);b.type="button";b.setAttribute("aria-pressed",String(o[0]===RK.season));b.addEventListener("click",function(){RK.season=o[0];G.refresh()});w.appendChild(b)});p.appendChild(w);
    }
    var box=el("div");box.appendChild(el("div","muted","불러오는 중…"));p.appendChild(box);
    var key="rk|"+RK.kind+"|"+RK.scope+"|"+RK.season;
    var q = RK.kind==="cl"
      ? cached(key,60000,function(){return rpc("gogu_clan_ranking",{p_limit:30})})
      : cached(key,60000,function(){return rpc("gogu_ranking",{p_kind:RK.kind,p_new:RK.scope==="new",p_season:RK.season,p_limit:50})});
    q.then(function(rows){
      box.innerHTML="";
      if(!rows||!rows.length){box.appendChild(el("div","card muted","아직 기록이 없어요. 첫 번째 주인공이 되어 보세요!"));return}
      var mine=U.profile&&U.profile.nickname;
      rows.forEach(function(r){
        var d=el("div","rk"+(RK.kind!=="cl"&&r.nickname===mine?" me":""));
        d.appendChild(el("div","n",String(r.rank)));
        var nm=el("div");
        if(RK.kind==="cl"){nm.appendChild(document.createTextNode(r.clan));nm.appendChild(el("small",null,r.members+"명"))}
        else{
          if(r.title)nm.appendChild(el("small",null,"["+r.title+"]"));
          nm.appendChild(document.createTextNode(r.nickname));
          if(r.clan)nm.appendChild(el("small",null,"· "+r.clan));
        }
        d.appendChild(nm);d.appendChild(el("div","v",G.fmt(Number(RK.kind==="cl"?r.score:r.value))));
        box.appendChild(d);
      });
      if(RK.kind!=="cl"&&U.user&&RK.season==null){
        rpc("gogu_my_rank",{p_kind:RK.kind}).then(function(m){
          if(m){var t=el("div","card");t.appendChild(el("div",null,m.hidden?"내 기록은 확인 중이라 랭킹에서 잠시 빠져 있어요 (내정보에서 확인)":"내 순위 "+m.rank+"위 · "+G.fmt(Number(m.value))));box.insertBefore(t,box.firstChild)}
        }).catch(function(){});
      }
    }).catch(function(e){box.innerHTML="";box.appendChild(el("div","card muted","랭킹을 불러오지 못했어요"))});
    note(p,"랭킹은 화력 최대 7배와 포인트샵 보너스를 뺀 기본 수입으로 계산해요. 초당 최고·터치당 최고 기록이 올라가요.");
  }

  /* ---------- 더보기 탭 ---------- */
  function back(p){
    var b=el("button","cbtn ghost back","← 더보기");b.type="button";
    b.addEventListener("click",function(){G.openSheet("more")});p.appendChild(b);
  }
  function menuItem(p,title,sub,tab){
    var b=el("button","menu");b.type="button";
    var l=el("div");l.appendChild(document.createTextNode(title));l.appendChild(el("small",null,sub));
    b.appendChild(l);b.appendChild(el("i",null,"›"));
    b.addEventListener("click",function(){if(tab==="sk")G.skFrom=null;G.openSheet(tab)});p.appendChild(b);
  }
  function tabMore(p){
    menuItem(p,"이벤트","하루 한 번 무료 룰렛","ev");
    menuItem(p,U.gifts>0?"내정보 ("+U.gifts+")":"내정보",U.gifts>0?"받을 선물이 있어요":"선물함 · 닉네임 · 내 코드 · 보유 아이템","me");
    menuItem(p,U.friendIn>0?"친구 ("+U.friendIn+")":"친구",U.friendIn>0?"받은 친구 신청이 있어요":"친구 등록 · 친구 랭킹 (최대 50명)","fr");
    menuItem(p,"클랜","클랜 만들기 · 가입 · 클랜원 보기","cl");
    var cm=el("a","menu");cm.href="https://open.kakao.com/o/p80tC5Vi";cm.target="_blank";cm.rel="noopener noreferrer";cm.style.textDecoration="none";
    var cl=el("div");cl.appendChild(document.createTextNode("커뮤니티 가기"));cl.appendChild(el("small",null,"카카오톡 오픈채팅에서 같이 이야기해요"));
    cm.appendChild(cl);cm.appendChild(el("i",null,"›"));p.appendChild(cm);
    menuItem(p,"규정 · 안내","공정한 플레이를 위한 규칙","rl");
    ["이용약관|terms.html","개인정보처리방침|privacy.html"].forEach(function(x){
      var a=x.split("|"),lk=el("a","menu");lk.href=a[1];lk.target="_blank";lk.rel="noopener";lk.style.textDecoration="none";
      var d=el("div");d.appendChild(document.createTextNode(a[0]));lk.appendChild(d);lk.appendChild(el("i",null,"›"));p.appendChild(lk);
    });
    if(!U.ready)note(p,"서버 연결 후 이용할 수 있어요.");
    else if(!U.user)needLogin(p);
  }

  /* ---------- 클랜 탭 ---------- */
  function tabClan(p){
    back(p);
    if(!U.ready){offline(p);return}
    if(!U.user){needLogin(p);return}
    var box=el("div");box.appendChild(el("div","muted","불러오는 중…"));p.appendChild(box);
    rpc("gogu_clan_my").then(function(c){
      box.innerHTML="";
      if(c){
        var card=el("div","card");card.appendChild(el("h4",null,"내 클랜"));
        card.appendChild(el("div","big",c.name));
        var r=el("div","row");var code=el("span","codebox",c.code);r.appendChild(code);
        var cb=el("button","cbtn ghost","코드 복사");cb.type="button";cb.addEventListener("click",function(){copy(c.code)});r.appendChild(cb);card.appendChild(r);
        card.appendChild(el("div","muted","이 코드를 친구에게 알려주면 가입할 수 있어요 (최대 30명)"));
        card.lastChild.style.marginTop="6px";
        box.appendChild(card);
        var ml=el("div","card");ml.appendChild(el("h4",null,"클랜원 "+c.members.length+"명 · 상위 10명 초당 합계로 순위가 정해져요"));
        c.members.forEach(function(m){
          var rr=el("div","row");rr.style.justifyContent="space-between";
          rr.appendChild(el("span",null,(m.owner?"👑 ":"")+m.nickname));rr.appendChild(el("span","muted","초당 "+G.fmt(Number(m.ps))));ml.appendChild(rr);
        });
        box.appendChild(ml);
        var lv=el("button","cbtn ghost","클랜 나가기");lv.type="button";
        var armed=false;
        lv.addEventListener("click",function(){
          if(!armed){armed=true;lv.textContent="한 번 더 누르면 나가요 (7일간 다른 클랜 불가)";setTimeout(function(){armed=false;lv.textContent="클랜 나가기"},3000);return}
          rpc("gogu_clan_leave").then(function(){cache={};toast("클랜에서 나왔어요");G.refresh()}).catch(function(e){toast(errMsg(e))});
        });
        box.appendChild(lv);
      }else{
        var c1=el("div","card");c1.appendChild(el("h4",null,"클랜 만들기"));
        var r1=el("div","row");var i1=el("input");i1.placeholder="클랜 이름 (2~12자)";i1.maxLength=12;r1.appendChild(i1);
        var b1=el("button","btn","만들기");b1.type="button";b1.addEventListener("click",function(){
          rpc("gogu_clan_create",{p_name:i1.value}).then(function(){cache={};toast("클랜을 만들었어요");G.refresh()}).catch(function(e){toast(errMsg(e))});
        });r1.appendChild(b1);c1.appendChild(r1);box.appendChild(c1);
        var c2=el("div","card");c2.appendChild(el("h4",null,"클랜 가입하기"));
        var r2=el("div","row");var i2=el("input");i2.placeholder="클랜 코드 (예: CL-ABC123)";i2.maxLength=12;r2.appendChild(i2);
        var b2=el("button","btn","가입");b2.type="button";b2.addEventListener("click",function(){
          rpc("gogu_clan_join",{p_code:i2.value}).then(function(){cache={};toast("가입했어요");G.refresh()}).catch(function(e){toast(errMsg(e))});
        });r2.appendChild(b2);c2.appendChild(r2);box.appendChild(c2);
        note(box,"클랜은 7일에 한 번만 바꿀 수 있어요.");
      }
    }).catch(function(){box.innerHTML="";box.appendChild(el("div","card muted","클랜 정보를 불러오지 못했어요"))});
  }

  /* ---------- 선물 받기 적용 (선물함·룰렛 공용) ---------- */
  function applyClaim(res){
    var s=G.state();
    if(res.kind==="points")s.pts=(s.pts||0)+res.amount;
    else if(res.kind==="coupon")s.coupons=Math.min(99,(s.coupons||0)+res.amount);
    else{
      if(U.items.indexOf(res.item_id)<0)U.items.push(res.item_id);
      applyItems();
      rpc("gogu_load").then(function(d){U.items=d.items||[];U.itemsExp=d.items_exp||{};applyItems();G.refresh()}).catch(function(){});
    }
    G.save();sync(true);
  }

  /* ---------- 친구 초대 · 코드 입력 카드 ---------- */
  function inviteCard(p,pr){
    var link=location.origin+location.pathname+"?ref="+pr.code;
    var c=el("div","card");c.appendChild(el("h4",null,"친구 초대"));
    c.appendChild(el("div","muted","친구가 내 링크로 가입하면 친구도 나도 7배 버터 30분! (친구 최대 20명)"));
    var cnt=el("div","muted","불러오는 중…");cnt.style.margin="6px 0";c.appendChild(cnt);
    var r=el("div","row");
    var b1=el("button","btn","링크 복사");b1.type="button";b1.addEventListener("click",function(){copy(link)});r.appendChild(b1);
    var b2=el("button","cbtn ghost","공유하기");b2.type="button";b2.addEventListener("click",function(){
      var t="고구마 굽기 같이 해요! 이 링크로 들어오면 우리 둘 다 7배 버터 30분!";
      if(navigator.share)navigator.share({title:"고구마 굽기",text:t,url:link}).catch(function(){});
      else copy(t+" "+link);
    });r.appendChild(b2);c.appendChild(r);
    var h=el("div","group","초대 코드 입력");h.style.marginTop="12px";c.appendChild(h);
    c.appendChild(el("div","muted","친구 코드(GOGU-…)나 이벤트 초대 코드를 넣어 주세요. 계정당 한 번이에요."));
    var r2=el("div","row");r2.style.marginTop="6px";var ci=el("input");ci.placeholder="코드";ci.maxLength=30;r2.appendChild(ci);
    var ok=el("button","btn","확인");ok.type="button";ok.addEventListener("click",function(){
      if(!ci.value.trim())return;ok.disabled=true;
      redeem(ci.value).then(function(){ci.value="";G.refresh()}).catch(function(e){toast(errMsg(e))}).then(function(){ok.disabled=false});
    });r2.appendChild(ok);c.appendChild(r2);
    p.appendChild(c);
    rpc("gogu_referral_my").then(function(m){cnt.textContent="내가 초대한 친구 "+m.invited+" / "+m.max+"명"+(m.used?" · 초대 코드 사용함":"")}).catch(function(){cnt.textContent=""});
  }

  /* ---------- 내정보 탭 ---------- */
  function tabMe(p){
    back(p);
    if(!U.ready){offline(p);return}
    if(!U.user||!U.profile){needLogin(p);return}
    var pr=U.profile;
    var ac=el("div","card");ac.appendChild(el("h4",null,"로그인 계정"));
    var ar=el("div","row");ar.style.justifyContent="space-between";
    var um=(U.user&&U.user.user_metadata)||{},an=um.name||um.full_name||um.nickname||um.preferred_username||pr.nickname;
    var al=el("div");al.appendChild(el("div",null,"카카오 로그인 중"));al.appendChild(el("div","muted",String(an)));ar.appendChild(al);
    var lo2=el("button","cbtn ghost","로그아웃");lo2.type="button";lo2.addEventListener("click",logout);ar.appendChild(lo2);
    ac.appendChild(ar);p.appendChild(ac);
    var c=el("div","card");c.appendChild(el("h4",null,"닉네임"));
    var r=el("div","row");var inp=el("input");inp.value=pr.nickname;inp.maxLength=10;r.appendChild(inp);
    var sv=el("button","btn","변경");sv.type="button";sv.addEventListener("click",function(){
      rpc("gogu_set_nickname",{p_name:inp.value}).then(function(n){pr.nickname=n;cache={};toast("닉네임을 바꿨어요");G.refresh()}).catch(function(e){toast(errMsg(e))});
    });r.appendChild(sv);c.appendChild(r);
    c.appendChild(el("div","muted","30일에 한 번만 바꿀 수 있어요"));c.lastChild.style.marginTop="6px";p.appendChild(c);

    var c2=el("div","card");c2.appendChild(el("h4",null,"내 코드 (운영자 선물 받을 때 알려주세요)"));
    var r2=el("div","row");r2.appendChild(el("span","codebox",pr.code));
    var cb=el("button","cbtn ghost","복사");cb.type="button";cb.addEventListener("click",function(){copy(pr.code)});r2.appendChild(cb);
    c2.appendChild(r2);p.appendChild(c2);
    inviteCard(p,pr);
    if(window.GoguSocial)window.GoguSocial.meExtras(p);

    var gbox=el("div","card");gbox.appendChild(el("h4",null,"선물함"));gbox.appendChild(el("div","muted","불러오는 중…"));p.appendChild(gbox);
    var dc=el("div","card");dc.appendChild(el("h4",null,"회원 탈퇴"));
    dc.appendChild(el("div","muted","계정과 기록, 보유 아이템이 모두 삭제되고 되돌릴 수 없어요. 탈퇴하려면 아래에 '탈퇴'라고 입력하세요."));dc.lastChild.style.marginBottom="8px";
    var dr=el("div","row");var di=el("input");di.placeholder="탈퇴";di.maxLength=4;dr.appendChild(di);
    var db=el("button","btn ghost","탈퇴하기");db.type="button";db.disabled=true;
    di.addEventListener("input",function(){db.disabled=(di.value.trim()!=="탈퇴")});
    db.addEventListener("click",function(){
      if(di.value.trim()!=="탈퇴")return;db.disabled=true;
      rpc("gogu_delete_account").then(function(){
        return sb.auth.signOut().catch(function(){});
      }).then(function(){ U.user=null;U.profile=null;U.loaded=false;U.items=[];U.itemsExp={};U.gifts=0;U.friendIn=0;applyItems();cache={};G.refresh();toast("탈퇴했어요. 이용해 주셔서 고마워요"); })
      .catch(function(e){db.disabled=false;toast(errMsg(e))});
    });
    dr.appendChild(db);dc.appendChild(dr);p.appendChild(dc);
    rpc("gogu_gifts_list").then(function(list){
      gbox.innerHTML="";gbox.appendChild(el("h4",null,"선물함"));
      if(!list||!list.length){gbox.appendChild(el("div","muted","받을 선물이 없어요"));return}
      list.forEach(function(g){
        var row=el("div","row");row.style.justifyContent="space-between";
        var name=g.kind==="item"?(g.item_name||g.item_id)+(g.item_days?" ("+g.item_days+"일)":" (영구)"):g.kind==="points"?"포인트 "+g.amount:"화력 최대 쿠폰 "+g.amount+"장";
        var l=el("div");l.appendChild(el("div",null,name));if(g.note)l.appendChild(el("div","muted",g.note));row.appendChild(l);
        var b=el("button","btn","받기");b.type="button";
        b.addEventListener("click",function(){
          b.disabled=true;
          rpc("gogu_gift_claim",{p_id:g.id}).then(function(res){
            applyClaim(res);
            U.gifts=Math.max(0,U.gifts-1);toast("선물을 받았어요!");G.refresh();updateBadge();
          }).catch(function(e){b.disabled=false;toast(errMsg(e))});
        });
        row.appendChild(b);gbox.appendChild(row);
      });
    }).catch(function(){gbox.innerHTML="";gbox.appendChild(el("div","muted","선물함을 불러오지 못했어요"))});

    var ib=el("div","card");ib.appendChild(el("h4",null,"보유 아이템"));
    rpc("gogu_items_list").then(function(all){
      var mine=all.filter(function(i){return U.items.indexOf(i.id)>=0});
      if(!mine.length){ib.appendChild(el("div","muted","아직 없어요"));return}
      mine.forEach(function(i){
        var row=el("div","row");row.style.justifyContent="space-between";
        var l=el("div");l.appendChild(el("div",null,i.name));var left=U.itemsExp&&U.itemsExp[i.id]?Math.max(1,Math.ceil((new Date(U.itemsExp[i.id])-Date.now())/86400000))+"일 남음":(i.kind==="title"||i.kind==="perk"?"영구":"");
        l.appendChild(el("div","muted",(i.descr||"")+(left?" · "+left:"")));row.appendChild(l);
        if(i.kind==="title"){
          var on=pr.title===i.name;var b=el("button","cbtn"+(on?" ghost":""),on?"해제":"달기");b.type="button";
          b.addEventListener("click",function(){rpc("gogu_set_title",{p_item:on?null:i.id}).then(function(){pr.title=on?null:i.name;cache={};G.refresh()}).catch(function(e){toast(errMsg(e))})});row.appendChild(b);
        }
        ib.appendChild(row);
      });
    }).catch(function(){});
    p.appendChild(ib);

    var ft=el("div","row");ft.style.justifyContent="space-between";
    if(pr.is_admin){var a=el("a","cbtn ghost","운영자 페이지");a.href="admin.html";a.style.textDecoration="none";ft.appendChild(a)}
    p.appendChild(ft);
    note(p,seasonEndText(U.season)+" · 시즌이 끝나면 진행은 초기화되고 아이템은 유지돼요.");
  }

  function updateBadge(){
    var b=document.getElementById("t-more");if(!b)return;
    var n=(U.gifts||0)+(U.friendIn||0);b.textContent=n>0?"더보기 ("+n+")":"더보기";
  }

  /* ---------- 시작 ---------- */
  function start(game){
    G=game;
    captureInvite();
    G.registerTab("rk",tabRank);G.registerTab("cl",tabClan);G.registerTab("me",tabMe);G.registerTab("more",tabMore);
    if(!cfg.SUPABASE_URL||!cfg.SUPABASE_ANON_KEY||!window.supabase){return}
    try{
      sb=window.supabase.createClient(cfg.SUPABASE_URL,cfg.SUPABASE_ANON_KEY,
        {auth:{storageKey:"gogu-auth",persistSession:true,autoRefreshToken:true,detectSessionInUrl:true,flowType:"pkce"}});
    }catch(e){return}
    U.ready=true;
    function onSession(s){
      if(s&&s.user){
        if(U.user&&U.user.id===s.user.id)return;
        U.user=s.user;
        rpc("gogu_load").then(function(d){afterLoad(d);updateBadge()}).catch(function(e){toast("서버에 연결하지 못했어요")});
      }
    }
    sb.auth.getSession().then(function(r){onSession(r.data&&r.data.session)});
    sb.auth.onAuthStateChange(function(ev,s){ if(ev==="SIGNED_IN")setTimeout(function(){onSession(s)},0) });
    setInterval(function(){ if(!document.hidden)sync(false) },15000);
    document.addEventListener("visibilitychange",function(){ if(document.hidden)sync(false) });
    window.addEventListener("pagehide",function(){ sync(false) });
  }

  window.GoguOnline={start:start,_state:U,api:{
    U:U, rpc:rpc, el:el, toast:toast, errMsg:errMsg, copy:copy, note:note, needLogin:needLogin, offline:offline,
    back:back, menuItem:menuItem, seg:seg, applyItems:applyItems, applyClaim:applyClaim, sync:sync, updateBadge:updateBadge,
    clearCache:function(){cache={}}, seasonEndText:seasonEndText, login:login
  }};
  if(window.GoguGame)start(window.GoguGame);
})();
