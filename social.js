/* 고구마 굽기 — 운영·소셜 기능: 터치 패턴 보고, 제재 안내/이의 신청, 아이템 신청,
   무료 룰렛, 친구(최대 50명), 프로필 카드 공유, 규정 안내
   online.js 가 먼저 로드되어 있어야 합니다. */
(function(){
  "use strict";
  var O = window.GoguOnline && window.GoguOnline.api;
  var G = window.GoguGame;
  if(!O || !G) return;
  var U = O.U, rpc = O.rpc, el = O.el, toast = O.toast, errMsg = O.errMsg;
  var GAME_URL = location.origin + location.pathname.replace(/[^\/]*$/, "");
  var CHAT_URL = "https://open.kakao.com/o/p80tC5Vi";
  var MAXF = 50;

  function login(){ O.login(); }

  /* ---------- 터치 패턴 보고 (30초마다 요약만 보냄) ---------- */
  var taps = [];
  var term = document.getElementById("term");
  if(term){
    term.addEventListener("pointerdown", function(e){
      if(window.GoguHit && !window.GoguHit(e)) return;
      if(taps.length < 3000) taps.push(performance.now());
    }, true);
  }
  function reportTouch(){
    var buf = taps; taps = [];
    if(!U.user || !U.loaded || buf.length < 30) return;
    var iv = [], i, sum = 0;
    for(i = 1; i < buf.length; i++){ var d = buf[i] - buf[i-1]; iv.push(d); sum += d; }
    var mean = sum / iv.length, v = 0;
    for(i = 0; i < iv.length; i++) v += (iv[i] - mean) * (iv[i] - mean);
    var cv = mean > 0 ? Math.sqrt(v / iv.length) / mean : 0;
    rpc("gogu_report_touch", { p_n: buf.length, p_cv: Math.round(cv * 10000) / 10000 }).then(function(r){
      if(r && r.state && U.profile && U.profile.flag_state !== r.state){
        U.profile.flag_state = r.state;
        if(r.state === "hold"){
          toast("터치 패턴 확인이 필요해요. 더보기 → 내정보를 확인해 주세요");
          O.clearCache(); G.refresh();
        }
      }
    }).catch(function(){});
  }
  setInterval(function(){ if(!document.hidden) reportTouch(); }, 30000);

  /* ---------- 불러온 뒤 안내 ---------- */
  function onLoad(d){
    var st = d.profile && d.profile.flag_state;
    if(st === "hold") toast("터치 패턴 확인 중이에요. 더보기 → 내정보에서 확인해 주세요");
    else if(st === "banned") toast("랭킹·시즌 보상에서 제외된 계정이에요");
    O.updateBadge();
    if(st === "ok" || st === "warned") rankPopup(d.season);
  }
  // 랭킹(50위 안)에 들어 있으면 알려준다. 순위가 바뀐 경우에만 다시 띄운다
  function rankPopup(season){
    var G2 = window.GoguGame; if(!G2 || !G2.popup) return;
    Promise.all([["ps","초당 최고"],["pc","터치당 최고"]].map(function(k){
      return rpc("gogu_my_rank", { p_kind: k[0] }).then(function(m){ return { k: k[0], n: k[1], m: m }; }).catch(function(){ return null; });
    })).then(function(rs){
      var rows = [], key = "gogu-rk-" + season;
      var last = {}; try{ last = JSON.parse(localStorage.getItem(key) || "{}"); }catch(e){}
      var cur = {}, changed = false;
      rs.forEach(function(r){
        if(!r || !r.m || r.m.hidden || !r.m.rank || r.m.rank > 50) return;
        cur[r.k] = r.m.rank; rows.push([r.n, r.m.rank + "위"]);
        if(last[r.k] !== r.m.rank) changed = true;
      });
      if(!rows.length || !changed) return;
      try{ localStorage.setItem(key, JSON.stringify(cur)); }catch(e){}
      G2.popup({ title: "랭킹에 올라 있어요!", rows: rows, msg: "랭킹 버튼에서 전체 순위를 볼 수 있어요.", btn: "확인" });
    });
  }

  /* ---------- 내정보 추가 영역 ---------- */
  var STATE_TEXT = {
    hold: ["자동 터치 프로그램으로 의심되는 패턴이 확인되어, 랭킹과 시즌 보상에서 잠시 제외됐어요. 직접 플레이하셨다면 아래에서 이의 신청을 해 주세요. 확인 후 경고 1회로 바로 풀어 드려요.", "#ffe1e1"],
    warned: ["경고 1회 기록이 있어요. 같은 시즌에 다시 확인되면 영구 제외될 수 있어요. (시즌이 바뀌면 경고는 초기화돼요)", "#fff3d6"],
    banned: ["랭킹·시즌 보상에서 영구 제외된 계정이에요. 게임은 계속 즐길 수 있어요.", "#ffe1e1"]
  };
  function meExtras(p){
    var pr = U.profile; if(!pr) return;
    var st = pr.flag_state;
    if(STATE_TEXT[st]){
      var c = el("div", "card"); c.style.background = STATE_TEXT[st][1];
      c.appendChild(el("h4", null, st === "hold" ? "확인이 필요해요" : st === "warned" ? "경고 1회" : "영구 제외"));
      c.appendChild(el("div", null, STATE_TEXT[st][0]));
      if(pr.recur && st === "hold") c.appendChild(el("div", "muted", "경고 이후 다시 확인되어 운영자가 한 번 더 살펴볼게요."));
      if(st === "hold"){
        if(U.appealOpen){ c.appendChild(el("div", "muted", "이의 신청이 접수됐어요. 운영자가 확인 중이에요.")); }
        else{
          var ta = el("textarea"); ta.maxLength = 300; ta.placeholder = "직접 플레이했다는 설명을 적어 주세요 (5~300자)";
          ta.style.cssText = "width:100%;min-height:70px;margin-top:8px;border:1px solid #d5dbe6;border-radius:10px;padding:8px;font:inherit";
          c.appendChild(ta);
          var b = el("button", "btn", "이의 신청 보내기"); b.type = "button"; b.style.marginTop = "8px";
          b.addEventListener("click", function(){
            b.disabled = true;
            rpc("gogu_appeal_submit", { p_note: ta.value }).then(function(){ U.appealOpen = true; toast("이의 신청을 보냈어요"); G.refresh(); })
              .catch(function(e){ b.disabled = false; toast(errMsg(e)); });
          });
          c.appendChild(b);
        }
      }
      p.appendChild(c);
    }
    var sc = el("div", "card"); sc.appendChild(el("h4", null, "프로필 · 자랑하기"));
    var r = el("div", "row");
    var b1 = el("button", "btn", "스킨 자랑 이미지 만들기"); b1.type = "button"; b1.addEventListener("click", shareCard); r.appendChild(b1); sc.appendChild(r);
    var lab = el("label", "muted"); lab.style.cssText = "display:flex;gap:8px;align-items:center;margin-top:10px";
    var cb = el("input"); cb.type = "checkbox"; cb.checked = pr.show_profile !== false;
    cb.addEventListener("change", function(){
      rpc("gogu_set_show_profile", { p_on: cb.checked }).then(function(){ pr.show_profile = cb.checked; toast(cb.checked ? "친구에게 프로필이 보여요" : "프로필을 숨겼어요"); })
        .catch(function(e){ cb.checked = !cb.checked; toast(errMsg(e)); });
    });
    lab.appendChild(cb); lab.appendChild(document.createTextNode("친구에게 내 프로필(스킨·기록) 보이기"));
    sc.appendChild(lab); p.appendChild(sc);

    var rq = el("div", "card"); rq.appendChild(el("h4", null, "아이템 신청 내역 (최근 30일)"));
    p.appendChild(rq);
    rpc("gogu_request_my").then(function(list){
      if(!list || !list.length){ rq.appendChild(el("div", "muted", "스킨 탭에서 잠긴 스킨을 눌러 신청할 수 있어요")); return; }
      var TXT = { pending: "대기 중", approved: "승인 (선물함 확인)", rejected: "보류됨" };
      list.forEach(function(x){
        var row = el("div", "row"); row.style.justifyContent = "space-between";
        row.appendChild(el("span", null, x.item_name)); row.appendChild(el("span", "muted", TXT[x.status] || x.status)); rq.appendChild(row);
      });
    }).catch(function(){ rq.appendChild(el("div", "muted", "불러오지 못했어요")); });
  }

  /* ---------- 아이템 신청 (잠긴 스킨 누르면) ---------- */
  G.requestItem = function(k){
    if(!U.ready){ toast("서버 연결 후 이용할 수 있어요"); return; }
    if(!U.user){ toast("로그인하면 신청할 수 있어요"); login(); return; }
    rpc("gogu_request_create", { p_item: k.id, p_note: "" }).then(function(){ toast("신청했어요! 운영자가 확인해요"); })
      .catch(function(e){ toast(errMsg(e)); });
  };

  /* ---------- 프로필 카드 이미지 공유 ---------- */
  function loadImg(src){ return new Promise(function(res, rej){ var i = new Image(); i.onload = function(){ res(i); }; i.onerror = rej; i.src = src; }); }
  function shareCard(){
    if(!window.GoguSkins || !window.GoguSkins.ready()){ toast("스킨을 준비 중이에요. 잠시 후 다시 눌러 주세요"); return; }
    var name = (U.profile && U.profile.nickname) || "구움이", title = U.profile && U.profile.title;
    var hidden = U.profile && (U.profile.flag_state === "hold" || U.profile.flag_state === "banned");
    var ranks = Promise.resolve([null, null]);
    if(U.user && !hidden) ranks = Promise.all([rpc("gogu_my_rank", { p_kind: "ps" }).catch(function(){ return null; }), rpc("gogu_my_rank", { p_kind: "pc" }).catch(function(){ return null; })]);
    var sel = window.GoguSkins.equipped();
    Promise.all([loadImg(window.GoguSkins.render(sel, 0)), ranks]).then(function(a){
      var img = a[0], rk = a[1];
      var W = 600, H = 800, cv = document.createElement("canvas"); cv.width = W; cv.height = H;
      var x = cv.getContext("2d");
      var g = x.createLinearGradient(0, 0, 0, H); g.addColorStop(0, "#0b1020"); g.addColorStop(1, "#1c2a4a");
      x.fillStyle = g; x.fillRect(0, 0, W, H);
      var gl = x.createRadialGradient(W/2, 330, 20, W/2, 330, 300); gl.addColorStop(0, "rgba(255,170,80,.35)"); gl.addColorStop(1, "rgba(255,170,80,0)");
      x.fillStyle = gl; x.fillRect(0, 0, W, H);
      x.imageSmoothingEnabled = false; x.drawImage(img, W/2 - 200, 110, 400, 400);
      x.textAlign = "center"; x.fillStyle = "#ffd25a"; x.font = "700 30px 'Noto Sans KR',sans-serif"; x.fillText("고구마 굽기", W/2, 70);
      if(title){ x.fillStyle = "#9fb4d8"; x.font = "500 24px 'Noto Sans KR',sans-serif"; x.fillText("[" + title + "]", W/2, 560); }
      x.fillStyle = "#fff"; x.font = "700 40px 'Noto Sans KR',sans-serif"; x.fillText(name, W/2, title ? 610 : 590);
      x.font = "500 24px 'Noto Sans KR',sans-serif"; x.fillStyle = "#cdd7ea";
      var l1, l2;
      if(hidden || !rk[0]){ l1 = "기록 준비 중"; l2 = ""; }
      else{
        l1 = "초당 최고 " + G.fmt(Number(rk[0].value)) + "원" + (rk[0].rank ? " · " + rk[0].rank + "위" : "");
        l2 = rk[1] ? "터치당 최고 " + G.fmt(Number(rk[1].value)) + "원" + (rk[1].rank ? " · " + rk[1].rank + "위" : "") : "";
      }
      x.fillText(l1, W/2, 670); if(l2) x.fillText(l2, W/2, 705);
      x.fillStyle = "#7f8fb0"; x.font = "500 20px 'Noto Sans KR',sans-serif"; x.fillText(GAME_URL.replace(/^https?:\/\//, ""), W/2, 765);
      cv.toBlob(function(blob){
        if(!blob){ toast("이미지를 만들지 못했어요"); return; }
        var file = new File([blob], "gogu-profile.png", { type: "image/png" });
        var text = "고구마 굽기에서 내 스킨 자랑! 같이 해요 👉 " + GAME_URL + "\n커뮤니티: " + CHAT_URL;
        if(navigator.canShare && navigator.canShare({ files: [file] })){
          navigator.share({ files: [file], title: "고구마 굽기", text: text }).catch(function(){});
        }else{
          var url = URL.createObjectURL(blob), a2 = document.createElement("a");
          a2.href = url; a2.download = "gogu-profile.png"; document.body.appendChild(a2); a2.click(); a2.remove();
          setTimeout(function(){ URL.revokeObjectURL(url); }, 4000);
          toast("이미지를 저장했어요. 커뮤니티에 올려 보세요!");
        }
      }, "image/png");
    }).catch(function(){ toast("이미지를 만들지 못했어요"); });
  }
  G.shareCard = shareCard;

  /* ---------- 이벤트 탭 (무료 룰렛) ---------- */
  /* ---------- 이벤트(룰렛) ---------- */
  var WHEEL_COLORS = ["#ff8a3d", "#ffd23f", "#4cc9a7", "#5b8def", "#b06bff", "#ff6b9a", "#8bd450", "#ff5a4d"];
  function ensureRouletteCss(){
    if(document.getElementById("rlcss")) return;
    var st = document.createElement("style"); st.id = "rlcss";
    st.textContent =
      ".rlbox{position:relative;width:min(280px,76vw);aspect-ratio:1;margin:6px auto 12px}"+
      ".rlwheel{position:absolute;inset:0;border-radius:50%;border:6px solid #ffd978;box-shadow:0 0 0 3px #7a4a10,0 8px 22px rgba(0,0,0,.35),inset 0 0 18px rgba(0,0,0,.35);overflow:hidden;transform:rotate(0deg)}"+
      ".rlwheel span{position:absolute;left:50%;top:50%;width:46%;transform-origin:0 50%;font:400 13px var(--f-display);color:#2a1600;text-align:right;line-height:1.1;text-shadow:0 1px 0 rgba(255,255,255,.5);padding-right:4px;box-sizing:border-box;word-break:keep-all}"+
      ".rlhub{position:absolute;left:50%;top:50%;width:46px;height:46px;margin:-23px 0 0 -23px;border-radius:50%;background:radial-gradient(circle at 35% 30%,#fff2c4,#ffb830);border:3px solid #7a4a10;box-shadow:0 3px 6px rgba(0,0,0,.4);z-index:2}"+
      ".rlpin{position:absolute;left:50%;top:-12px;margin-left:-14px;width:0;height:0;border-left:14px solid transparent;border-right:14px solid transparent;border-top:26px solid #e5483d;filter:drop-shadow(0 2px 2px rgba(0,0,0,.5));z-index:3}"+
      ".rlres{text-align:center;padding:10px 8px;border-radius:14px;margin-bottom:10px;font:400 22px var(--f-display);background:var(--row);color:var(--sheet-fg);min-height:48px;display:flex;align-items:center;justify-content:center;flex-direction:column;gap:2px}"+
      ".rlres small{font:500 13px var(--f-body);color:var(--sheet-muted)}"+
      ".rlres.win{background:linear-gradient(180deg,#fff3c4,#ffd66a);color:#6a3a00;animation:rlpop .5s cubic-bezier(.2,1.5,.4,1)}"+
      ".rlres.lose{background:#e9edf5;color:#5a6580}"+
      "@keyframes rlpop{0%{transform:scale(.6);opacity:0}100%{transform:none;opacity:1}}";
    document.head.appendChild(st);
  }
  // 서버가 돌려준 결과가 상품표의 몇 번째 칸인지 찾는다
  function wheelIndex(rows, r){
    var i, lab = r.label || "";
    for(i = 0; i < rows.length; i++) if(rows[i].label === lab) return i;
    if(r.kind === "event_skin"){
      var m = /\((\d+)일\)/.exec(lab), d = m ? m[1] : "";
      for(i = 0; i < rows.length; i++) if(rows[i].label.indexOf("스킨") >= 0 && rows[i].label.indexOf("(" + d + "일") >= 0) return i;
    }
    return 0;
  }
  function tabEvent(p){
    O.back(p);
    if(!U.ready){ O.offline(p); return; }
    ensureRouletteCss();
    var c = el("div", "card"); c.appendChild(el("h4", null, "무료 룰렛 · 하루 한 번"));
    var box = el("div", "rlbox"), wheel = el("div", "rlwheel");
    box.appendChild(wheel); box.appendChild(el("div", "rlhub")); box.appendChild(el("div", "rlpin")); c.appendChild(box);
    var res = el("div", "rlres"); res.textContent = U.spun ? "오늘은 이미 돌렸어요" : "룰렛을 돌려 보세요!"; c.appendChild(res);
    var btn = el("button", "btn", U.spun ? "내일 또 도전하세요" : "룰렛 돌리기"); btn.type = "button"; btn.style.width = "100%";
    btn.disabled = true; c.appendChild(btn); p.appendChild(c);
    var oc = el("div", "card"); oc.appendChild(el("h4", null, "당첨 확률")); p.appendChild(oc);

    var rows = null, rot = 0;
    function build(){
      var n = rows.length, seg = 360 / n, grad = [];
      rows.forEach(function(r, i){
        grad.push(WHEEL_COLORS[i % WHEEL_COLORS.length] + " " + (i * seg) + "deg " + ((i + 1) * seg) + "deg");
        var t = el("span", null, r.label.replace("화력 최대 ", "").replace("이벤트 ", "").replace(", 무작위", ""));
        t.style.transform = "translateY(-50%) rotate(" + (i * seg + seg / 2 - 90) + "deg)";
        wheel.appendChild(t);
      });
      wheel.style.background = "conic-gradient(" + grad.join(",") + ")";
      btn.disabled = !!U.spun;
    }
    btn.addEventListener("click", function(){
      if(!U.user){ toast("로그인하면 참여할 수 있어요"); login(); return; }
      if(!rows) return;
      btn.disabled = true; res.className = "rlres"; res.textContent = "룰렛이 돌아가요…";
      rpc("gogu_roulette_spin").then(function(r){
        return rpc("gogu_gift_claim", { p_id: r.gift_id }).then(function(cl){
          var n = rows.length, seg = 360 / n, idx = wheelIndex(rows, r);
          // 칸의 가운데가 위쪽 바늘에 오도록 여러 바퀴 돌린 뒤 멈춘다
          var target = 360 * 6 + (360 - (idx * seg + seg / 2)) + (Math.random() * seg * 0.5 - seg * 0.25);
          rot = Math.ceil(rot / 360) * 360 + target;
          wheel.style.transition = "transform 4.2s cubic-bezier(.12,.62,.1,1)";
          wheel.style.transform = "rotate(" + rot + "deg)";
          setTimeout(function(){
            O.applyClaim(cl); U.spun = true;
            var lose = r.kind === "none";
            res.className = "rlres " + (lose ? "lose" : "win"); res.textContent = "";
            res.appendChild(document.createTextNode(lose ? "아쉽게 꽝이에요" : "🎉 당첨!"));
            res.appendChild(el("small", null, lose ? "내일 또 도전해 보세요" : r.label + " 지급 완료"));
            btn.textContent = "내일 또 도전하세요";
            toast(lose ? "꽝! 내일 또 도전하세요" : "당첨! " + r.label);
          }, 4400);
        });
      }).catch(function(e){ res.className = "rlres"; res.textContent = "룰렛을 돌려 보세요!"; btn.disabled = false; toast(errMsg(e)); });
    });
    rpc("gogu_roulette_odds").then(function(list){
      rows = list;
      list.forEach(function(r){
        var row = el("div", "row"); row.style.justifyContent = "space-between";
        row.appendChild(el("span", null, r.label)); row.appendChild(el("span", "muted", r.pct + "%")); oc.appendChild(row);
      });
      build();
    }).catch(function(){ oc.appendChild(el("div", "muted", "불러오지 못했어요")); });
    O.note(p, "무료 이벤트예요. 돈으로 사거나 팔 수 없고, 당첨 스킨은 기간제(7일·30일)로 지급돼요. 기간이 끝나면 기본 모습으로 돌아가요.");
    if(!U.user) O.needLogin(p);
  }

  /* ---------- 친구 탭 ---------- */
  var FR = { open: null, kind: "ps" };
  function tabFriends(p){
    O.back(p);
    if(!U.ready){ O.offline(p); return; }
    if(!U.user){ O.needLogin(p); return; }
    var box = el("div"); box.appendChild(el("div", "muted", "불러오는 중…")); p.appendChild(box);
    rpc("gogu_friend_list").then(function(d){
      box.innerHTML = ""; U.friendIn = d.incoming.length; O.updateBadge();
      var add = el("div", "card"); add.appendChild(el("h4", null, "친구 추가 (" + d.friends.length + "/" + d.max + ")"));
      var r = el("div", "row"); var inp = el("input"); inp.placeholder = "친구 코드 (GOGU-XXXX-XXXX)"; inp.maxLength = 14; r.appendChild(inp);
      var b = el("button", "btn", "신청"); b.type = "button";
      b.addEventListener("click", function(){
        rpc("gogu_friend_request", { p_code: inp.value }).then(function(n){ toast(n + "님께 신청했어요"); G.refresh(); }).catch(function(e){ toast(errMsg(e)); });
      });
      r.appendChild(b); add.appendChild(r);
      add.appendChild(el("div", "muted", "내 코드는 내정보에서 복사할 수 있어요. 친구끼리만 프로필을 볼 수 있어요.")); add.lastChild.style.marginTop = "6px";
      box.appendChild(add);
      if(d.incoming.length){
        var ic = el("div", "card"); ic.appendChild(el("h4", null, "받은 신청"));
        d.incoming.forEach(function(f){
          var row = el("div", "row"); row.style.justifyContent = "space-between"; row.appendChild(el("span", null, f.nickname));
          var w = el("span"); w.style.cssText = "display:flex;gap:6px";
          var ok = el("button", "cbtn", "수락"); ok.type = "button";
          var no = el("button", "cbtn ghost", "거절"); no.type = "button";
          ok.addEventListener("click", function(){ rpc("gogu_friend_respond", { p_id: f.id, p_accept: true }).then(function(){ toast("친구가 됐어요"); G.refresh(); }).catch(function(e){ toast(errMsg(e)); }); });
          no.addEventListener("click", function(){ rpc("gogu_friend_respond", { p_id: f.id, p_accept: false }).then(function(){ G.refresh(); }).catch(function(e){ toast(errMsg(e)); }); });
          w.appendChild(ok); w.appendChild(no); row.appendChild(w); ic.appendChild(row);
        });
        box.appendChild(ic);
      }
      var lc = el("div", "card"); lc.appendChild(el("h4", null, "친구 랭킹 (나 포함)"));
      box.appendChild(lc);
      var segw = el("div", "seg");
      [["ps", "초당 최고"], ["pc", "터치당 최고"]].forEach(function(o){
        var bt = el("button", null, o[1]); bt.type = "button"; bt.setAttribute("aria-pressed", String(FR.kind === o[0]));
        bt.addEventListener("click", function(){ FR.kind = o[0]; G.refresh(); }); segw.appendChild(bt);
      });
      lc.appendChild(segw);
      var listBox = el("div"); lc.appendChild(listBox);
      var myq = Promise.all([rpc("gogu_my_rank", { p_kind: "ps" }).catch(function(){ return null; }), rpc("gogu_my_rank", { p_kind: "pc" }).catch(function(){ return null; })]);
      myq.then(function(m){
        var hide = U.profile && (U.profile.flag_state === "hold" || U.profile.flag_state === "banned");
        var key = FR.kind, rows = d.friends.map(function(f){ return { f: f, nick: f.nickname, title: f.title, v: f[key] == null ? null : Number(f[key]) }; });
        var mine = key === "ps" ? m[0] : m[1];
        rows.push({ me: true, nick: (U.profile && U.profile.nickname) || "나", title: U.profile && U.profile.title, v: hide || !mine ? null : Number(mine.value) });
        rows.sort(function(a, b){ return (b.v == null ? -1 : b.v) - (a.v == null ? -1 : a.v); });
        if(rows.length === 1) listBox.appendChild(el("div", "muted", "친구를 추가하면 친구끼리 순위가 매겨져요!"));
        rows.forEach(function(r, i){
          var row = el("button", "menu"); row.type = "button"; row.style.marginBottom = "6px"; row.style.padding = "12px 14px";
          if(r.me) row.style.outline = "2px solid #2f6df6";
          var l = el("div"); l.appendChild(document.createTextNode((r.v == null ? "-" : (i + 1)) + ". " + (r.title ? "[" + r.title + "] " : "") + r.nick + (r.me ? " (나)" : "")));
          l.appendChild(el("small", null, r.v == null ? "기록 없음/비공개" : (key === "ps" ? "초당 최고 " : "터치당 최고 ") + G.fmt(r.v) + "원"));
          row.appendChild(l); if(!r.me) row.appendChild(el("i", null, "›"));
          if(!r.me) row.addEventListener("click", function(){ FR.open = r.f; G.refresh(); });
          listBox.appendChild(row);
        });
      });
      if(d.outgoing.length){
        var oc = el("div", "card"); oc.appendChild(el("h4", null, "보낸 신청 (상대가 수락하면 친구가 돼요)"));
        d.outgoing.forEach(function(f){
          var row = el("div", "row"); row.style.justifyContent = "space-between"; row.appendChild(el("span", null, f.nickname));
          var c2 = el("button", "cbtn ghost", "취소"); c2.type = "button";
          c2.addEventListener("click", function(){ rpc("gogu_friend_remove", { p_id: f.id }).then(function(){ G.refresh(); }).catch(function(e){ toast(errMsg(e)); }); });
          row.appendChild(c2); oc.appendChild(row);
        });
        box.appendChild(oc);
      }
      if(FR.open) showFriend(box, FR.open);
    }).catch(function(){ box.innerHTML = ""; box.appendChild(el("div", "card muted", "친구 목록을 불러오지 못했어요")); });
  }
  function showFriend(box, f){
    var c = el("div", "card"); c.appendChild(el("h4", null, f.nickname + "님의 프로필"));
    box.insertBefore(c, box.firstChild); c.appendChild(el("div", "muted", "불러오는 중…"));
    rpc("gogu_friend_profile", { p_id: f.id }).then(function(pf){
      c.innerHTML = ""; c.appendChild(el("h4", null, pf.nickname + "님의 프로필"));
      if(pf.hidden){ c.appendChild(el("div", "muted", "이 친구는 프로필을 숨겼어요")); }
      else{
        if(window.GoguSkins && window.GoguSkins.ready()){
          var sk = pf.skin || {}, sel = { p: sk.p || "skin_p_default", b: sk.b || "skin_b_default", f: sk.f || "skin_f_default" };
          var im = el("img"); im.alt = ""; im.src = window.GoguSkins.render(sel, 0);
          im.style.cssText = "width:120px;height:120px;image-rendering:pixelated;display:block;margin:6px auto"; c.appendChild(im);
        }
        if(pf.title) c.appendChild(el("div", "muted", "[" + pf.title + "]"));
        if(pf.clan) c.appendChild(el("div", "muted", "클랜 " + pf.clan));
        c.appendChild(el("div", null, pf.ps == null ? "기록 비공개" : "초당 최고 " + G.fmt(Number(pf.ps)) + "원 · 터치당 최고 " + G.fmt(Number(pf.pc)) + "원"));
      }
      var row = el("div", "row");
      var cl = el("button", "cbtn ghost", "닫기"); cl.type = "button"; cl.addEventListener("click", function(){ FR.open = null; G.refresh(); });
      var rm = el("button", "cbtn ghost", "친구 삭제"); rm.type = "button"; var armed = false;
      rm.addEventListener("click", function(){
        if(!armed){ armed = true; rm.textContent = "한 번 더 누르면 삭제"; setTimeout(function(){ armed = false; rm.textContent = "친구 삭제"; }, 3000); return; }
        rpc("gogu_friend_remove", { p_id: f.id }).then(function(){ FR.open = null; toast("삭제했어요"); G.refresh(); }).catch(function(e){ toast(errMsg(e)); });
      });
      row.appendChild(cl); row.appendChild(rm); c.appendChild(row);
    }).catch(function(e){ c.innerHTML = ""; c.appendChild(el("div", "muted", errMsg(e))); });
  }

  /* ---------- 규정 · 안내 ---------- */
  function tabRules(p){
    O.back(p);
    var rules = [
      ["공정한 플레이", "자동 터치(매크로) 프로그램은 사용할 수 없어요. 직접 눌러서 즐겨 주세요. 초당 자동 수입(방치)은 게임 기능이라 괜찮아요."],
      ["확인되면 이렇게 해요", "① 의심 패턴이 확인되면 랭킹·시즌 보상에서 잠시 제외되고 안내가 떠요. ② 직접 플레이했다고 이의 신청하면 확인 후 경고 1회로 풀어 드려요. ③ 경고 후 같은 시즌에 다시 확인되면 영구 제외돼요. 경고는 시즌이 바뀌면 초기화돼요."],
      ["제외되면", "랭킹과 시즌 보상에서만 빠져요. 게임은 계속 즐길 수 있고 보유 아이템도 그대로예요."],
      ["시즌", "시즌은 3개월마다 시작돼요. 시즌이 끝나면 진행은 초기화되고, 스킨·칭호·아이템은 유지돼요. 랭킹은 화력 최대와 포인트샵 보너스를 뺀 초당·터치당 최고 기록이에요."],
      ["아이템 기간", "일부 아이템은 7일·30일 같은 기간제예요. 기간이 끝나면 기본 모습으로 돌아가고, 다시 받으면 기간이 이어져요."],
      ["문의", "커뮤니티 오픈채팅에서 운영자에게 물어보세요."]
    ];
    rules.forEach(function(r){ var c = el("div", "card"); c.appendChild(el("h4", null, r[0])); c.appendChild(el("div", null, r[1])); p.appendChild(c); });
    var a = el("a", "menu"); a.href = CHAT_URL; a.target = "_blank"; a.rel = "noopener noreferrer"; a.style.textDecoration = "none";
    var l = el("div"); l.appendChild(document.createTextNode("커뮤니티 오픈채팅")); l.appendChild(el("small", null, "문의 · 이벤트 소식 · 스킨 자랑"));
    a.appendChild(l); a.appendChild(el("i", null, "›")); p.appendChild(a);
  }

  G.registerTab("ev", tabEvent);
  G.registerTab("fr", tabFriends);
  G.registerTab("rl", tabRules);
  window.GoguSocial = { onLoad: onLoad, meExtras: meExtras, _reportTouch: reportTouch, _taps: function(){ return taps; } };
  // online.js 가 이미 데이터를 불러온 뒤 이 파일이 로드된 경우를 대비
  if(U.loaded && U.profile) onLoad({ profile: U.profile });
})();
