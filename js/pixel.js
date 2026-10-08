// Пиксельный режим v4: прогулка по двору со скроллингом камеры (экран 320×180, мир 560×180)
window.PixelMap = (() => {
const W = 320, H = 180, WW = 560;
const Y_MIN = 108, Y_MAX = 146; // тротуар/двор: где можно ходить
let cv, cx, bgC, fgC, lightC, running = false, cfg = null, onEnter = null, raf = 0, last = 0, camX = 0, T = 0;
const keys = {};
const hero = { x: 96, y: 114, dir: 'down', t: 0, moving: false, target: null, autoEnter: null, stepT: 0, idleT: 0 };
let msgT = 0, msgText = '';
let drops = [], splashes = [], cars = [], crows = [], smoke = [], trains = [];
let world = 'yard', tickT = 0; // v10: 'yard' — двор, 'station' — дорога к станции
const rnd = seed => { let s = seed; return () => (s = (s * 16807) % 2147483647) / 2147483647; };

// ═══ Спрайт героя (12×26): лохматые чёрные волосы, бледная кожа, чёрная оверсайз-футболка, серые джоггеры ═══
const PAL = { K:'#121018', k:'#2e2a3a', h:'#4a4560', S:'#f3e3db', s:'#d6bcb2', E:'#1b1622', e:'#8a7f96', T:'#19181f', t:'#2f2d3a', J:'#80808c', j:'#5e5e6b', B:'#0c0c10', W:'#cfcfd6', R:'#c23a58', P:'#cfd3dc' };
const HEAD = {
  down: ['...kKKkK....','..KKKKKKKk..','.KKKhKKKKKK.','.KKKKKKKKKKK','KKKSKKKSKKKK','.KSSSSSSSSK.','PKeESSSeESKP','.KSSSSSSSSK.','..SSSssSSS..','...SSSSSS...'],
  up:   ['...kKKkK....','..KKKKKKKk..','.KKKKhKKKKK.','.KKKKKKKKKKK','KKKKKKKKKKKK','.KKKKKKKKKK.','PKKKKKKKKKKP','.KKKKKKKKKK.','..KKKKKKKK..','...SSSSSS...'],
  side: ['...kKKkK....','..KKKKKKKk..','.KKKKhKKKKK.','KKKKKKKKKKK.','KKKKKKKSKSKK','.KKKSSSSSSS.','.KKPSSSSeES.','.KKKSSSSSSS.','..KKSSSSss..','...SSSSSS...'],
};
const TORSO_F = ['....SSSS....','.TTTTTTTTTT.','TTTtTTTTtTTT','TTTTTTTTTTTT','TTTTTTTTTTTT','.TTTTTTTTTT.','.TTTTTTTTTT.','.TtTTTTTTtT.'];
const TORSO_S = ['....SSSS....','...TTTTTT...','..TTTTTTTT..','..TTtTTTTT..','..TTTTTTTT..','..TTTTTTTT..','..TTTTTTTT..','..TTTTTTTT..'];
const LEGS_F = [
  ['..JJJJJJJJ..','..JJJJJJJJ..','..JJJ..JJJ..','..JJJ..JJJ..','..jJJ..JJj..','..jjj..jjj..','.BBBB..BBBB.','.WWWW..WWWW.'],
  ['..JJJJJJJJ..','..JJJJJJJJ..','..JJJ..JJJ..','..jJJ..JJJ..','..jjj..JJj..','.BBBB..jjj..','.WWWW.BBBB..','......WWWW..'],
  ['..JJJJJJJJ..','..JJJJJJJJ..','..JJJ..JJJ..','..JJJ..JJj..','..jJJ..jjj..','..jjj.BBBB..','.BBBB.WWWW..','.WWWW.......'],
];
const LEGS_S = [
  ['...JJJJJJ...','...JJJJJJ...','....JJJJ....','....JJJJ....','....JJjJ....','....jjjj....','....BBBBB...','....WWWWW...'],
  ['...JJJJJJ...','..JJJJJJJ...','..JJJ.JJJ...','.JJJ...JJJ..','.jJJ...JJj..','.jjj...jjj..','BBBB...BBBBB','WWWW...WWWWW'],
  ['...JJJJJJ...','...JJJJJJ...','...JJJJJ....','...JJJJJ....','...JjjJJ....','...jjjjj....','...BBBBBB...','...WWWWWW...'],
];
function px(x, y, c) { cx.fillStyle = c; cx.fillRect(x, y, 1, 1); }
function rows(rs, x, y, flip) { rs.forEach((r, j) => { for (let i = 0; i < r.length; i++) { const c = r[flip ? r.length - 1 - i : i]; if (c !== '.') px(x + i, y + j, PAL[c]); } }); }
function drawHero(x, y) {
  const side = hero.dir === 'left' || hero.dir === 'right', flip = hero.dir === 'left';
  const ph = hero.moving ? (hero.t * 8 | 0) % 4 : 0;          // 0..3 шаг
  const leg = hero.moving ? [1, 0, 2, 0][ph] : 0;
  const bob = hero.moving ? (ph % 2 ? -1 : 0) : (Math.sin(hero.idleT * 2.2) > .6 ? -0 : 0);
  const breathe = !hero.moving && (hero.idleT % 3) > 2.6 ? 1 : 0;
  const ox = x - 6, oy = y - 26 + bob;
  // тень
  cx.fillStyle = 'rgba(0,0,0,.32)'; cx.fillRect(x - 5, y - 1, 11, 2); cx.fillRect(x - 4, y + 1, 9, 1);
  rows(side ? LEGS_S[leg] : LEGS_F[leg], ox, oy + 18, flip);
  rows(side ? TORSO_S : TORSO_F, ox, oy + 10 + breathe, flip);
  // руки: рукав футболки + бледное предплечье, качаются при ходьбе
  const sw = hero.moving ? [1, 0, -1, 0][ph] : 0;
  if (side) {
    const ax = flip ? ox + 5 : ox + 6, d = flip ? -sw : sw;
    px(ax, oy + 12, PAL.t); px(ax, oy + 13, PAL.T); px(ax, oy + 14, PAL.T);
    px(ax + d, oy + 15, PAL.S); px(ax + d, oy + 16, PAL.S); px(ax + d * 2, oy + 17, PAL.s);
    if (!flip) px(ax + d, oy + 16, PAL.R);
  } else if (hero.dir === 'down' || hero.dir === 'up') {
    [[ox - 1, sw], [ox + 12, -sw]].forEach(([axx, d], i) => {
      px(axx, oy + 12, PAL.T); px(axx, oy + 13, PAL.T); px(axx, oy + 14, PAL.t);
      px(axx, oy + 15 + Math.max(0, d), PAL.S); px(axx, oy + 16 + Math.max(0, d), PAL.S);
      if (i === 1 && hero.dir === 'down') px(axx, oy + 15 + Math.max(0, d), PAL.R);
    });
  }
  rows(HEAD[side ? 'side' : hero.dir], ox, oy, flip);
  // моргание
  if (hero.dir === 'down' && (hero.idleT % 4) > 3.85) { px(ox + 3, oy + 6, PAL.S); px(ox + 4, oy + 6, PAL.s); px(ox + 7, oy + 6, PAL.s); px(ox + 8, oy + 6, PAL.S); }
}

// ═══ Мелкие NPC (пиксели) ═══
const NPC = {
  valya: { p:{ h:'#c4c4ca', f:'#a9a9b0', g:'#8d7f78', s:'#f1d9c7', c:'#8e2b2e', C:'#6a1d22', d:'#55545a', D:'#403f45', w:'#e9e4da', b:'#5a3e2a' },
    r:['..hhfhh..','.hfhhhfh.','.hsssssh.','.hgsssgh.','..sssss..','.ccccccc.','ccCcccCcc','cccsscccc','.ccccccc.','.ddddddd.','dDddddDdd','.ddddddd.','..ww.ww..','..bb.bb..'] },
  timur: { p:{ K:'#16151b', S:'#efd6c6', E:'#222', G:'#2a3152', g:'#1f2540', H:'#323b60', J:'#17171c', B:'#17171c', W:'#0d0d10', L:'#efd6c6' },
    r:['..KKKKK.','.KKKKKKK','.KSSSSK.','.KSESES.','..SSSS..','.GHHHHG.','GGHHHHGG','GGHHHHGG','SGGGGGGL','.GGGGGG.','.JJJJJJ.','.JJ..JJ.','.JJ..JJ.','.BB..BB.','.WW..WW.'] },
  margo: { p:{ g:'#ececf0', b:'#d6d6dc', S:'#efdccf', E:'#333', o:'#efdccf', c:'#36353b', C:'#2a292e', d:'#2e2d33', B:'#1a1a1d' },
    r:['...gb...','..gggg..','.gggggg.','.gSSSSg.','.oEooEo.','..SSSS..','.ccddcc.','cccddccc','cccddccc','.ccddcc.','.cddddc.','..dddd..','..dddd..','..S..S..','..B..B..'] },
  sera: { p:{ P:'#8a2236', p:'#64172a', b:'#f2f2f2', S:'#f6e6e0', E:'#c2203a', G:'#cfcfd4', g:'#a9a9b2', k:'#55555e', L:'#1d1c22', B:'#18171c', W:'#2e2d33' },
    r:['.b.PPPP.b..','bbPPPPPPbb.','.PPPPPPPP..','PPSSSSSSPP.','PPSESSESPP.','PP.SSSS.PP.','PPGGGGGGPP.','PGGGGGGGGP.','PGGGGGGGGP.','PSGGGGGGSP.','P.kkkkkk.P.','P.kkkkkk.P.','p..LL.LL.p.','p..LL.LL...','...LL.LL...','..BBB.BBB..','..WWW.WWW..'] },
};
NPC.matvey = { p:{ h:'#9a8a78', H:'#7d6f60', S:'#f1ddd0', E:'#2a2a30', C:'#2e2c31', c:'#232126', w:'#e8e8ea', x:'#9a7440', d:'#1d1c20', B:'#121114' },
  r:['..hhhh..','.hHhhhh.','.hSSSSh.','..SESE..','..SSSS..','.CCwwCC.','CCCwwCCC','CCCxCCCC','CCCCcCCC','SCCCcCCS','.CCCcCC.','.CCCCCC.','.dd..dd.','.dd..dd.','.BB..BB.'] };
NPC.sera_sit = { p: NPC.sera.p, r: NPC.sera.r.slice(0, 12).concat(['.PLLLLLLP..', '..LLLLLL...', '..BB..BB...']) };
function drawNpc(id, x, y, t) {
  const n = NPC[id]; const bob = Math.sin(t / 600 + x) > .7 ? -1 : 0;
  cx.fillStyle = 'rgba(0,0,0,.3)'; cx.fillRect(x - 1, y + n.r.length - 1, n.r[0].length + 2, 2);
  n.r.forEach((r, j) => { for (let i = 0; i < r.length; i++) if (r[i] !== '.') { cx.fillStyle = n.p[r[i]]; cx.fillRect(x + i, y + j + (j < 6 ? bob : 0), 1, 1); } });
}

// ═══ Фон: рисуется один раз на мир 560 px ═══
function paintBg(time) {
  if (world === 'station') return paintStation(time);
  bgC = document.createElement('canvas'); bgC.width = WW; bgC.height = H; const g = bgC.getContext('2d'); const R = rnd(11);
  const sky = { day: ['#7d8494', '#b9b3ab'], eve: ['#2f2848', '#a8607a'], night: ['#0b0a18', '#262040'] }[time] || ['#7d8494', '#b9b3ab'];
  const dark = time !== 'day';
  const gr = g.createLinearGradient(0, 0, 0, 96); gr.addColorStop(0, sky[0]); gr.addColorStop(1, sky[1]); g.fillStyle = gr; g.fillRect(0, 0, WW, 100);
  // тяжёлые облака
  for (let k = 0; k < 26; k++) { const x = R() * WW, y = R() * 26, w = 30 + R() * 70; g.fillStyle = dark ? `rgba(20,16,36,${.25 + R() * .3})` : `rgba(90,94,108,${.18 + R() * .25})`; g.fillRect(x | 0, y | 0, w | 0, 3 + (R() * 5 | 0)); }
  // дальний план: ТЭЦ и панельки
  g.fillStyle = dark ? '#221e36' : '#8d909c';
  for (let x = 0; x < WW; x += 26 + (R() * 14 | 0)) { const h = 30 + R() * 24; g.fillRect(x, 92 - h, 22, h); }
  [[214, 10], [228, 14], [470, 18]].forEach(([x, y]) => { g.fillStyle = dark ? '#2a2540' : '#9a9ca8'; g.fillRect(x, y, 6, 70); g.fillStyle = dark ? '#6a2f44' : '#b8656b'; g.fillRect(x, y + 4, 6, 3); g.fillRect(x, y + 14, 6, 2); });
  g.fillStyle = dark ? 'rgba(255,190,120,.35)' : 'rgba(0,0,0,.08)'; for (let x = 0; x < WW; x += 3) for (let y = 50; y < 90; y += 5) if (R() < .06) g.fillRect(x, y, 1, 1);
  const lit = dark ? .5 : .1;
  const win = (x, y, w, h) => { const on = R() < lit; g.fillStyle = on ? (R() < .5 ? '#ffd27a' : '#ffae5a') : (dark ? '#25213a' : '#5b6170'); g.fillRect(x, y, w, h);
    if (!on) { g.fillStyle = dark ? '#312c48' : '#79808f'; g.fillRect(x, y, w, 1); } if (on && R() < .3) { g.fillStyle = 'rgba(80,40,30,.5)'; g.fillRect(x + w - 2, y, 2, h); } };
  function panel(x0, w, top, col, floors) {
    g.fillStyle = col; g.fillRect(x0, top, w, 98 - top);
    g.fillStyle = 'rgba(0,0,0,.16)'; for (let y = top + 13; y < 98; y += 13) g.fillRect(x0, y, w, 1); for (let x = x0 + 18; x < x0 + w; x += 18) g.fillRect(x, top, 1, 98 - top);
    g.fillStyle = 'rgba(255,255,255,.06)'; g.fillRect(x0, top, w, 1);
    g.fillStyle = dark ? '#1a1724' : '#55535c'; g.fillRect(x0 - 1, top - 2, w + 2, 2); // карниз
    for (let y = top + 4; y < 86; y += 13) for (let x = x0 + 5; x < x0 + w - 7; x += 9) win(x, y, 5, 7);
    // потёки и балконы
    for (let k = 0; k < 8; k++) { g.fillStyle = 'rgba(0,0,0,.12)'; g.fillRect(x0 + (R() * w | 0), top + (R() * 30 | 0), 1, 10 + (R() * 30 | 0)); }
    for (let y = top + 11; y < 80; y += 13) for (let x = x0 + 22; x < x0 + w - 20; x += 54) { g.fillStyle = dark ? '#3a3548' : '#8c8a90'; g.fillRect(x, y, 20, 3); g.fillStyle = 'rgba(0,0,0,.25)'; g.fillRect(x, y + 3, 20, 1); }
  }
  // гаражи слева
  g.fillStyle = dark ? '#2b2a33' : '#6f6e72'; g.fillRect(0, 78, 26, 20); g.fillStyle = dark ? '#3c3a46' : '#8a8890'; for (let x = 1; x < 26; x += 9) g.fillRect(x, 82, 7, 16);
  // дом героя и Серы (подъезд №3)
  panel(28, 162, 14, dark ? '#4a4658' : '#a19f9a');
  g.fillStyle = dark ? '#2d2a35' : '#6d6a70'; g.fillRect(84, 72, 26, 3);           // козырёк
  g.fillStyle = '#3a2c27'; g.fillRect(90, 76, 14, 22); g.fillStyle = '#251c19'; g.fillRect(91, 77, 12, 21); g.fillStyle = '#8f7a5a'; g.fillRect(100, 87, 1, 3); // дверь
  g.fillStyle = '#ffd98a'; g.fillRect(95, 73, 4, 2);
  g.fillStyle = '#3d4a6a'; g.fillRect(92, 79, 3, 2); // домофон
  // граффити
  g.fillStyle = dark ? '#7a3a5a' : '#8b4a62'; [[118, 88], [121, 87], [124, 88], [127, 86], [130, 88]].forEach(([x, y]) => g.fillRect(x, y, 2, 1));
  // детская площадка: качели, песочница, горка
  g.fillStyle = '#7b2d2d'; g.fillRect(212, 102, 2, 18); g.fillRect(238, 102, 2, 18); g.fillRect(212, 102, 28, 2);
  g.fillStyle = '#4b6b8a'; g.fillRect(250, 104, 2, 16); g.fillRect(262, 108, 2, 12); g.fillStyle = '#b8a040'; for (let k = 0; k < 10; k++) g.fillRect(252 + k, 104 + k, 2, 1);
  g.fillStyle = '#5a3a1f'; g.fillRect(196, 124, 16, 2); g.fillStyle = '#c4ad7c'; g.fillRect(197, 120, 14, 4);
  // кафе «Луна»
  panel(280, 96, 24, dark ? '#4c4256' : '#ada397');
  g.fillStyle = '#2b1b18'; g.fillRect(286, 70, 84, 28); g.fillStyle = dark ? '#ffbe6e' : '#d9a675'; g.fillRect(290, 74, 24, 15); g.fillRect(344, 74, 22, 15);
  g.fillStyle = 'rgba(60,30,20,.6)'; g.fillRect(290, 82, 24, 1); g.fillRect(344, 82, 22, 1);
  g.fillStyle = '#5a3a2a'; g.fillRect(322, 75, 14, 23); g.fillStyle = '#c9a05a'; g.fillRect(333, 86, 1, 2);
  g.fillStyle = '#7a2a2a'; for (let x = 288; x < 368; x += 6) { g.fillRect(x, 66, 3, 4); } g.fillStyle = '#e8d8c0'; for (let x = 291; x < 368; x += 6) g.fillRect(x, 66, 3, 4);
  // магазин «24 часа»: павильон
  g.fillStyle = dark ? '#3b3f3a' : '#8a9286'; g.fillRect(386, 60, 76, 38); g.fillStyle = 'rgba(0,0,0,.2)'; g.fillRect(386, 60, 76, 2);
  g.fillStyle = dark ? '#cfeff7' : '#aecfd8'; g.fillRect(390, 70, 22, 22); g.fillRect(436, 70, 22, 22);
  g.fillStyle = 'rgba(30,60,50,.35)'; for (let y = 72; y < 92; y += 4) { g.fillRect(390, y, 22, 1); g.fillRect(436, y, 22, 1); }
  g.fillStyle = '#5b6a6e'; g.fillRect(416, 72, 16, 26); g.fillStyle = '#9fb9bd'; g.fillRect(418, 74, 5, 22); g.fillRect(425, 74, 5, 22);
  // колледж (кирпич)
  g.fillStyle = dark ? '#53403d' : '#a7806e'; g.fillRect(470, 22, 90, 76);
  g.fillStyle = 'rgba(0,0,0,.18)'; for (let y = 24; y < 98; y += 3) g.fillRect(470, y, 90, 1); for (let y = 24; y < 98; y += 6) for (let x = 470 + (y % 12 ? 0 : 3); x < 560; x += 6) g.fillRect(x, y, 1, 3);
  for (let y = 30; y < 74; y += 14) for (let x = 476; x < 556; x += 12) { g.fillStyle = '#e7dccb'; g.fillRect(x - 1, y - 1, 8, 11); win(x, y, 6, 9); }
  g.fillStyle = '#e7dccb'; g.fillRect(500, 74, 30, 3); g.fillRect(502, 77, 2, 21); g.fillRect(526, 77, 2, 21); g.fillStyle = '#4a2f26'; g.fillRect(507, 79, 16, 19);
  // тротуар
  g.fillStyle = dark ? '#5a5762' : '#9d9a95'; g.fillRect(0, 98, WW, 10); g.fillStyle = 'rgba(0,0,0,.18)'; for (let x = 0; x < WW; x += 12) g.fillRect(x, 98, 1, 10); g.fillRect(0, 98, WW, 1);
  // двор (асфальт с трещинами)
  g.fillStyle = dark ? '#34323d' : '#6c6a70'; g.fillRect(0, 108, WW, 44);
  for (let k = 0; k < 260; k++) { g.fillStyle = R() < .5 ? 'rgba(255,255,255,.05)' : 'rgba(0,0,0,.14)'; g.fillRect(R() * WW | 0, 108 + R() * 44 | 0, 1 + (R() * 2 | 0), 1); }
  g.fillStyle = 'rgba(0,0,0,.25)'; for (let k = 0; k < 14; k++) { let x = R() * WW | 0, y = 110 + R() * 38 | 0; for (let s = 0; s < 8; s++) { g.fillRect(x, y, 1, 1); x += R() < .5 ? 1 : -1; y += 1; } }
  // газоны с жухлой травой
  [[0, 108, 26], [140, 108, 50], [470, 108, 40]].forEach(([x, y, w]) => { g.fillStyle = dark ? '#2f3a2a' : '#5f6e48'; g.fillRect(x, y, w, 5); for (let i = 0; i < w; i += 2) { g.fillStyle = R() < .5 ? (dark ? '#4a4a2a' : '#8a8a4a') : (dark ? '#26301f' : '#4e5c3a'); g.fillRect(x + i, y - 1, 1, 2); } });
  // бордюр и дорога
  g.fillStyle = dark ? '#77737e' : '#b7b4ae'; g.fillRect(0, 152, WW, 3); g.fillStyle = 'rgba(0,0,0,.25)'; g.fillRect(0, 155, WW, 1);
  g.fillStyle = dark ? '#1f1e25' : '#45444b'; g.fillRect(0, 156, WW, 24);
  g.fillStyle = dark ? '#8a8670' : '#c8c3a8'; for (let x = 4; x < WW; x += 22) g.fillRect(x, 167, 10, 1);
  // лужи (с отражением неба)
  bgC.puddles = [[150, 132, 30, 6], [330, 140, 38, 7], [96, 146, 22, 4], [430, 122, 26, 5], [520, 138, 20, 4], [260, 168, 40, 5]];
  bgC.puddles.forEach(([x, y, w, h]) => { g.fillStyle = dark ? '#3e4866' : '#8a98aa'; g.beginPath(); g.ellipse(x, y, w / 2, h / 2, 0, 0, 7); g.fill();
    g.fillStyle = dark ? '#56628a' : '#a9b6c6'; g.fillRect(x - w / 4 | 0, y - 1, w / 3 | 0, 1); g.fillStyle = 'rgba(0,0,0,.15)'; g.fillRect(x - w / 2 + 2 | 0, y + h / 2 - 1 | 0, w - 4, 1); });
  // опавшие листья
  for (let k = 0; k < 90; k++) { g.fillStyle = ['#b0782a', '#8a5a22', '#c9962e', '#6a4a20'][k % 4]; g.fillRect(R() * WW | 0, 106 + R() * 48 | 0, 2, 1); }
  // люк
  g.fillStyle = 'rgba(0,0,0,.35)'; g.fillRect(366, 128, 10, 4); g.fillStyle = dark ? '#4a4852' : '#848288'; g.fillRect(367, 129, 8, 2);
  // припаркованная «копейка» у бордюра
  (() => { const x = 236, y = 140; g.fillStyle = 'rgba(0,0,0,.35)'; g.fillRect(x - 1, y + 7, 34, 2); g.fillStyle = dark ? '#8c8676' : '#d6cfba'; g.fillRect(x, y, 32, 7); g.fillRect(x + 7, y - 5, 17, 5);
    g.fillStyle = dark ? '#3a4558' : '#7f93a6'; g.fillRect(x + 9, y - 4, 6, 4); g.fillRect(x + 16, y - 4, 6, 4); g.fillStyle = '#111'; g.fillRect(x + 4, y + 6, 6, 3); g.fillRect(x + 22, y + 6, 6, 3);
    g.fillStyle = '#c03030'; g.fillRect(x, y + 2, 1, 2); g.fillStyle = 'rgba(255,255,255,.25)'; g.fillRect(x + 1, y, 30, 1); })();
  // лавочка у подъезда
  g.fillStyle = '#2f6b3e'; g.fillRect(52, 106, 30, 3); g.fillRect(52, 110, 30, 2); g.fillStyle = '#1e4a2a'; g.fillRect(52, 112, 30, 1);
  g.fillStyle = '#222'; g.fillRect(54, 113, 2, 5); g.fillRect(78, 113, 2, 5);
  // урна, мусорные баки
  g.fillStyle = '#3a4a3a'; g.fillRect(114, 108, 5, 7); g.fillStyle = '#2a6a5a'; g.fillRect(170, 100, 12, 10); g.fillRect(184, 100, 12, 10); g.fillStyle = 'rgba(0,0,0,.25)'; g.fillRect(170, 100, 26, 1);
  // фонари
  bgC.lamps = [130, 270, 380, 466];
  bgC.lamps.forEach(x => { g.fillStyle = '#2a2a30'; g.fillRect(x, 66, 2, 42); g.fillRect(x - 4, 66, 9, 2); g.fillStyle = dark ? '#ffe2a0' : '#d8d8d8'; g.fillRect(x - 3, 68, 7, 2); });
  // провода
  g.fillStyle = 'rgba(20,20,26,.55)'; for (let x = 0; x < WW; x++) { g.fillRect(x, 40 + Math.round(Math.sin(x / 140 * Math.PI) * 4 + 4), 1, 1); }
  return bgC;
}
// передний план (деревья, столбы) — отдельный слой поверх героя
function paintFg(time) {
  if (world === 'station') return paintFgStation(time);
  fgC = document.createElement('canvas'); fgC.width = WW; fgC.height = H; const g = fgC.getContext('2d'); const dark = time !== 'day'; const R = rnd(5);
  const cols = dark ? ['#5e4f22', '#7a6526', '#3f381c', '#2a2a18'] : ['#b08a2c', '#cfa63e', '#8a6c22', '#6a5a20'];
  [[14, 178], [124, 182], [204, 180], [300, 181], [404, 179], [548, 180]].forEach(([x, y]) => {
    g.fillStyle = '#2d2018'; g.fillRect(x - 1, y - 30, 3, 30); g.fillRect(x - 4, y - 24, 3, 1); g.fillRect(x + 2, y - 20, 4, 1);
    for (let k = 0; k < 120; k++) { const a = R() * 6.28, r = Math.sqrt(R()) * 14; g.fillStyle = cols[k % 4]; g.fillRect(x + Math.cos(a) * r * 1.2 | 0, y - 38 + Math.sin(a) * r * .8 | 0, 3, 2); }
  });
  return fgC;
}

// ═══ v10: мир «Дорога к станции» — гаражи, ларёк, подземный переход, платформа 47 км ═══
function paintStation(time) {
  bgC = document.createElement('canvas'); bgC.width = WW; bgC.height = H; const g = bgC.getContext('2d'); const R = rnd(29);
  const dark = time !== 'day';
  const sky = { day: ['#7d8494', '#b9b3ab'], eve: ['#2f2848', '#a8607a'], night: ['#0b0a18', '#262040'] }[time] || ['#7d8494', '#b9b3ab'];
  const gr = g.createLinearGradient(0, 0, 0, 96); gr.addColorStop(0, sky[0]); gr.addColorStop(1, sky[1]); g.fillStyle = gr; g.fillRect(0, 0, WW, 100);
  for (let k = 0; k < 26; k++) { const x = R() * WW, y = R() * 26, w = 30 + R() * 70; g.fillStyle = dark ? `rgba(20,16,36,${.25 + R() * .3})` : `rgba(90,94,108,${.18 + R() * .25})`; g.fillRect(x | 0, y | 0, w | 0, 3 + (R() * 5 | 0)); }
  // дальний план: панельки и трубы ТЭЦ (как во дворе — тот же город)
  g.fillStyle = dark ? '#221e36' : '#8d909c';
  for (let x = 0; x < WW; x += 24 + (R() * 16 | 0)) { const h = 22 + R() * 30; g.fillRect(x, 84 - h, 20, h); }
  g.fillStyle = dark ? 'rgba(255,190,120,.4)' : 'rgba(0,0,0,.1)'; for (let x = 0; x < WW; x += 3) for (let y = 40; y < 82; y += 5) if (R() < .05) g.fillRect(x, y, 1, 1);
  [[214, 10], [228, 14], [470, 18]].forEach(([x, y]) => { g.fillStyle = dark ? '#2a2540' : '#9a9ca8'; g.fillRect(x, y, 6, 66); g.fillStyle = dark ? '#6a2f44' : '#b8656b'; g.fillRect(x, y + 4, 6, 3); g.fillRect(x, y + 14, 6, 2); });
  // ряд гаражей (ржавые ворота, граффити)
  const gcol = dark ? ['#3a3236', '#2f3a3a', '#3d3328', '#33303a'] : ['#7a5e4e', '#56706c', '#806a48', '#6a6470'];
  for (let i = 0; i < 7; i++) { const x = 4 + i * 22; g.fillStyle = dark ? '#2a2830' : '#77757a'; g.fillRect(x, 70, 22, 28); g.fillStyle = gcol[i % 4]; g.fillRect(x + 2, 76, 18, 22);
    g.fillStyle = 'rgba(0,0,0,.25)'; g.fillRect(x + 10, 76, 1, 22); for (let k = 0; k < 6; k++) { g.fillStyle = dark ? 'rgba(120,60,30,.35)' : 'rgba(150,80,40,.45)'; g.fillRect(x + 2 + (R() * 18 | 0), 76 + (R() * 22 | 0), 1 + (R() * 2 | 0), 2 + (R() * 4 | 0)); } }
  g.fillStyle = dark ? '#1f1d24' : '#55535a'; g.fillRect(2, 68, 156, 3);
  g.fillStyle = dark ? '#7a3a5a' : '#8b4a62'; [[30, 84], [33, 83], [36, 85], [39, 83], [96, 88], [99, 86], [102, 88]].forEach(([x, y]) => g.fillRect(x, y, 2, 1));
  // ларёк «Табак · Шаурма»
  g.fillStyle = dark ? '#3c4a44' : '#7f968a'; g.fillRect(184, 64, 46, 34); g.fillStyle = '#8a2a2a'; g.fillRect(182, 60, 50, 6);
  g.fillStyle = dark ? '#ffcf7a' : '#d6c8a0'; g.fillRect(190, 72, 30, 16); g.fillStyle = 'rgba(60,40,20,.5)'; g.fillRect(190, 80, 30, 1);
  g.fillStyle = '#2a2420'; g.fillRect(201, 76, 6, 6); g.fillStyle = '#e9cdb8'; g.fillRect(202, 74, 4, 3); // продавщица в окошке
  g.fillStyle = '#5a5a60'; g.fillRect(188, 88, 34, 2);
  [[192, 92], [200, 92], [208, 92]].forEach(([x, y]) => { g.fillStyle = ['#c23a3a', '#3a6ac2', '#e0c040'][((x / 8) | 0) % 3]; g.fillRect(x, y, 5, 5); });
  // путепровод и спуск в подземный переход
  g.fillStyle = dark ? '#3a3844' : '#8e8c90'; g.fillRect(262, 46, 82, 52); g.fillStyle = 'rgba(0,0,0,.18)'; for (let y = 50; y < 98; y += 8) g.fillRect(262, y, 82, 1);
  g.fillStyle = dark ? '#2a2832' : '#6e6c72'; g.fillRect(258, 42, 90, 6);
  g.fillStyle = dark ? '#121118' : '#2e2c34'; g.fillRect(282, 70, 36, 28); // проём
  for (let k = 0; k < 7; k++) { g.fillStyle = `rgba(${dark ? 70 : 120},${dark ? 66 : 116},${dark ? 80 : 124},${.9 - k * .11})`; g.fillRect(284, 84 + k * 2, 32, 1); }
  g.fillStyle = dark ? '#cfe8ff' : '#eef4f8'; g.fillRect(292, 72, 16, 1); // лампа в переходе
  g.fillStyle = '#2a4a8a'; g.fillRect(288, 60, 24, 7); g.fillStyle = '#e8eef8'; g.fillRect(291, 63, 18, 1);
  g.fillStyle = '#5a5a62'; g.fillRect(278, 76, 2, 22); g.fillRect(320, 76, 2, 22); g.fillRect(278, 76, 6, 1); g.fillRect(316, 76, 6, 1);
  g.fillStyle = dark ? '#7a3a5a' : '#8b4a62'; [[266, 80], [268, 79], [270, 81], [330, 84], [333, 83], [336, 85]].forEach(([x, y]) => g.fillRect(x, y, 2, 1));
  // железная дорога: насыпь, рельсы, опоры контактной сети
  g.fillStyle = dark ? '#2b2a30' : '#6a6668'; g.fillRect(344, 84, WW - 344, 16);
  for (let x = 346; x < WW; x += 5) { g.fillStyle = dark ? '#3e3530' : '#6e5a48'; g.fillRect(x, 92, 3, 6); }
  g.fillStyle = dark ? '#8a8a96' : '#b8b8c0'; g.fillRect(344, 92, WW - 344, 1); g.fillRect(344, 97, WW - 344, 1);
  for (let x = 356; x < WW; x += 48) { g.fillStyle = dark ? '#2a2a30' : '#5a5a60'; g.fillRect(x, 34, 2, 52); g.fillRect(x - 6, 36, 14, 2); }
  g.fillStyle = 'rgba(20,20,26,.6)'; for (let x = 344; x < WW; x++) g.fillRect(x, 40 + Math.round(Math.sin((x - 344) / 48 * Math.PI) * 1.5 + 1.5), 1, 1);
  // земля: асфальт до перехода, дальше бетон платформы с жёлтой линией
  g.fillStyle = dark ? '#5a5762' : '#9d9a95'; g.fillRect(0, 98, 344, 10); g.fillStyle = 'rgba(0,0,0,.18)'; for (let x = 0; x < 344; x += 12) g.fillRect(x, 98, 1, 10);
  g.fillStyle = dark ? '#34323d' : '#6c6a70'; g.fillRect(0, 108, 344, 44);
  g.fillStyle = dark ? '#4a4852' : '#8f8c88'; g.fillRect(344, 100, WW - 344, 52);
  g.fillStyle = dark ? '#a8902a' : '#d8b840'; g.fillRect(344, 102, WW - 344, 2);
  g.fillStyle = 'rgba(0,0,0,.35)'; g.fillRect(344, 100, WW - 344, 1);
  for (let k = 0; k < 300; k++) { g.fillStyle = R() < .5 ? 'rgba(255,255,255,.05)' : 'rgba(0,0,0,.14)'; g.fillRect(R() * WW | 0, 104 + R() * 48 | 0, 1 + (R() * 2 | 0), 1); }
  g.fillStyle = 'rgba(0,0,0,.25)'; for (let k = 0; k < 16; k++) { let x = R() * WW | 0, y = 110 + R() * 38 | 0; for (let q = 0; q < 8; q++) { g.fillRect(x, y, 1, 1); x += R() < .5 ? 1 : -1; y += 1; } }
  g.fillStyle = dark ? '#77737e' : '#b7b4ae'; g.fillRect(340, 104, 4, 48);
  // навес платформы, лавочка, табличка «47 км», будка кассы
  g.fillStyle = dark ? '#3a2e2a' : '#7a5a4a'; g.fillRect(420, 48, 140, 5); g.fillStyle = 'rgba(0,0,0,.3)'; g.fillRect(420, 53, 140, 1);
  [430, 548].forEach(x => { g.fillStyle = dark ? '#44404a' : '#8a8890'; g.fillRect(x, 53, 4, 54); });
  g.fillStyle = dark ? '#32402e' : '#4e6a46'; g.fillRect(484, 100, 30, 3); g.fillRect(484, 104, 30, 2); g.fillStyle = '#222'; g.fillRect(486, 106, 2, 4); g.fillRect(510, 106, 2, 4);
  g.fillStyle = '#e8e2d0'; g.fillRect(462, 58, 16, 8); g.fillStyle = '#2a2a30'; g.fillRect(469, 66, 2, 40);
  g.fillStyle = dark ? '#3a3a40' : '#7a7a80'; g.fillRect(372, 70, 22, 30); g.fillStyle = dark ? '#1a1a22' : '#40404a'; g.fillRect(376, 76, 14, 9);
  // лужи
  bgC.puddles = [[60, 128, 30, 6], [150, 140, 34, 6], [238, 124, 22, 5], [300, 142, 30, 6], [400, 130, 26, 5], [520, 140, 30, 6]];
  bgC.puddles.forEach(([x, y, w, h]) => { g.fillStyle = dark ? '#3e4866' : '#8a98aa'; g.beginPath(); g.ellipse(x, y, w / 2, h / 2, 0, 0, 7); g.fill(); g.fillStyle = dark ? '#56628a' : '#a9b6c6'; g.fillRect(x - w / 4 | 0, y - 1, w / 3 | 0, 1); });
  for (let k = 0; k < 70; k++) { g.fillStyle = ['#b0782a', '#8a5a22', '#c9962e', '#6a4a20'][k % 4]; g.fillRect(R() * 340 | 0, 106 + R() * 48 | 0, 2, 1); }
  // ближний край: бурьян и бетонный забор
  g.fillStyle = dark ? '#2f2d36' : '#7c7a80'; g.fillRect(0, 152, WW, 28);
  for (let x = 0; x < WW; x += 30) { g.fillStyle = 'rgba(0,0,0,.25)'; g.fillRect(x, 152, 1, 28); g.fillStyle = 'rgba(255,255,255,.05)'; for (let y = 156; y < 180; y += 6) g.fillRect(x + 4, y, 22, 1); }
  for (let x = 0; x < WW; x += 2) { g.fillStyle = R() < .5 ? (dark ? '#2a3322' : '#5e6a44') : (dark ? '#384028' : '#76804e'); g.fillRect(x, 148 + (R() * 4 | 0), 1, 6); }
  // фонари
  bgC.lamps = [70, 168, 250, 404, 520];
  bgC.lamps.forEach(x => { g.fillStyle = '#2a2a30'; g.fillRect(x, 66, 2, 42); g.fillRect(x - 4, 66, 9, 2); g.fillStyle = dark ? '#ffd090' : '#d8d8d8'; g.fillRect(x - 3, 68, 7, 2); });
  g.fillStyle = 'rgba(20,20,26,.55)'; for (let x = 0; x < 344; x++) g.fillRect(x, 44 + Math.round(Math.sin(x / 120 * Math.PI) * 4 + 4), 1, 1);
  return bgC;
}
function paintFgStation(time) {
  fgC = document.createElement('canvas'); fgC.width = WW; fgC.height = H; const g = fgC.getContext('2d'); const dark = time !== 'day'; const R = rnd(8);
  const cols = dark ? ['#3e3a1c', '#4a4420', '#2f2c16', '#24241a'] : ['#8a7a2c', '#a08a3a', '#6a5c22', '#58501e'];
  [[26, 180], [212, 182], [356, 180], [470, 181]].forEach(([x, y]) => { g.fillStyle = '#2d2018'; g.fillRect(x - 1, y - 26, 3, 26);
    for (let k = 0; k < 90; k++) { const a = R() * 6.28, r = Math.sqrt(R()) * 12; g.fillStyle = cols[k % 4]; g.fillRect(x + Math.cos(a) * r * 1.2 | 0, y - 32 + Math.sin(a) * r * .8 | 0, 3, 2); } });
  // столб с проводами на переднем плане
  g.fillStyle = '#1e1c22'; g.fillRect(300, 120, 3, 60); g.fillRect(294, 122, 15, 2);
  return fgC;
}
// электрички на путях (за платформой, выезжают из-под путепровода)
function updTrains(dt) {
  if (world !== 'station') return;
  if (Math.random() < dt * .06 && !trains.length) { const dir = Math.random() < .5 ? -1 : 1; trains.push({ x: dir < 0 ? WW + 20 : 150, dir, v: 110 + Math.random() * 40, n: 3 + (Math.random() * 2 | 0) });
    if (window.Sound) Sound.sfx('train'); }
  trains.forEach(t => t.x += t.dir * t.v * dt); trains = trains.filter(t => t.dir < 0 ? t.x + t.n * 64 > 300 : t.x < WW + 40);
}
function drawTrains(time) {
  if (world !== 'station' || !trains.length) return; const dark = time !== 'day';
  cx.save(); cx.beginPath(); cx.rect(344 - camX, 0, WW, H); cx.clip();
  trains.forEach(t => { for (let i = 0; i < t.n; i++) { const x = Math.round(t.x + (t.dir < 0 ? i : -i) * 64 - camX), y = 72;
    cx.fillStyle = dark ? '#2c4436' : '#3d6a52'; cx.fillRect(x, y, 62, 20); cx.fillStyle = dark ? '#6a6a72' : '#9a9aa2'; cx.fillRect(x + 1, y - 2, 60, 2);
    cx.fillStyle = '#a82a2a'; cx.fillRect(x, y + 14, 62, 2);
    for (let w = 4; w < 58; w += 7) { cx.fillStyle = dark ? (Math.sin(w + i) > -.6 ? '#ffd890' : '#3a3a40') : '#8fa6b0'; cx.fillRect(x + w, y + 4, 5, 6); }
    cx.fillStyle = '#16161a'; cx.fillRect(x + 6, y + 20, 8, 3); cx.fillRect(x + 48, y + 20, 8, 3);
    if (i === 0) { const fx = t.dir < 0 ? x : x + 61; cx.fillStyle = '#fff6c8'; cx.fillRect(fx, y + 10, 1, 2); cx.fillStyle = '#2a2a30'; cx.fillRect(x + 26, y - 7, 10, 1); cx.fillRect(x + 30, y - 6, 1, 4);
      if (dark) { cx.fillStyle = 'rgba(255,240,190,.14)'; cx.fillRect(t.dir < 0 ? fx - 60 : fx + 1, y + 4, 60, 14); } } } });
  cx.restore();
}
// ═══ v10: задания на карте — листовки (cfg.items), таймер (cfg.timer), справки (cfg.info) ═══
function itemNear() { if (!cfg.items) return null; let best = null, bd = 15; cfg.items.forEach(([x], i) => { if (cfg.got.includes(i)) return; const d = Math.hypot(x - hero.x, (112 - hero.y) * 1.2); if (d < bd) { bd = d; best = 'it' + i; } }); return best; }
function pickItem(id) {
  const i = +id.slice(2); if (cfg.got.includes(i)) return; cfg.got.push(i); window.Sound && Sound.sfx('tear');
  say((cfg.itemLines && cfg.itemLines[i]) || 'Сорвал. Скомкал. В карман.'); cfg.onItem && cfg.onItem(cfg.got.length);
  if (cfg.got.length >= cfg.items.length) { const done = cfg.itemsDone || 'Кажется, всё. Больше ни одной.'; setTimeout(() => { say(done); setTimeout(() => { if (running) { stop(); onEnter && onEnter('__items'); } }, 1700); }, 1500); }
}
function drawItems(t) {
  if (!cfg.items) return;
  cfg.items.forEach(([x, y], i) => { if (cfg.got.includes(i)) return; const sx = Math.round(x - camX); if (sx < -8 || sx > W + 8) return; const fl = Math.sin(t / 260 + i) > .6 ? 1 : 0;
    cx.fillStyle = 'rgba(0,0,0,.3)'; cx.fillRect(sx - 2, y + 1, 6, 7); cx.fillStyle = '#ecebe4'; cx.fillRect(sx - 3, y, 6, 7 - fl); cx.fillStyle = '#8a2236'; cx.fillRect(sx - 2, y + 1, 4, 3); cx.fillStyle = '#3a3a40'; cx.fillRect(sx - 2, y + 5, 4, 1);
    const by = y - 8 + Math.round(Math.sin(t / 300 + i) * 1.2); cx.fillStyle = '#ffe36b'; cx.fillRect(sx, by, 1, 3); cx.fillRect(sx, by + 4, 1, 1); });
}
// ═══ Живой мир: дождь, машины, вороны, дым ═══
function initFx() {
  drops = Array.from({ length: 140 }, () => ({ x: Math.random() * (W + 40), y: Math.random() * H, v: 140 + Math.random() * 90, l: 3 + (Math.random() * 4 | 0) }));
  splashes = []; cars = []; crows = Array.from({ length: 3 }, (_, i) => ({ x: 60 + i * 170, y: 41 + i, fly: 0, vx: 0, vy: 0, t: Math.random() * 5 }));
  smoke = [];
}
function updFx(dt) {
  drops.forEach(d => { d.y += d.v * dt; d.x -= d.v * dt * .12; if (d.y > 108 + Math.random() * 70 || d.x < -10) {
    if (d.y > 108 && Math.random() < .35) splashes.push({ x: d.x + camX, y: d.y, t: 0 }); d.y = -5 - Math.random() * 20; d.x = Math.random() * (W + 40); } });
  splashes.forEach(s => s.t += dt); splashes = splashes.filter(s => s.t < .25);
  if (world === 'yard' && Math.random() < dt * .18 && cars.length < 2) { const dir = Math.random() < .5 ? 1 : -1; cars.push({ x: dir > 0 ? -40 : WW + 40, y: dir > 0 ? 170 : 160, dir, v: 70 + Math.random() * 40, c: ['#8a2a2a', '#d8d2c0', '#3a4a6a', '#5a6a4a'][Math.random() * 4 | 0] }); }
  cars.forEach(c => c.x += c.dir * c.v * dt); cars = cars.filter(c => c.x > -60 && c.x < WW + 60);
  crows.forEach(c => { c.t += dt;
    if (!c.fly && Math.abs(c.x - hero.x) < 22 && Math.abs(hero.y - 108) < 60 && c.y > 90) { c.fly = 1; c.vx = (c.x > hero.x ? 1 : -1) * 50; c.vy = -40; }
    if (c.fly) { c.x += c.vx * dt; c.y += c.vy * dt; c.vy += 6 * dt; if (c.y < 20 || c.x < -20 || c.x > WW + 20) { c.fly = 0; c.x = 40 + Math.random() * (WW - 80); c.y = 41; } } });
  if (Math.random() < dt * 3) [214, 228, 470].forEach(x => smoke.push({ x: x + 3, y: [10, 14, 18][[214, 228, 470].indexOf(x)], t: 0 }));
  smoke.forEach(s => { s.t += dt; s.x += 5 * dt; s.y -= 4 * dt; }); smoke = smoke.filter(s => s.t < 4);
}
function drawFx(time) {
  const dark = time !== 'day';
  // дым ТЭЦ (дальний план)
  drawTrains(time);
  smoke.forEach(s => { cx.fillStyle = dark ? `rgba(120,110,140,${.25 * (1 - s.t / 4)})` : `rgba(220,220,225,${.35 * (1 - s.t / 4)})`; const r = 2 + s.t * 2; cx.fillRect(s.x - camX - r / 2 | 0, s.y - r / 2 | 0, r | 0, r * .7 | 0); });
}
function drawWorldFx(time, t) {
  const dark = time !== 'day';
  // вороны
  crows.forEach(c => { const x = c.x - camX | 0, y = c.y | 0; cx.fillStyle = '#121016';
    if (c.fly) { const f = (c.t * 10 | 0) % 2; cx.fillRect(x - 2, y - f, 2, 1); cx.fillRect(x + 1, y - f, 2, 1); cx.fillRect(x, y, 1, 1); }
    else { cx.fillRect(x, y, 3, 2); cx.fillRect(x + 2, y - 1, 1, 1); cx.fillRect(x - 1, y + 1, 1, 1); } });
  // машины
  cars.forEach(c => { const x = c.x - camX | 0, y = c.y; if (x < -50 || x > W + 50) return;
    cx.fillStyle = 'rgba(0,0,0,.35)'; cx.fillRect(x - 1, y + 6, 32, 2); cx.fillStyle = c.c; cx.fillRect(x, y, 30, 6); cx.fillRect(x + 6, y - 4, 16, 4);
    cx.fillStyle = dark ? '#ffd88a' : '#9fb4c4'; cx.fillRect(x + 8, y - 3, 6, 3); cx.fillRect(x + 15, y - 3, 6, 3);
    cx.fillStyle = '#111'; cx.fillRect(x + 4, y + 5, 5, 3); cx.fillRect(x + 21, y + 5, 5, 3);
    cx.fillStyle = dark ? '#fff2b0' : '#e8e8e0'; cx.fillRect(c.dir > 0 ? x + 29 : x, y + 1, 1, 2); cx.fillStyle = '#d02a2a'; cx.fillRect(c.dir > 0 ? x : x + 29, y + 1, 1, 2);
    if (dark) { cx.fillStyle = 'rgba(255,230,160,.12)'; cx.fillRect(c.dir > 0 ? x + 30 : x - 30, y - 1, 30, 7); } });
  // всплески
  splashes.forEach(s => { const x = s.x - camX | 0, y = s.y | 0; cx.fillStyle = 'rgba(210,220,240,.55)'; const k = s.t < .12 ? 1 : 2; cx.fillRect(x - k, y, 1, 1); cx.fillRect(x + k, y, 1, 1); if (k === 1) cx.fillRect(x, y - 1, 1, 1); });
  // рябь на лужах
  bgC.puddles.forEach(([x, y, w], i) => { const ph = (t / 900 + i * .37) % 1; const rx = x - camX + Math.sin(i * 7) * w / 4; cx.fillStyle = `rgba(230,235,255,${.4 * (1 - ph)})`; const r = 1 + ph * 5 | 0; cx.fillRect(rx - r | 0, y, 1, 1); cx.fillRect(rx + r | 0, y, 1, 1); });
}
function drawRain() {
  cx.fillStyle = 'rgba(200,210,235,.42)';
  drops.forEach(d => { for (let k = 0; k < d.l; k++) cx.fillRect(d.x - k * .12 | 0, d.y + k | 0, 1, 1); });
}
function drawLight(time, t) {
  if (time === 'day') { cx.fillStyle = 'rgba(40,50,70,.12)'; cx.fillRect(0, 0, W, H); return; }
  if (!lightC) { lightC = document.createElement('canvas'); lightC.width = W; lightC.height = H; }
  const l = lightC.getContext('2d'); l.globalCompositeOperation = 'source-over'; l.clearRect(0, 0, W, H);
  l.fillStyle = time === 'night' ? 'rgba(6,4,22,.62)' : 'rgba(26,10,44,.38)'; l.fillRect(0, 0, W, H);
  l.globalCompositeOperation = 'destination-out';
  const glow = (x, y, r, a) => { const gg = l.createRadialGradient(x, y, 1, x, y, r); gg.addColorStop(0, `rgba(0,0,0,${a})`); gg.addColorStop(1, 'rgba(0,0,0,0)'); l.fillStyle = gg; l.fillRect(x - r, y - r, r * 2, r * 2); };
  bgC.lamps.forEach((x, i) => { const fl = i === 2 && Math.sin(t / 90) > .93 ? .3 : 1; glow(x + 1 - camX, 92, 34, .9 * fl); glow(x + 1 - camX, 70, 8, 1); });
  (world === 'station' ? [[205, 80, 26], [300, 80, 16], [383, 80, 10], [470, 62, 10]] : [[97, 74, 16], [329, 84, 28], [424, 82, 30], [515, 86, 16]]).forEach(([x, y, r]) => glow(x - camX, y, r, .85));
  glow(hero.x - camX, hero.y - 12, 14, .35);
  cx.drawImage(lightC, 0, 0);
  // тёплые ореолы
  cx.globalCompositeOperation = 'lighter';
  bgC.lamps.forEach(x => { const gg = cx.createRadialGradient(x + 1 - camX, 96, 2, x + 1 - camX, 96, 30); gg.addColorStop(0, 'rgba(90,60,20,.35)'); gg.addColorStop(1, 'rgba(0,0,0,0)'); cx.fillStyle = gg; cx.fillRect(x - 30 - camX, 66, 62, 62); });
  cx.globalCompositeOperation = 'source-over';
}

// ═══ Точки интереса ═══
const SPOTS = {
  home:    { x: 97,  y: 110, label: 'Подъезд №3 · домой' },
  valya:   { x: 67,  y: 118, label: 'Лавочка у подъезда' },
  cafe:    { x: 329, y: 110, label: 'Кафе «Луна»' },
  store:   { x: 424, y: 110, label: 'Магазин «24 часа»' },
  college: { x: 515, y: 110, label: 'Художественный колледж' },
  swing:   { x: 226, y: 124, label: 'Качели', decor: true },
};
const SIGNS = [['Подъезд №3', 97, 63], ['Кафе «Луна»', 329, 58], ['24 часа', 424, 52], ['Колледж искусств', 515, 66]];
const ST_SPOTS = {
  home:      { x: 22,  y: 116, label: 'Обратно во двор' },
  kiosk:     { x: 205, y: 112, label: 'Ларёк «Табак · Шаурма»' },
  underpass: { x: 300, y: 112, label: 'Подземный переход' },
  platform:  { x: 499, y: 114, label: 'Платформа 47 км' },
};
const ST_SIGNS = [['Гаражи', 80, 62], ['Табак · Шаурма', 207, 52], ['Переход', 300, 54], ['47 км', 470, 50]];
const SP = () => Object.assign({}, world === 'station' ? ST_SPOTS : SPOTS, cfg.extra || {});
const avail = id => id === 'home' || (id === 'swing' ? world === 'yard' && cfg.time !== 'day' && !cfg.follow && !cfg.items : cfg.spots.includes(id) || !!(cfg.info && cfg.info[id]));
function near() { const it = itemNear(); if (it) return it; let best = null, bd = 18; Object.entries(SP()).forEach(([id, s]) => { if (!avail(id)) return; const d = Math.hypot(s.x - hero.x, (s.y - hero.y) * 1.4); if (d < bd) { bd = d; best = id; } }); return best; }
const SWING_LINES = ['Сера сидит на качелях с альбомом и рисует котов. Увидела меня — показала язык. Увидимся вечером.', 'Сера раскачивается, глядя в небо. «Не мешай, я ловлю вдохновение», — говорит она, не оборачиваясь.'];
function act(id) {
  if (!id) return;
  if (id === '__allitems' && cfg.items) { cfg.items.forEach((_, i) => { if (!cfg.got.includes(i)) cfg.got.push(i); }); stop(); onEnter && onEnter('__items'); return; }
  if (id.startsWith('it') && cfg.items) return pickItem(id);
  if (cfg.info && cfg.info[id] && !cfg.spots.includes(id)) { const v = cfg.info[id]; const k = (cfg.infoN = cfg.infoN || {})[id] = ((cfg.infoN[id] || 0) + 1); return say(Array.isArray(v) ? v[(k - 1) % v.length] : v); }
  if (id === 'home') return say(cfg.home || (cfg.items ? 'Сначала — листовки. Все до одной.' : 'Рано возвращаться. Хочется ещё куда-нибудь заглянуть.'));
  if (id === 'swing') return say(SWING_LINES[(cfg.title || '').length % 2]);
  if (cfg.done.includes(id)) return say('Сегодня я тут уже был.');
  window.Sound && Sound.sfx('enter'); stop(); onEnter && onEnter(id);
}
function say(t) { msgText = t; msgT = 3.2; }
// ═══ Сера идёт следом за героем (cfg.follow) ═══
const trail = []; let folT = 6, folI = 0;
const FOLLOW_LINES = ['Сера: «Не беги так. У меня ноги короче, чем твоя совесть».', 'Сера: «Смотри, лужа в форме таракана. Это знак».', 'Сера: «Я тут каждую ночь хожу. С тобой почему-то не так страшно. Только не зазнавайся».', 'Сера: «Ты всегда так сутулишься? Выпрямись, затворник».', 'Сера: «Магазин там, если что. Направо. Вечно направо».'];
const folLines = () => cfg.lines || FOLLOW_LINES;
function follower() { const k = Math.max(0, trail.length - 18); return trail[k] || { x: hero.x - 14, y: hero.y }; }

// ═══ Логика ═══
function blocked(x, y) { // препятствия: лавочка, баки, песочница, качели
  if (world === 'station') return false;
  return [[52, 104, 82, 113], [234, 134, 270, 150], [170, 98, 196, 111], [196, 119, 212, 127], [211, 116, 241, 121]].some(([a, b, c, d]) => x > a && x < c && y > b && y < d);
}
function update(dt) {
  let dx = 0, dy = 0;
  if (keys.ArrowLeft || keys.a) dx--; if (keys.ArrowRight || keys.d) dx++; if (keys.ArrowUp || keys.w) dy--; if (keys.ArrowDown || keys.s) dy++;
  if (dx || dy) { hero.target = null; hero.autoEnter = null; }
  else if (hero.target) { const vx = hero.target.x - hero.x, vy = hero.target.y - hero.y, d = Math.hypot(vx, vy); if (d < 1.5) { hero.target = null; if (hero.autoEnter) { const a = hero.autoEnter; hero.autoEnter = null; act(a); } } else { dx = vx / d; dy = vy / d; } }
  hero.moving = !!(dx || dy);
  if (hero.moving) {
    const l = Math.hypot(dx, dy), sp = (keys.Shift ? 92 : 64) * dt; const nx = hero.x + dx / l * sp, ny = hero.y + dy / l * sp * .8;
    if (!blocked(nx, hero.y)) hero.x = nx; if (!blocked(hero.x, ny)) hero.y = ny;
    hero.t += dt * (keys.Shift ? 1.4 : 1);
    hero.dir = Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'right' : 'left') : (dy > 0 ? 'down' : 'up');
    hero.stepT -= dt; if (hero.stepT <= 0) { hero.stepT = keys.Shift ? .2 : .27; window.Sound && Sound.sfx('step'); }
    hero.idleT = 0;
  } else { hero.idleT += dt; hero.t = 0; }
  if (cfg.follow) {
    const l = trail[trail.length - 1]; if (!l || Math.hypot(l.x - hero.x, l.y - hero.y) > 1.2) { trail.push({ x: hero.x, y: hero.y, m: 1 }); if (trail.length > 60) trail.shift(); }
    folT -= dt; if (folT <= 0 && msgT <= 0) { folT = 9 + Math.random() * 5; say(folLines()[folI++ % folLines().length]); }
  }
  hero.x = Math.max(6, Math.min(WW - 6, hero.x)); hero.y = Math.max(Y_MIN, Math.min(Y_MAX + 4, hero.y));
  camX += ((Math.max(0, Math.min(WW - W, hero.x - W / 2))) - camX) * Math.min(1, dt * 5);
  updFx(dt); updTrains(dt);
  if (cfg.timer != null) { cfg.tleft = Math.max(0, (cfg.tleft == null ? cfg.timer : cfg.tleft) - dt); tickT -= dt;
    if (tickT <= 0) { tickT = .25; const s = Math.ceil(cfg.tleft); document.getElementById('pixTask').textContent = `${cfg.task} · ${s / 60 | 0}:${String(s % 60).padStart(2, '0')}`; cfg.onTick && cfg.onTick(cfg.tleft);
      document.getElementById('pixTask').classList.toggle('hurry', s <= 15); }
    if (cfg.tleft <= 0) { stop(); onEnter && onEnter('__late'); } }
}
function render(dt, t) {
  const time = cfg.time || 'day';
  cx.drawImage(bgC, -Math.round(camX), 0);
  drawFx(time);
  const n = near();
  // персонажи и герой, сортировка по глубине (y)
  const actors = [];
  if (world === 'yard' && !cfg.quiet && (cfg.spots.includes('valya') || !!(cfg.info && cfg.info.valya))) actors.push({ y: 113, d: () => drawNpc('valya', 60 - Math.round(camX), 100, t) });
  if (world === 'yard' && !cfg.quiet && (cfg.spots.includes('store') || !!(cfg.info && cfg.info.store))) actors.push({ y: 112, d: () => drawNpc('timur', 446 - Math.round(camX), 97, t) });
  if (world === 'yard' && !cfg.quiet && (cfg.spots.includes('college') || !!(cfg.info && cfg.info.college)) && time === 'day') actors.push({ y: 112, d: () => drawNpc('margo', 534 - Math.round(camX), 97, t) });
  if (cfg.follow) { const f = follower(), mv = hero.moving && trail.length > 18; actors.push({ y: f.y, d: () => drawNpc('sera', Math.round(f.x - 5 - camX), Math.round(f.y - 16 + (mv && Math.sin(t / 90) > 0 ? -1 : 0)), t) }); }
  else if (world === 'yard' && time !== 'day' && !cfg.items && !cfg.noSera) actors.push({ y: 121, d: () => drawNpc('sera', 220 - Math.round(camX), 104 + (Math.sin(t / 500) > 0 ? 0 : 1), t) });
  if (cfg.seraBench) actors.push({ y: 106, d: () => drawNpc('sera_sit', 494 - Math.round(camX), 93 + (Math.sin(t / 700) > .3 ? 1 : 0), t) });
  (cfg.npcs || []).forEach(n => actors.push({ y: n.y + 14, d: () => drawNpc(n.id, Math.round(n.x - camX), n.y, t) }));
  actors.push({ y: hero.y, d: () => drawHero(Math.round(hero.x - camX), Math.round(hero.y)) });
  actors.sort((a, b) => a.y - b.y).forEach(a => a.d());
  drawWorldFx(time, t);
  drawItems(t);
  // маркеры над точками
  Object.entries(SP()).forEach(([id, s]) => { if (id === 'home' || !avail(id)) return; const done = cfg.done.includes(id); const x = Math.round(s.x - camX); const info = cfg.info && cfg.info[id] && !cfg.spots.includes(id);
    if (x < -10 || x > W + 10) return; const by = Math.round(s.y - 34 + Math.sin(t / 300 + s.x) * 1.5);
    if (info) { cx.fillStyle = n === id ? '#ffe36b' : '#9fd0ff'; cx.fillRect(x - 1, by + 2, 3, 3); cx.fillRect(x, by + 6, 1, 2); return; } // «?» — справка
    if (s.decor) { cx.fillStyle = n === id ? '#ffe36b' : '#ff9fc0'; cx.fillRect(x - 1, by + 4, 3, 2); cx.fillRect(x - 2, by + 3, 2, 1); cx.fillRect(x + 1, by + 3, 2, 1); cx.fillRect(x, by + 6, 1, 1); return; } // сердечко
    cx.fillStyle = 'rgba(0,0,0,.5)'; cx.fillRect(x - 3, by - 1, 7, 10);
    cx.fillStyle = done ? 'rgba(160,160,170,.9)' : (n === id ? '#ffe36b' : '#ff6b9a');
    if (done) { [[-2, 4], [-1, 5], [0, 4], [1, 3], [2, 2]].forEach(([a, b]) => cx.fillRect(x + a, by + b, 1, 1)); }
    else { cx.fillRect(x, by, 2, 5); cx.fillRect(x, by + 6, 2, 2); } });
  cx.drawImage(fgC, -Math.round(camX), 0);
  drawRain();
  drawLight(time, t);
  // HTML-подписи едут вместе с камерой
  document.querySelectorAll('#pixwrap .psign').forEach(el => { const x = +el.dataset.x - camX; el.style.left = (x / W * 100) + '%'; el.style.display = x < -30 || x > W + 30 ? 'none' : ''; });
  const pr = document.getElementById('pixPrompt');
  if (msgT > 0) { msgT -= dt; pr.textContent = msgText; pr.classList.add('show'); }
  else if (n) { const done = n !== 'home' && cfg.done.includes(n); pr.innerHTML = n.startsWith('it') ? `<b>E</b> · ${cfg.itemLabel || 'Сорвать листовку'}` : `<b>E</b> · ${SP()[n].label}${done ? ' <i>(уже был)</i>' : ''}`; pr.classList.add('show'); }
  else pr.classList.remove('show');
  // мини-карта
  const mm = document.getElementById('pixMini'); if (mm) { const k = hero.x / WW * 100; mm.querySelector('.me').style.left = k + '%'; }
}
function loop(t) {
  if (!running) return; const dt = Math.min(.05, (t - last) / 1000 || 0); last = t; T = t;
  if (document.getElementById('modal').classList.contains('hidden')) update(dt);
  render(dt, t); raf = requestAnimationFrame(loop);
}
const KMAP = { 'ц':'w', 'ф':'a', 'ы':'s', 'в':'d', 'у':'e' };
function kd(e) {
  if (!running || !document.getElementById('modal').classList.contains('hidden')) return;
  const k = e.key.length === 1 ? e.key.toLowerCase() : e.key; const kk = KMAP[k] || k;
  if (['ArrowLeft','ArrowRight','ArrowUp','ArrowDown',' '].includes(kk)) e.preventDefault();
  if (kk === 'e' || kk === 'Enter' || kk === ' ') { act(near()); return; }
  keys[kk] = true;
}
function ku(e) { const k = e.key.length === 1 ? e.key.toLowerCase() : e.key; keys[KMAP[k] || k] = false; }
function click(e) {
  const r = cv.getBoundingClientRect(); const x = (e.clientX - r.left) / r.width * W + camX, y = (e.clientY - r.top) / r.height * H;
  let hit = null; Object.entries(SP()).forEach(([id, s]) => { if (avail(id) && Math.abs(x - s.x) < 14 && y > s.y - 44 && y < s.y + 10) hit = id; });
  let ht = null; (cfg.items || []).forEach(([ix, iy], i) => { if (!cfg.got.includes(i) && Math.abs(x - ix) < 9 && y > iy - 12 && y < 124) ht = { id: 'it' + i, x: ix, y: 112 }; });
  if (ht) { hero.target = { x: ht.x, y: ht.y }; hero.autoEnter = ht.id; return; }
  hero.target = hit ? { x: SP()[hit].x, y: SP()[hit].y + 2 } : { x, y: Math.max(Y_MIN, Math.min(Y_MAX, y)) }; hero.autoEnter = hit;
}
function open(c, cb) {
  cfg = c; onEnter = cb; world = c.world || 'yard'; trains = []; tickT = 0; if (c.items && !c.got) c.got = []; cv = document.getElementById('pix'); cx = cv.getContext('2d'); cv.width = W; cv.height = H; cx.imageSmoothingEnabled = false;
  paintBg(c.time || 'day'); paintFg(c.time || 'day'); initFx();
  if (c.pos) { hero.x = c.pos.x; hero.y = c.pos.y; } else if (c.start) { hero.x = c.start.x; hero.y = c.start.y; hero.dir = c.start.dir || 'right'; } else { hero.x = 97; hero.y = 116; hero.dir = 'down'; }
  hero.target = null; hero.autoEnter = null; for (const k in keys) keys[k] = false;
  trail.length = 0; folT = 4; for (let i = 0; i < 20; i++) trail.push({ x: hero.x - 14 + i * .7, y: hero.y });
  camX = Math.max(0, Math.min(WW - W, hero.x - W / 2));
  document.getElementById('pixDay').textContent = c.title || ''; document.getElementById('pixTask').textContent = c.task || '';
  const wrap = document.getElementById('pixwrap');
  wrap.querySelectorAll('.psign').forEach(e => e.remove()); (world === 'station' ? ST_SIGNS : SIGNS).forEach(([t, x, y]) => {
    const d = document.createElement('div'); d.className = 'psign'; d.textContent = t; d.dataset.x = x; d.style.top = (y / H * 100) + '%'; wrap.appendChild(d); });
  let mm = document.getElementById('pixMini');
  if (mm) mm.remove(); { mm = document.createElement('div'); mm.id = 'pixMini'; mm.innerHTML = '<i class="me"></i>' + Object.entries(SP()).filter(([, s]) => !s.decor).map(([id, s]) => `<b data-id="${id}" style="left:${s.x / WW * 100}%"></b>`).join(''); wrap.appendChild(mm); }
  mm.querySelectorAll('b').forEach(b => { const id = b.dataset.id; b.className = id === 'home' ? 'home' : !avail(id) ? 'off' : cfg.done.includes(id) ? 'done' : ''; });
  wrap.classList.remove('hidden');
  if (!running) { running = true; last = performance.now(); raf = requestAnimationFrame(loop); }
}
function stop() { running = false; cancelAnimationFrame(raf); if (cfg) cfg.pos = { x: hero.x, y: hero.y }; document.getElementById('pixwrap').classList.add('hidden'); }
addEventListener('keydown', kd); addEventListener('keyup', ku);
setTimeout(() => { const c = document.getElementById('pix'); if (c) c.addEventListener('click', click); }, 0);
return { open, close: stop, enter: id => act(id), world: () => world, pos: () => ({ x: hero.x, y: hero.y }), isOpen: () => running };
})();
