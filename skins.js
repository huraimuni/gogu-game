/* 고구마게임 스킨: 고구마 / 화로 / 불 3칸 × 무료 / 유료 / 이벤트
   원본 픽셀아트를 캔버스에서 다시 칠해 보여준다. 무료 스킨은 누구나, 유료·이벤트는 보유(선물/지급) 시 사용. */
(function(){
  "use strict";
  var G=null;
  var SLOTS=[["p","고구마"],["b","화로"],["f","불"]];
  var TIER={free:"무료",paid:"유료",event:"이벤트"};
  // 팔레트: [어두운색, 중간색, 밝은색] / rainbow:true 면 가로 위치에 따라 색이 변함
  var CAT={
    p:[
      {id:"skin_p_default",name:"기본 고구마",tier:"free"},
      {id:"skin_p_pumpkin",name:"호박고구마",tier:"free",pal:["#a8501c","#f08a24","#ffd06a"]},
      {id:"skin_p_chestnut",name:"밤고구마",tier:"free",pal:["#8a6a2a","#e0b55a","#fff0b8"]},
      {id:"skin_p_violet",name:"자색고구마",tier:"free",pal:["#2a1050","#7a3fd0","#d9b8ff"]},
      {id:"skin_p_gold",name:"황금고구마",tier:"paid",pal:["#8a5a00","#ffc21a","#fff7b0"],fx:"sparkle"},
      {id:"skin_p_snow",name:"눈꽃고구마",tier:"event",pal:["#5a7aa8","#b8d4f0","#ffffff"],fx:"snow"},
      {id:"skin_p_ember",name:"불타는 고구마",tier:"event",pal:["#4a0a00","#e0321a","#ffd23a"],vert:true},
      {id:"skin_p_rainbow",name:"무지개고구마",tier:"event",rainbow:true},
      {id:"skin_p_sakura",name:"벚꽃고구마",tier:"paid",pal:["#6a2a4a","#f28ab8","#fff0f6"],fx:"petals"},
      {id:"skin_p_emerald",name:"에메랄드고구마",tier:"paid",pal:["#04301c","#1fbf6a","#c8ffe0"],fx:"sparkle"},
      {id:"skin_p_ruby",name:"루비고구마",tier:"paid",pal:["#3a0010","#d01040","#ff9ab8"],fx:"sparkle"},
      {id:"skin_p_sapphire",name:"사파이어고구마",tier:"paid",pal:["#06143a","#2a6af0","#b0d0ff"],fx:"sparkle"},
      {id:"skin_p_neon",name:"네온고구마",tier:"paid",pal:["#2e0060","#ff20d0","#40ffff"],post:3},
      {id:"skin_p_galaxy",name:"은하고구마",tier:"paid",pal:["#050520","#2a1a8a","#8a6aff"],fx:"stars"},
      {id:"skin_p_candy",name:"사탕고구마",tier:"paid",pal:["#d01a50","#ff7aa8","#fff4f8"],fx:"stripes"},
      {id:"skin_p_diamond",name:"다이아고구마",tier:"paid",pal:["#3a5a7a","#a8e4ff","#ffffff"],fx:"facet"},
      {id:"skin_p_lava",name:"용암고구마",tier:"event",pal:["#1a0000","#7a1000","#ffb020"],fx:"cracks"},
      {id:"skin_p_aurora",name:"오로라고구마",tier:"event",pal:["#062a3a","#2adca0","#d8a8ff"],fx:"aurora"}
    ],
    b:[
      {id:"skin_b_default",name:"기본 화로",tier:"free"},
      {id:"skin_b_silver",name:"은빛 화로",tier:"free",pal:["#3c424c","#a9b2bf","#f2f5fa"]},
      {id:"skin_b_copper",name:"구리 화로",tier:"free",pal:["#3a1a0c","#b4622e","#f2b98a"]},
      {id:"skin_b_gold",name:"황금 화로",tier:"paid",pal:["#4a3000","#d9a21a","#fff1a0"],fx:"sparkle"},
      {id:"skin_b_rose",name:"로즈골드 화로",tier:"paid",pal:["#4a2428","#d98a86","#ffe0d8"]},
      {id:"skin_b_ruby",name:"루비 화로",tier:"paid",pal:["#2e0410","#b8143a","#ff9ab0"]},
      {id:"skin_b_sapphire",name:"사파이어 화로",tier:"paid",pal:["#06143a","#1f56c8","#9ac4ff"]},
      {id:"skin_b_amethyst",name:"자수정 화로",tier:"paid",pal:["#1e0a38","#7a3cc0","#dcb8ff"]},
      {id:"skin_b_obsidian",name:"흑요석 화로",tier:"event",pal:["#050508","#262030","#6a5a8a"]},
      {id:"skin_b_ice",name:"얼음 화로",tier:"event",pal:["#2a5a80","#9adcf4","#f4ffff"],fx:"snow"},
      {id:"skin_b_jade",name:"비취 화로",tier:"event",pal:["#06301e","#22a070","#b0ffd8"]},
      {id:"skin_b_neon",name:"네온 화로",tier:"paid",pal:["#2e0060","#ff20d0","#40ffff"],post:3},
      {id:"skin_b_diamond",name:"다이아 화로",tier:"paid",pal:["#3a5a7a","#a8e4ff","#ffffff"],fx:"facet"},
      {id:"skin_b_lava",name:"용암 화로",tier:"paid",pal:["#1a0000","#7a1000","#ffb020"],fx:"cracks"},
      {id:"skin_b_sakura",name:"벚꽃 화로",tier:"paid",pal:["#5a2a3e","#f4a0c4","#fff4f8"],fx:"petals"},
      {id:"skin_b_emerald",name:"에메랄드 화로",tier:"paid",pal:["#03281a","#18b060","#b8ffd8"]},
      {id:"skin_b_galaxy",name:"은하 화로",tier:"paid",pal:["#050520","#2a1a8a","#8a6aff"],fx:"stars"},
      {id:"skin_b_candy",name:"사탕 화로",tier:"paid",pal:["#d01a50","#ff7aa8","#fff4f8"],fx:"stripes"},
      {id:"skin_b_bronze",name:"청동 화로",tier:"free",pal:["#2a1a08","#8a6a3a","#e0c890"]},
      {id:"skin_b_aurora",name:"오로라 화로",tier:"event",pal:["#042030","#20c8a8","#c8a0ff"],fx:"aurora"},
      {id:"skin_b_prism",name:"프리즘 화로",tier:"event",rainbow:true},
      {id:"skin_b_bungeo",name:"붕어빵 화로",tier:"event",only:"붕어빵 초대 코드 전용",pal:["#7a3a0c","#e89a2e","#ffe9a8"],fx:"bungeo"}
    ],
    f:[
      {id:"skin_f_default",name:"기본 불꽃",tier:"free"},
      {id:"skin_f_blue",name:"푸른 불꽃",tier:"free",pal:["#0a1a6a","#2a7aff","#bfe6ff"]},
      {id:"skin_f_purple",name:"보라 불꽃",tier:"free",pal:["#2a0a5a","#9a3cf0","#f0c8ff"]},
      {id:"skin_f_pink",name:"분홍 불꽃",tier:"paid",pal:["#6a0a3a","#ff4a9a","#ffd0ea"]},
      {id:"skin_f_white",name:"백색 불꽃",tier:"paid",pal:["#6a7a90","#e8f0ff","#ffffff"],fx:"sparkle"},
      {id:"skin_f_gold",name:"황금 불꽃",tier:"paid",pal:["#7a4a00","#ffc21a","#fffbd0"]},
      {id:"skin_f_teal",name:"청록 불꽃",tier:"paid",pal:["#04403a","#14c8b0","#c8fff4"]},
      {id:"skin_f_green",name:"초록 불꽃",tier:"event",pal:["#063a10","#2ad04a","#d0ffc0"]},
      {id:"skin_f_crimson",name:"진홍 불꽃",tier:"event",pal:["#2a0004","#c8101c","#ff8a7a"]},
      {id:"skin_f_rainbow",name:"무지개 불꽃",tier:"event",rainbow:true},
      {id:"skin_f_cyan",name:"번개 불꽃",tier:"paid",pal:["#0a0a40","#ffe83a","#ffffff"],fx:"sparkle"},
      {id:"skin_f_lime",name:"먹구름 불꽃",tier:"paid",pal:["#101018","#5a5a70","#d0d0e0"]},
      {id:"skin_f_sunset",name:"노을 불꽃",tier:"free",pal:["#4a0a2a","#ff6a3a","#ffe08a"],vert:true},
      {id:"skin_f_ice",name:"서리 불꽃",tier:"paid",pal:["#2a4a7a","#8ad0ff","#ffffff"],fx:"snow"},
      {id:"skin_f_toxic",name:"독성 불꽃",tier:"paid",pal:["#1a3a00","#5ae000","#e8ff7a"]},
      {id:"skin_f_royal",name:"로열 불꽃",tier:"event",pal:["#2a0a4a","#e0a81a","#fff4c0"]},
      {id:"skin_f_prism",name:"프리즘 불꽃",tier:"event",rainbow:true}
    ]
  };
  var BY={};SLOTS.forEach(function(s){CAT[s[0]].forEach(function(k){k.slot=s[0];BY[k.id]=k})});
  var DEF={p:"skin_p_default",b:"skin_b_default",f:"skin_f_default"};
  window.GOGU_SKINS={CAT:CAT,SLOTS:SLOTS,TIER:TIER};

  function hex(h){return [parseInt(h.substr(1,2),16),parseInt(h.substr(3,2),16),parseInt(h.substr(5,2),16)]}
  function grad(pal,t){
    var a=hex(pal[0]),b=hex(pal[1]),c=hex(pal[2]),u,x,y;
    if(t<.5){u=t*2;x=a;y=b}else{u=(t-.5)*2;x=b;y=c}
    return [x[0]+(y[0]-x[0])*u,x[1]+(y[1]-x[1])*u,x[2]+(y[2]-x[2])*u];
  }
  function hsv2rgb(h,s,v){
    var i=Math.floor(h*6),f=h*6-i,p=v*(1-s),q=v*(1-f*s),t=v*(1-(1-f)*s),r,g,b;
    switch(i%6){case 0:r=v;g=t;b=p;break;case 1:r=q;g=v;b=p;break;case 2:r=p;g=v;b=t;break;case 3:r=p;g=q;b=v;break;case 4:r=t;g=p;b=v;break;default:r=v;g=p;b=q}
    return [r*255,g*255,b*255];
  }

  var W=0,H=0,frames=[],cls=[],lum=[],range={},ready=false,cache={},BB={1:[999,999,-1,-1],2:[999,999,-1,-1],3:[999,999,-1,-1]},rcache={},canv={};
  var D=window.GOGU_DEBUG_SKINS={};

  // 원본 2프레임을 읽고 픽셀을 고구마(p) / 불(f) / 화로(b) 로 분류
  function prepare(srcs,done){
    var n=0,imgs=[];
    srcs.forEach(function(s,i){
      var im=new Image();
      im.onload=function(){imgs[i]=im;if(++n===srcs.length)build(imgs,done)};
      im.src=s;
    });
  }
  function build(imgs,done){
    W=imgs[0].naturalWidth;H=imgs[0].naturalHeight;
    var mm={p:[9,-9],b:[9,-9],f:[9,-9]};
    imgs.forEach(function(im,fi){
      var c=document.createElement("canvas");c.width=W;c.height=H;
      var x=c.getContext("2d",{willReadFrequently:true});x.drawImage(im,0,0);
      var d=x.getImageData(0,0,W,H);frames[fi]=d;
      var C=new Uint8Array(W*H),L=new Float32Array(W*H);
      for(var y=0;y<H;y++)for(var xx=0;xx<W;xx++){
        var i=y*W+xx,o=i*4,r=d.data[o]/255,g=d.data[o+1]/255,b=d.data[o+2]/255,a=d.data[o+3];
        if(a<10){C[i]=0;continue}
        var mx=Math.max(r,g,b),mn=Math.min(r,g,b),sat=mx?(mx-mn)/mx:0,h=0,df=mx-mn;
        if(df){if(mx===r)h=((g-b)/df+6)%6;else if(mx===g)h=(b-r)/df+2;else h=(r-g)/df+4;h/=6}
        var warm=h<.17||h>.93;
        var k;
        if(y>=48&&sat>.35&&warm)k=3;            // 불
        else if(y<36&&sat>=.2)k=1;               // 고구마
        else k=2;                                // 화로 (김·연기 같은 흰색도 여기 → 아래에서 보호)
        if(k===2&&y<12&&sat<.2)k=0;              // 김은 그대로 둔다
        C[i]=k;
        if(k){var bb=BB[k];if(xx<bb[0])bb[0]=xx;if(y<bb[1])bb[1]=y;if(xx>bb[2])bb[2]=xx;if(y>bb[3])bb[3]=y}
        var l=.3*r+.59*g+.11*b;L[i]=l;
        var key=k===1?"p":k===2?"b":k===3?"f":null;
        if(key){if(l<mm[key][0])mm[key][0]=l;if(l>mm[key][1])mm[key][1]=l}
      }
      cls[fi]=C;lum[fi]=L;
    });
    range=mm;ready=true;done();
  }


  // 스킨마다 다른 무늬: 별(은하), 줄무늬(사탕), 면(다이아), 균열(용암), 오로라 …
  function hs(x,y){var h=(Math.imul(x,374761393)+Math.imul(y,668265263))|0;h=Math.imul(h^(h>>>13),1274126177);return ((h^(h>>>16))>>>0)%1000/1000}
  function mix(c,w,a){return [c[0]+(w[0]-c[0])*a,c[1]+(w[1]-c[1])*a,c[2]+(w[2]-c[2])*a]}
  function fxp(n,c,x,y,t){
    var h=hs(x,y),w;
    switch(n){
      case "stars": return h<.05?[255,255,255]:h<.08?mix(c,[170,210,255],.7):c;
      case "sparkle": return h<.03?mix(c,[255,255,255],.92):c;
      case "snow": return h<.06?[255,255,255]:c;
      case "petals": return h<.06?[255,246,250]:c;
      case "stripes": return (((x+y)>>2)&1)?mix(c,[255,255,255],.6):c;
      case "facet": return h<.02?[255,255,255]:((((x>>2)+(y>>2))&1)?mix(c,[255,255,255],.24):mix(c,[0,0,0],.14));
      case "cracks": w=hs(x>>1,y>>1);return w<.17?[255,170+Math.round(w*300),40]:mix(c,[0,0,0],.3);
      case "bungeo": var rw=(y/4)|0,u=(x+((rw&1)*3))%6,v=y&3,ar=[1,2,3,3,2,1][u];   // 붕어빵 비늘(∪ 모양이 어긋나게 쌓임)
        if(v===ar)return mix(c,[90,36,6],.55);
        return (v===ar-1&&(u===2||u===3))?mix(c,[255,244,190],.4):c;
      case "aurora": w=Math.sin(x*.17+y*.08)*.5+.5;var b=mix([40,235,150],[190,110,255],w),sh=.4+.6*t;return [b[0]*sh,b[1]*sh,b[2]*sh];
    }
    return c;
  }

  function render(sel,fi){
    var key=sel.p+"|"+sel.b+"|"+sel.f+"|"+fi;
    if(cache[key])return cache[key];
    var src=frames[fi],out=new ImageData(new Uint8ClampedArray(src.data),W,H);
    var C=cls[fi],L=lum[fi],px=out.data;
    var pick={1:BY[sel.p],2:BY[sel.b],3:BY[sel.f]},rg={1:range.p,2:range.b,3:range.f};
    for(var i=0;i<W*H;i++){
      var k=C[i];if(!k)continue;
      var sk=pick[k];if(!sk||(!sk.pal&&!sk.rainbow))continue;
      var r=rg[k],t=(L[i]-r[0])/Math.max(.001,r[1]-r[0]);t=t<0?0:t>1?1:t;
      var col;
      if(sk.rainbow){var x=i%W;col=hsv2rgb(((x/W)*1.2+.0)%1,.75-.25*t,.35+.65*t)}
      else{
        if(sk.vert){var bb=BB[k],vf=((i/W|0)-bb[1])/Math.max(1,bb[3]-bb[1]);t=Math.max(0,Math.min(1,.35*t+.65*(1-vf)))}
        if(sk.post)t=Math.round(t*(sk.post-1))/(sk.post-1);
        col=grad(sk.pal,t);
        if(sk.fx)col=fxp(sk.fx,col,i%W,(i/W)|0,t);
      }
      px[i*4]=col[0];px[i*4+1]=col[1];px[i*4+2]=col[2];
    }
    var c=document.createElement("canvas");c.width=W;c.height=H;c.getContext("2d").putImageData(out,0,0);
    canv[key]=c;
    return (cache[key]=c.toDataURL("image/png"));
  }

  // 목록용 작은 그림: 고구마/화로/불 중 해당 부분만 잘라서 크게 보여준다
  function thumb(o,slot){
    var key="T|"+o.p+"|"+o.b+"|"+o.f+"|"+slot;if(rcache[key])return rcache[key];
    render(o,0);
    var src=canv[o.p+"|"+o.b+"|"+o.f+"|0"];
    var k=slot==="p"?1:slot==="b"?2:3,bb=BB[k];
    var bw=bb[2]-bb[0]+1,bh=bb[3]-bb[1]+1,side=Math.max(bw,bh)+4;
    var c=document.createElement("canvas");c.width=c.height=side;
    c.getContext("2d").drawImage(src,bb[0],bb[1],bw,bh,Math.floor((side-bw)/2),Math.floor((side-bh)/2),bw,bh);
    return (rcache[key]=c.toDataURL("image/png"));
  }

  function owned(id){
    var k=BY[id];if(!k)return false;
    if(k.tier==="free")return true;
    return (G.owned||[]).indexOf(id)>=0;
  }
  function equipped(){
    var s=G.state().skin||{},r={};
    SLOTS.forEach(function(x){var id=s[x[0]];r[x[0]]=(id&&BY[id]&&owned(id))?id:DEF[x[0]]});
    return r;
  }
  function apply(){
    if(!ready)return;
    var sel=equipped();
    G.setArt(render(sel,0),render(sel,1));
    glowFor(BY[sel.f]);
  }
  // 화력 최대 때의 불빛·불씨 색을 장착한 불 스킨에 맞춘다
  function glowFor(k){
    var r=document.documentElement.style,b=document.body;
    if(!k||(!k.pal&&!k.rainbow)){r.removeProperty("--fa");r.removeProperty("--fb");r.removeProperty("--fe");b.classList.remove("fire-rainbow");return}
    if(k.rainbow){r.setProperty("--fa","255,120,60");r.setProperty("--fb","255,60,60");r.setProperty("--fe","255,210,90");b.classList.add("fire-rainbow");return}
    b.classList.remove("fire-rainbow");
    var d=hex(k.pal[0]),m=hex(k.pal[1]),l=hex(k.pal[2]);
    function t(c){return Math.round(c[0])+","+Math.round(c[1])+","+Math.round(c[2])}
    r.setProperty("--fa",t(m));
    r.setProperty("--fb",t([m[0]*.7+d[0]*.3,m[1]*.7+d[1]*.3,m[2]*.7+d[2]*.3]));
    r.setProperty("--fe",t(l));
  }

  /* ---------- 스킨 탭 ---------- */
  function css(){
    var s=document.createElement("style");
    s.textContent=
      ".skprev{display:flex;justify-content:center;background:var(--row);border-radius:16px;padding:10px;margin-bottom:10px}"+
      ".skprev img{width:120px;height:120px;image-rendering:pixelated}"+
      ".skgrid{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin-bottom:12px}"+
      ".sk{position:relative;border:2px solid var(--line);background:#fff;border-radius:14px;padding:6px 4px 8px;text-align:center;cursor:pointer;font:700 12px var(--f-body);color:var(--sheet-fg)}"+
      ".sk img{width:64px;height:64px;image-rendering:pixelated;display:block;margin:0 auto 4px}"+
      ".sk[aria-pressed=\"true\"]{border-color:var(--blue);background:#eef4ff}"+
      ".sk.lock{opacity:.55}"+
      ".sk .tg{position:absolute;top:4px;left:4px;font:700 10px var(--f-body);padding:1px 6px;border-radius:999px;background:#e6ebf3;color:var(--sheet-muted)}"+
      ".sk .tg.paid{background:#fff0c8;color:#8a5a00}.sk .tg.event{background:#e8dcff;color:#5a2aa8}"+
      ".skpop{position:fixed;inset:0;background:rgba(5,8,16,.6);z-index:60;display:flex;align-items:center;justify-content:center;padding:16px}"+
      ".skbox{background:#fff;color:var(--sheet-fg);border-radius:20px;padding:16px;width:min(340px,100%);text-align:center;max-height:92vh;overflow:auto}"+
      ".skh{display:flex;align-items:center;justify-content:center;gap:8px;font-size:17px;margin-bottom:6px}.skh .tg{position:static}"+
      ".skbox img{width:min(220px,70vw);aspect-ratio:1;image-rendering:pixelated;background:var(--row);border-radius:16px;display:block;margin:6px auto}"+
      ".sknm{font:700 12px var(--f-body);color:var(--sheet-muted);text-align:center}"+
      ".skmsg{margin:10px 0 12px;font-size:14px}.skrow{display:flex;gap:8px;justify-content:center}.skrow .cbtn{flex:1}.skrow .cbtn:disabled{opacity:.5}"+
      ".sk small{display:block;font-weight:500;color:var(--sheet-muted);margin-top:2px}";
    document.head.appendChild(s);
  }

  /* ---------- 미리보기 팝업: 누르면 내 조합으로 어떻게 보이는지 먼저 보여준다 ---------- */
  var PV={};   // 미리보기로 고른 스킨 (칸 → id). 장착하지 않아도 위쪽 큰 그림에 반영돼요
  function combo(extra){var e=equipped(),o={p:e.p,b:e.b,f:e.f},k;for(k in PV)o[k]=PV[k];if(extra)for(k in extra)o[k]=extra[k];return o}
  function comboNames(o){return SLOTS.map(function(sl){var k=BY[o[sl[0]]];return sl[1]+" "+(k?k.name:"")}).join(" · ")}
  function closePop(){var x=document.getElementById("skpop");if(x)x.parentNode.removeChild(x)}
  function equip(k){var s=G.state();s.skin=Object.assign({},s.skin||{});s.skin[k.slot]=k.id;delete PV[k.slot];G.save();apply();G.refresh()}
  function skinPopup(k){
    var el=G.el;closePop();PV[k.slot]=k.id;
    var has=owned(k.id),on=equipped()[k.slot]===k.id,isOwner=!!(G.isOwner&&G.isOwner());
    var ov=el("div","skpop");ov.id="skpop";
    ov.addEventListener("click",function(e){if(e.target===ov){closePop();G.refresh()}});
    var bx=el("div","skbox");ov.appendChild(bx);
    var h=el("div","skh");h.appendChild(el("b",null,k.name));h.appendChild(el("span","tg "+k.tier,TIER[k.tier]));bx.appendChild(h);
    var im=el("img");im.alt="";im.src=render(combo(),0);bx.appendChild(im);
    bx.appendChild(el("div","sknm","내 조합: "+comboNames(combo())));
    var msg,btns=[];
    if(on){msg="지금 사용 중인 스킨이에요.";btns.push(["사용 중",null,true])}
    else if(has){msg="보유 중이에요. 사용하면 위 조합 그대로 적용돼요.";btns.push(["사용하기",function(){equip(k);closePop()}])}
    else if(k.tier==="paid"){
      if(isOwner){msg="이 스킨을 구매할까요? (대표 구매)";btns.push(["구매하기",function(){closePop();G.ownerBuy(k)}])}
      else{msg="유료 스킨이에요. 구매는 서비스 준비 중이에요. 지금은 미리보기만 볼 수 있어요."}
    }else if(k.only){
      msg=k.only+"예요. 더보기 › 내정보에서 코드를 입력하면 받을 수 있어요.";
    }else{
      msg="이벤트 스킨이에요. 신청하면 운영자가 확인해요.";
      if(G.requestItem)btns.push(["신청하기",function(){closePop();G.requestItem(k)}]);
    }
    bx.appendChild(el("div","skmsg",msg));
    var row=el("div","skrow");
    btns.forEach(function(b){var x=el("button","cbtn",b[0]);x.type="button";if(b[2])x.disabled=true;else x.addEventListener("click",b[1]);row.appendChild(x)});
    var cb=el("button","cbtn ghost","닫기");cb.type="button";cb.addEventListener("click",function(){closePop();G.refresh()});row.appendChild(cb);
    bx.appendChild(row);
    document.body.appendChild(ov);
  }

  function tabSkin(p){
    var el=G.el;
    var from=G.skFrom||"more";
    var b=el("button","cbtn ghost back",from==="up"?"← 고구마 상점":from==="cash"?"← 캐쉬 상점":"← 더보기");b.type="button";
    b.addEventListener("click",function(){PV={};G.skFrom=null;G.openSheet(from)});p.appendChild(b);
    if(!ready){p.appendChild(el("div","muted","불러오는 중…"));return}
    var sel=equipped(),cm=combo(),previewing=Object.keys(PV).some(function(x){return PV[x]!==sel[x]});
    var pv=el("div","skprev"),pi=el("img");pi.alt="";pi.src=render(cm,0);pv.appendChild(pi);p.appendChild(pv);
    var pn=el("div","sknm",(previewing?"미리보기 중 · ":"내 조합 · ")+comboNames(cm));pn.style.marginBottom="8px";p.appendChild(pn);
    if(previewing){var pr=el("button","cbtn ghost","미리보기 끝내기");pr.type="button";pr.style.marginBottom="8px";pr.addEventListener("click",function(){PV={};G.refresh()});p.appendChild(pr)}
    SLOTS.forEach(function(sl){
      var g=el("div","group",sl[1]);g.style.marginBottom="6px";p.appendChild(g);
      var grid=el("div","skgrid");
      CAT[sl[0]].forEach(function(k){
        var has=owned(k.id),on=sel[sl[0]]===k.id;
        var c=el("button","sk"+(has?"":" lock"));c.type="button";c.setAttribute("aria-pressed",on?"true":"false");
        var t=el("span","tg "+k.tier,TIER[k.tier]);c.appendChild(t);
        var o={p:sel.p,b:sel.b,f:sel.f};o[sl[0]]=k.id;
        var im=el("img");im.alt="";im.src=thumb(o,sl[0]);c.appendChild(im);
        c.appendChild(document.createTextNode(k.name));
        var ex=G.itemsExp&&G.itemsExp[k.id],dl=ex?Math.max(1,Math.ceil((new Date(ex)-Date.now())/86400000)):0;
        c.appendChild(el("small",null,on?"사용 중":has?(dl?dl+"일 남음":"사용하기"):(k.only?"초대 전용":k.tier==="paid"?(G.isOwner&&G.isOwner()?"대표 구매":"준비 중"):"신청하기")));
        if(PV[sl[0]]===k.id&&!on)c.style.borderStyle="dashed";
        c.addEventListener("click",function(){skinPopup(k)});
        grid.appendChild(c);
      });
      p.appendChild(grid);
    });
    if(G.shareCard){var sb=el("button","cbtn","내 스킨 자랑하기 (이미지 공유)");sb.type="button";sb.style.width="100%";sb.style.marginBottom="10px";sb.addEventListener("click",function(){G.shareCard()});p.insertBefore(sb,pv.nextSibling)}
    p.appendChild(el("div","muted","유료 스킨은 서비스 준비 중이에요. 이벤트 스킨은 이벤트 룰렛 보상 등으로 받을 수 있고, 로그인하면 보유 스킨이 불러와져요."));
  }

  // 상점 탭에 넣는 스킨 상품 목록 (유료 스킨). 누르면 구매 신청, 보유 중이면 스킨 화면으로
  function tabCash(p){
    var el=G.el;
    G.shopTabs(p,"cash");
    var mb=el("button","menu");mb.type="button";
    var ml=el("div");ml.appendChild(document.createTextNode("내 스킨 보기"));ml.appendChild(el("small",null,"스킨 바꾸기 · 자랑 이미지 공유"));
    mb.appendChild(ml);mb.appendChild(el("i",null,"›"));
    mb.addEventListener("click",function(){G.skFrom="cash";G.openSheet("sk")});p.appendChild(mb);
    if(!ready){p.appendChild(el("div","muted","불러오는 중…"));return}
    products(p);
  }
  function products(p){
    if(!ready)return;
    var el=G.el,sel=equipped();
    p.appendChild(el("div","group","스킨 상품"));
    SLOTS.forEach(function(sl){
      var list=CAT[sl[0]].filter(function(k){return k.tier==="paid"});
      if(!list.length)return;
      var g=el("div","muted",sl[1]);g.style.margin="2px 0 4px";p.appendChild(g);
      var grid=el("div","skgrid");
      list.forEach(function(k){
        var has=owned(k.id);
        var c=el("button","sk"+(has?"":" lock"));c.type="button";
        c.appendChild(el("span","tg paid",has?"보유":"유료"));
        var o={p:sel.p,b:sel.b,f:sel.f};o[sl[0]]=k.id;
        var im=el("img");im.alt="";im.src=thumb(o,sl[0]);c.appendChild(im);
        c.appendChild(document.createTextNode(k.name));
        c.appendChild(el("small",null,has?"사용하러 가기":(G.isOwner&&G.isOwner()?"대표 구매":"준비 중")));
        c.addEventListener("click",function(){skinPopup(k)});
        grid.appendChild(c);
      });
      p.appendChild(grid);
    });
    p.appendChild(el("div","muted","유료 스킨 구매는 서비스 준비 중이에요. 곧 만나요!"));
    p.lastChild.style.marginBottom="10px";
  }

  function start(game){
    G=game;css();
    G.registerTab("sk",tabSkin);G.registerTab("cash",tabCash);
    var a=document.querySelectorAll("#term img");
    prepare([a[0].src,a[1].src],function(){
      D.ready=true;apply();
      if(G.currentTab()==="sk"||G.currentTab()==="cash")G.refresh();
    });
    G.onItems=function(){apply();if(G.currentTab()==="sk"||G.currentTab()==="cash")G.refresh()};
  }
  window.GoguSkins={start:start,products:products,render:function(s,f){return render(s,f||0)},thumb:function(o,sl){return thumb(o,sl)},equipped:function(){return equipped()},ready:function(){return ready}};
  if(window.GoguGame)start(window.GoguGame);
})();
