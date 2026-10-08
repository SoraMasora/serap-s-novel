// Движок визуальной новеллы
(() => {
const $ = s => document.querySelector(s);
const A = window.ASSETS || { bg:{}, sprites:{} };
const st = { scene:'start', i:0, feel:50, press:0, flags:{}, notes:[], name:'Кирилл', bg:null, chars:{}, music:null, rain:false, chapter:'', mode:'', map:null };
let typing = false, full = '', tIdx = 0, tTimer = null, waiting = false, auto = false, skip = false, inChoice = false;
const log = []; const LOGMAX = 2000;
// v12: снимок состояния для отката из журнала (без заметок — они только дописываются, хранится их число)
function snapLite(off = -1) { const o = JSON.parse(JSON.stringify({ ...st, notes: undefined, i: Math.max(0, st.i + off) })); o.nc = (st.notes || []).length; return o; }
function logPush(e) { log.push(e); if (log.length > LOGMAX) log.shift(); }
const opts = Object.assign({ speed: 28, music: 0.6, autoDelay: 1800 }, JSON.parse(localStorage.getItem('serap_opts') || '{}'));
Sound.setVol('music', opts.music);

// ── Заставка ──
A.title = A.title || {}; A.ui = A.ui || {};
document.documentElement.style.setProperty('--vine', `url(${A.ui.vine})`);
$('#logoImg').src = A.ui.logo;
document.querySelectorAll('#tAnim .tf').forEach(i => i.src = A.title[i.dataset.f]);
// ветки цветов на кнопках
function vineify(btn) { ['l','r','t','b'].forEach(s => { const v = document.createElement('span'); v.className = 'vine ' + s; btn.appendChild(v); }); }
document.querySelectorAll('.vbtn').forEach(vineify);
// анимация титульного экрана: Сера перебирает пальцами + моргает
const TF = {}; document.querySelectorAll('#tAnim .tf').forEach(i => TF[i.dataset.f] = i);
let tfCur = 't0', tfTimer = null, tfStep = 0;
const tfSeq = ['t0','t1','t0','t2','t1','t0','t2','t0'];
function tfShow(k) { if (k === tfCur) return; TF[k].classList.add('on'); const old = TF[tfCur]; tfCur = k; setTimeout(() => { if (old !== TF[tfCur]) old.classList.remove('on'); }, 360); }
function titleAnim(on) {
  clearTimeout(tfTimer); if (!on) return;
  (function loop() {
    let k = tfSeq[tfStep++ % tfSeq.length], d = 520 + Math.random() * 380;
    if (k === 't0' && Math.random() < .35) { // моргание
      TF.tb.classList.add('on'); setTimeout(() => TF.tb.classList.remove('on'), 140);
    }
    tfShow(k); tfTimer = setTimeout(loop, d);
  })();
}
titleAnim(true);
// пылинки и неон
const dc = $('#tDust'), dx = dc.getContext('2d'); let motes = [];
function dResize() { dc.width = dc.clientWidth; dc.height = dc.clientHeight; motes = Array.from({ length: 45 }, () => ({ x: Math.random(), y: Math.random(), r: .5 + Math.random() * 1.8, v: .0002 + Math.random() * .0005, p: Math.random() * 6 })); }
addEventListener('resize', dResize); dResize();
(function dFrame(t) {
  if (!$('#title').classList.contains('hidden')) {
    dx.clearRect(0, 0, dc.width, dc.height);
    motes.forEach(m => { m.y -= m.v; m.x += Math.sin(t / 2000 + m.p) * .0003; if (m.y < 0) m.y = 1;
      dx.fillStyle = `rgba(255,${170 + 60 * Math.sin(m.p)},200,${.25 + .25 * Math.sin(t / 700 + m.p)})`; dx.beginPath(); dx.arc(m.x * dc.width, m.y * dc.height, m.r, 0, 7); dx.fill(); });
  }
  requestAnimationFrame(dFrame);
})(0);
$('#btnLoadT').onclick = () => { Sound.init(); slotsUI('load'); };
const refreshContinue = () => $('#btnContinue').disabled = !localStorage.getItem('serap_save_auto');
refreshContinue();

$('#btnNew').onclick = () => { Sound.init(); titleAnim(false); $('#title').classList.add('hidden'); $('#nameScreen').classList.remove('hidden'); $('#nameInput').focus(); };
$('#nameOk').onclick = () => {
  const n = $('#nameInput').value.trim(); Object.assign(st, { scene:'start', i:0, feel:50, press:0, flags:{}, notes:[], name: n || 'Кирилл', bg:null, chars:{}, music:null, rain:false, chapter:'', mode:'', map:null });
  log.length = 0; $('#nameScreen').classList.add('hidden'); begin();
};
$('#nameInput').onkeydown = e => { if (e.key === 'Enter') $('#nameOk').click(); };
$('#btnContinue').onclick = () => { Sound.init(); loadSlot('auto'); };
$('#btnSettings').onclick = settings;
$('#btnEndings').onclick = endingsList;
$('#endBack').onclick = toTitle;

function begin(noRun) { titleAnim(false); $('#title').classList.add('hidden'); $('#hud').classList.remove('hidden'); if (st.mode === 'map') { openMap(); return; } $('#textbox').classList.remove('hidden'); if (!noRun) run(); }
function toTitle() {
  auto = skip = false; syncBtns(); clearTimeout(tTimer);
  ['#ending','#modal','#textbox','#hud','#choices','#card'].forEach(s => $(s).classList.add('hidden')); PixelMap.close();
  $('#chars').innerHTML = ''; Sound.loc('title'); Sound.music('calm'); Sound.rain(false); setRain(false);
  $('#title').classList.remove('hidden'); $('#side').classList.add('hidden'); titleAnim(true); refreshContinue();
}

// ── Фон и персонажи ──
let bgFront = $('#bg'), bgBack = $('#bg2');
function camTo(c) { // наезд камеры на точку фона: {x,y — % ; s — масштаб; ms}
  [bgFront, bgBack].forEach(b => { b.style.transition = ''; b.style.transform = ''; b.style.transformOrigin = ''; });
  if (!c) return; const ms = skip ? 1 : (c.ms || 1400);
  bgFront.style.transition = `opacity 1.2s ease,transform ${ms}ms cubic-bezier(.45,0,.2,1)`; bgFront.style.transformOrigin = `${c.x}% ${c.y}%`;
  void bgFront.offsetWidth; bgFront.style.transform = `scale(${c.s || 1.6})`;
}
// катсцена: кадры сменяют друг друга сами (клик — следующий кадр)
let cutKill = null;
function playCut(frames) {
  // Новый кадр плавно проявляется ПОВЕРХ старого (старый гаснет только после перехода),
  // зум идёт один на всю катсцену на обёртке .cstage — кадры не «прыгают».
  const c = $('#cut'), stage = c.querySelector('.cstage'), L = [...c.querySelectorAll('.cimg')], cap = c.querySelector('.ccap');
  let k = 0, cur = 1, tm = null, offT = null, endT = null; const cutSnap = snapLite(-1);
  $('#textbox').classList.add('hidden'); $('#side').classList.add('hidden'); c.classList.remove('hidden', 'out');
  const total = frames.reduce((s, f) => s + (f.ms || 2600), 0) + 1200;
  stage.style.animation = 'none'; void stage.offsetWidth; stage.style.animation = skip ? 'none' : `cutzoom ${total}ms linear forwards`;
  const next = () => {
    clearTimeout(tm);
    if (k > frames.length + 50) return; if (k >= frames.length) { c.onclick = null; c.classList.add('out'); endT = setTimeout(() => { cutKill = null; c.classList.add('hidden'); c.classList.remove('out'); clearTimeout(offT); L.forEach(x => { x.classList.remove('on'); x.style.zIndex = ''; }); stage.style.animation = 'none'; cap.textContent = ''; $('#textbox').classList.remove('hidden'); run(); }, skip ? 50 : 700); return; }
    const f = frames[k++], prev = L[cur]; cur ^= 1; const el = L[cur];
    clearTimeout(offT);
    el.style.backgroundImage = `url(${A.bg[f.img]})`; el.style.zIndex = 2; prev.style.zIndex = 1;
    el.classList.remove('on'); void el.offsetWidth; el.classList.add('on');
    if (prev.classList.contains('on')) offT = setTimeout(() => prev.classList.remove('on'), skip ? 0 : 900);
    cap.classList.remove('show'); void cap.offsetWidth; cap.textContent = f.text ? fmt(f.text) : ''; if (f.text) cap.classList.add('show');
    if (f.text) logPush({ n: '', t: fmt(f.text), s: cutSnap });
    if (f.sfx && !skip) Sound.sfx(f.sfx);
    tm = setTimeout(next, skip ? 200 : (f.ms || 2600));
  };
  cutKill = () => { clearTimeout(tm); clearTimeout(offT); clearTimeout(endT); c.onclick = null; k = frames.length + 99; L.forEach(x => { x.classList.remove('on'); x.style.zIndex = ''; }); stage.style.animation = 'none'; cap.textContent = ''; c.classList.add('hidden'); c.classList.remove('out'); cutKill = null; };
  c.onclick = e => { e.stopPropagation(); next(); }; next();
}
function setBg(k, instant) {
  camTo(null); st.bg = k; if (typeof applyRain === 'function') applyRain(); Sound.loc(k); const url = `url(${A.bg[k]})`;
  if (instant) { bgFront.style.backgroundImage = url; bgFront.style.opacity = 1; bgBack.style.opacity = 0; return; }
  bgBack.style.backgroundImage = url; bgBack.style.opacity = 1; bgFront.style.opacity = 0;
  [bgFront, bgBack] = [bgBack, bgFront];
}
const POS = { left:'25%', center:'50%', right:'75%', fl:'16%', fr:'84%' };
const SINGLE = { father:1, valya:1, timur:1, liza:1, margo:1, matvey:1 };
const WHO = { '???':'sera', 'Сера':'sera', 'Пастор':'father', 'P':'hero', 'Баба Валя':'valya', 'Тимур':'timur', 'Лиза':'liza', 'Маргарита Павловна':'margo', 'Матвей':'matvey', 'Парень в пальто':'matvey' };
const BLINK = { neutral:1, cold:1 };
const THOUGHT = '~'; // внутренний голос героя // для этих эмоций есть кадр моргания
const baseImg = el => el.querySelector('img.base');
function setImg(el, key) { const im = baseImg(el); const src = A.sprites[key]; if (src && im.getAttribute('src') !== src) im.src = src; }
function syncBlink(el, expr) { const b = el.querySelector('img.blink'); if (el.dataset.who === 'sera' && BLINK[expr] && A.sprites['blink_' + expr]) { b.src = A.sprites['blink_' + expr]; b.dataset.ok = 1; } else delete b.dataset.ok; }
function showChar(who, expr, pos) {
  const key = SINGLE[who] ? (expr && A.sprites[who + '_' + expr] ? who + '_' + expr : who) : who + '_' + expr;
  const prev = st.chars[who];
  pos = pos || (prev && prev.pos) || 'center';
  st.chars[who] = { expr, pos };
  let el = document.querySelector(`.char[data-who="${who}"]:not([data-dying])`);
  if (!el) {
    el = document.createElement('div'); el.className = 'char fade'; el.dataset.who = who;
    el.innerHTML = '<div class="shiftw"><div class="idle"><img class="base" alt=""><img class="blink" alt=""></div></div>';
    el.querySelector('.idle').style.animationDelay = (-Math.random() * 6).toFixed(2) + 's';
    $('#chars').appendChild(el); setImg(el, key); el.style.left = POS[pos];
    requestAnimationFrame(() => requestAnimationFrame(() => el.classList.remove('fade')));
  } else { if (!el.dataset.reacting) setImg(el, key); el.style.left = POS[pos]; el.classList.remove('fade'); }
  syncBlink(el, expr);
}
// ── Анимация бездействия: моргание и смена веса ──
function idleLoop() {
  document.querySelectorAll('.char[data-who="sera"]:not([data-dying])').forEach(el => {
    const b = el.querySelector('img.blink');
    if (b.dataset.ok && !el.dataset.reacting && !leanOn && Math.random() < .42) {
      el.classList.add('blinking'); setTimeout(() => el.classList.remove('blinking'), 130);
      if (Math.random() < .25) setTimeout(() => { el.classList.add('blinking'); setTimeout(() => el.classList.remove('blinking'), 110); }, 260);
    }
  });
  document.querySelectorAll('.char[data-who="sera"]:not([data-dying])').forEach(el => {
    if (!el.dataset.reacting && Math.random() < .12) { const w = el.querySelector('.shiftw'); w.classList.remove('shiftL', 'shiftR'); void w.offsetWidth; w.classList.add(Math.random() < .5 ? 'shiftL' : 'shiftR'); }
  });
  setTimeout(idleLoop, 1400 + Math.random() * 1600);
}
setTimeout(idleLoop, 1500);
function hideChar(who) {
  const list = who === 'all' ? Object.keys(st.chars) : [who];
  list.forEach(w => { delete st.chars[w]; const el = document.querySelector(`.char[data-who="${w}"]:not([data-dying])`); if (el) { el.dataset.dying = 1; el.classList.add('fade'); setTimeout(() => el.remove(), 500); } });
}
function setSpeaker(name) {
  document.querySelectorAll('.char').forEach(el => {
    const who = el.dataset.who; const active = !name || WHO[name] === who;
    el.style.filter = active || Object.keys(st.chars).length < 2 ? '' : 'brightness(.6) drop-shadow(0 0 14px rgba(0,0,0,.6))';
  });
}

// ── Эффекты: дождь ──
const cv = $('#fx'), cx = cv.getContext('2d'); let drops = [], raining = false;
function resize() { cv.width = cv.clientWidth; cv.height = cv.clientHeight; } addEventListener('resize', resize); resize();
// дождь рисуется на слое ПОД персонажами: на весь экран, но не поверх них
function setRain(on) { raining = on; st.rain = on; document.getElementById('game').classList.toggle('gloom', !!on); /* v13: мрачная палитра, пока идёт дождь */ if (on && !drops.length) drops = Array.from({ length: 650 }, () => newDrop(true)); }
function newDrop(any) { const z = Math.random(); return { x: Math.random() * 1.15 - .05, y: any ? Math.random() : -.1 - Math.random() * .2, z, l: 18 + z * 46, v: .55 + z * .9, a: .12 + z * .38 }; }
const RAIN_SLANT = .12;
const OUTDOOR = { street:1, roof:1, court:1, platform:1, yard:1, street_rain:1 }; // дождь (капли и звук) — только на открытых локациях
function applyRain() { Sound.rain(!!(st.rain && OUTDOOR[st.bg])); }
(function frame() {
  cx.clearRect(0, 0, cv.width, cv.height);
  if (raining && OUTDOOR[st.bg]) {
    const W = cv.width, H = cv.height, k = H / 720;
    const mg = cx.createLinearGradient(0, H * .45, 0, H); mg.addColorStop(0, 'rgba(150,160,200,0)'); mg.addColorStop(1, 'rgba(150,160,200,.10)'); cx.fillStyle = mg; cx.fillRect(0, 0, W, H);
    cx.lineCap = 'round';
    [0, 1, 2].forEach(band => {
      cx.beginPath(); cx.lineWidth = band === 2 ? 1.9 * k : band === 1 ? 1.3 * k : 1 * k;
      cx.strokeStyle = `rgba(215,222,245,${[.38, .58, .85][band]})`;
      drops.forEach(d => { if ((d.z * 3 | 0) !== band) return; const x = d.x * W, y = d.y * H, L = d.l * k; cx.moveTo(x, y); cx.lineTo(x - L * RAIN_SLANT, y + L); });
      cx.stroke();
    });
    drops.forEach((d, i) => { d.y += .022 * d.v; d.x -= .022 * d.v * RAIN_SLANT * (H / W); if (d.y > 1.05) drops[i] = newDrop(false); });
  }
  requestAnimationFrame(frame);
})();
function fx(kind) { const g = $('#game'); g.classList.remove(kind); void g.offsetWidth; g.classList.add(kind); setTimeout(() => g.classList.remove(kind), 700); }

// ── Доверие (скрытое) и заметки о Сере ──
function changeFeel(d) { st.feel = Math.max(0, Math.min(100, st.feel + d)); }
function addNote(t) { st.notes = st.notes || []; if (st.notes.includes(t)) return; st.notes.push(t); if (!skip) toast('✎ Новая заметка о Сере'); }
const NOTES_TOTAL = (() => { const set = new Set(); Object.values(STORY).forEach(sc => sc.forEach(c => { if (c && c.note) set.add(c.note); })); return set.size; })();
function showNotes() {
  const n = st.notes || [];
  openModal(`<h2>Заметки о Сере</h2><p class="nsub">${n.length} из ${NOTES_TOTAL}</p><ul class="notes">${n.length ? n.map(t => `<li>${t}</li>`).join('') : '<li class="empty">Пока я почти ничего о ней не знаю.</li>'}</ul><button id="mClose">Закрыть</button>`);
}
let toastT; function toast(t) { const el = $('#toast'); el.textContent = t; el.classList.add('show'); clearTimeout(toastT); toastT = setTimeout(() => el.classList.remove('show'), 1800); }

// ── Исполнение сценария ──
const fmt = t => t.replace(/\{P\}/g, st.name);
// v9: «тон» маршрута — от него зависят реплики и отношение персонажей.
// warm — дело идёт к хорошей концовке, mid — к нейтральной, cold — к плохой.
function tier(s = st) { if (s.feel < 40 || s.press >= 3) return 'cold'; if (s.feel >= 65 && s.press < 2) return 'warm'; return 'mid'; }
// реплика/эмоция/заметка может быть объектом {warm, mid, cold}; null — строку пропустить
const TV = v => (v && typeof v === 'object' && !Array.isArray(v) && ('mid' in v || 'warm' in v || 'cold' in v)) ? (tier() in v ? v[tier()] : v.mid) : v;
function run() {
  while (true) {
    const scene = STORY[st.scene]; const c = scene[st.i];
    if (!c) return;
    st.i++;
    if (Array.isArray(c)) { const t = TV(c[1]); if (t == null) continue; say(c[0], t, TV(c[2])); return; }
    if (c.tier) { const g = TV(c.tier); if (g) { jump(g); continue; } }
    if (c.card) { showCard(c.card); return; }
    if (c.note) { const n = TV(c.note); if (n) addNote(n); }
    if (c.chapter) { st.chapter = c.chapter; $('#chapter').textContent = c.chapter; }
    if (c.bg) { setBg(c.bg); document.querySelectorAll('#bg,#bg2').forEach(x => x.classList.remove('zoom')); }
    if (c.zoom) bgFront.classList.add('zoom');
    if ('cam' in c) camTo(c.cam);
    if (c.cut) { playCut(c.cut); return; }
    if (c.music) { st.music = c.music; Sound.music(c.music); }
    if ('rain' in c) { setRain(c.rain); applyRain(); }
    if (c.show) showChar(c.who || (c.show === 'father' ? 'father' : 'sera'), c.show, c.pos);
    if (c.hide) hideChar(c.hide);
    if (c.fx && !skip) fx(c.fx);
    if (c.sfx && !skip) Sound.sfx(c.sfx);
    if (c.react && !skip) react(c.react);
    if (typeof c.feel === 'number' && !c.choice) changeFeel(c.feel);
    if (c.set && !c.choice) Object.assign(st.flags, c.set);
    if (c.add && !c.choice) st.press += c.add.press || 0;
    if (c.when) { if (c.when(st)) { jump(c.go); continue; } else continue; }
    if (c.go) { jump(c.go); continue; }
    if (c.breath) { breath(c.breath); return; }
    if (c.choice) { choose(c.choice); return; }
    if (c.ending) { jump(pickEnding(st)); continue; }
    if (c.map) { st.map = Object.assign({ done: [], pos: null }, c.map); st.mode = 'map'; openMap(); return; }
    if (c.tomap) { if (st.map.done.length >= st.map.visits) { const a = st.map.after; st.map = null; st.mode = ''; jump(a); continue; } st.mode = 'map'; openMap(); return; }
    if (c.final) { finish(c.final); return; }
  }
}
function jump(l) { st.scene = l; st.i = 0; }

// v10: мини-игра «Дыши со мной» — зажимай (пробел / мышь), пока круг растёт (вдох), отпускай, пока сжимается (выдох)
let breathOn = false;
function breath(o) {
  const n = o.n || 3, IN = 3000, OUT = 3400, CY = IN + OUT, tot = n * CY;
  $('#textbox').classList.add('hidden'); $('#side').classList.add('hidden');
  let el = $('#breath'); if (!el) { el = document.createElement('div'); el.id = 'breath'; el.className = 'layer';
    el.innerHTML = '<div class="btitle"></div><div class="bring"><div class="bcirc"></div><div class="bcore"></div></div><div class="btxt"></div><div class="bbar"><i></i></div><div class="bhint">Зажми <b>пробел</b> или кнопку мыши, пока круг растёт, — вдох.<br>Отпусти, когда он сжимается, — выдох.</div>';
    $('#game').appendChild(el); }
  el.querySelector('.btitle').textContent = o.title || 'Дыши со мной';
  el.classList.remove('hidden', 'done'); breathOn = true; let held = false, good = 0, all = 0, t0 = null, raf = 0, beat = 0;
  const dn = e => { if (e.type === 'keydown' && e.code !== 'Space' && e.key !== ' ') return; e.preventDefault(); e.stopPropagation(); held = true; };
  const up = e => { if (e.type === 'keyup' && e.code !== 'Space' && e.key !== ' ') return; e.preventDefault(); e.stopPropagation(); held = false; };
  const stopClick = e => { e.stopPropagation(); };
  addEventListener('keydown', dn, true); addEventListener('keyup', up, true); el.addEventListener('pointerdown', dn); addEventListener('pointerup', up, true); el.addEventListener('click', stopClick);
  const circ = el.querySelector('.bcirc'), txt = el.querySelector('.btxt'), bar = el.querySelector('.bbar i');
  Sound.sfx('heart');
  function fr(now) {
    if (t0 == null) t0 = now; const t = now - t0, ph = t % CY, inh = ph < IN, k = inh ? ph / IN : 1 - (ph - IN) / OUT;
    const e = .5 - Math.cos(Math.PI * k) / 2; circ.style.transform = `scale(${(.42 + .58 * e).toFixed(3)})`;
    all++; if (held === inh) good++; const q = good / all;
    el.classList.toggle('sync', held === inh); txt.textContent = (inh ? 'Вдох' : 'Выдох') + '…  ' + (Math.floor(t / CY) + 1) + ' / ' + n;
    bar.style.width = (100 * Math.min(1, t / tot)).toFixed(1) + '%';
    if (t - beat > 2600 && q < .55) { beat = t; Sound.sfx('heart'); }
    if (t < tot && !skip) { raf = requestAnimationFrame(fr); return; }
    removeEventListener('keydown', dn, true); removeEventListener('keyup', up, true); el.removeEventListener('pointerdown', dn); removeEventListener('pointerup', up, true); el.removeEventListener('click', stopClick);
    const score = skip ? 1 : good / Math.max(1, all); st.flags[o.flag || 'breathOk'] = score >= .6; st.flags.breathScore = Math.round(score * 100);
    if (score >= .6 && o.feel) changeFeel(o.feel);
    el.classList.add('done'); txt.textContent = score >= .6 ? (o.ok || 'Ровно. Вместе.') : (o.bad || 'Сбилось… но я всё равно рядом.');
    setTimeout(() => { el.classList.add('hidden'); breathOn = false; $('#textbox').classList.remove('hidden'); if (o.go) jump(score >= .6 ? o.go : (o.fail || o.go)); run(); }, 1500);
  }
  raf = requestAnimationFrame(fr);
}

function say(name, text, expr) {
  const nb = $('#namebox'), tx = $('#text');
  const thought = name === THOUGHT;
  const disp = thought ? '' : name === 'P' ? st.name : name;
  nb.textContent = disp; nb.className = name === 'P' ? 'gg' : name === 'Пастор' ? 'father' : name === '???' ? 'unk' : (WHO[name] && name !== 'Сера') ? 'npc' : '';
  $('#textbox').dataset.kind = thought ? 'thought' : !name ? 'narr' : name === 'P' ? 'gg' : WHO[name] || 'npc';
  if (expr && (name === 'Сера' || name === '???') && st.chars.sera) showChar('sera', expr);
  if (expr && name === 'P' && st.chars.hero) showChar('hero', expr);
  else if (name !== 'P' && WHO[name] && SINGLE[WHO[name]] && st.chars[WHO[name]]) showChar(WHO[name], expr || 'neutral');
  tx.className = thought ? 'thought' : name ? '' : 'narr';
  setSpeaker((name === 'P' && !st.chars.hero) || thought ? null : name);
  const side = $('#side');
  if (name === 'P' && !st.chars.hero) { const src = A.sprites['hero_' + (expr || 'neutral')]; const im = side.querySelector('img');
    if (side.classList.contains('hidden') || im.getAttribute('src') !== src) { im.src = src; im.style.animation = 'none'; void im.offsetWidth; im.style.animation = ''; }
    side.classList.remove('hidden'); } else side.classList.add('hidden');
  full = fmt(text); tIdx = 0; typing = true; waiting = false; $('#next').classList.remove('show');
  logPush({ n: disp, t: full, th: thought, s: snapLite(-1) });
  clearTimeout(tTimer);
  if (skip || opts.speed === 0) { tx.textContent = full; endType(); return; }
  (function type() { tIdx++; tx.textContent = full.slice(0, tIdx); if (tIdx >= full.length) endType(); else tTimer = setTimeout(type, 1000 / Math.max(5, opts.speed) * 1.0); })();
}
function endType() {
  typing = false; waiting = true; $('#text').textContent = full; $('#next').classList.add('show');
  saveSlot('auto', true);
  if (skip) tTimer = setTimeout(advance, 60);
  else if (auto) tTimer = setTimeout(advance, opts.autoDelay + full.length * 25);
}
function advance() {
  if (inChoice || !$('#modal').classList.contains('hidden')) return;
  if (typing) { clearTimeout(tTimer); endType(); return; }
  if (waiting) { waiting = false; run(); }
}

function choose(list) {
  inChoice = true; skip = false; syncBtns(); saveSlot('auto', true); const chSnap = snapLite(-1);
  const box = $('#choices'); box.innerHTML = ''; box.classList.remove('hidden');
  list.forEach(o => {
    const b = document.createElement('button'); b.className = 'vbtn'; b.innerHTML = fmt(o.t) + (o.hint ? `<span class="hint">${o.hint}</span>` : ''); vineify(b);
    b.onmouseenter = () => hoverLean(true); b.onmouseleave = () => hoverLean(false);
    b.onclick = e => {
      e.stopPropagation(); box.classList.add('hidden'); inChoice = false; hoverLean(false);
      const rk = o.react || (o.feel >= 10 ? 'shy' : o.feel >= 5 ? 'hop' : o.feel <= -12 ? 'shake' : o.feel < 0 ? 'shiver' : null);
      if (rk) react(rk);
      logPush({ n: '→', t: fmt(o.t), s: chSnap, ch: 1 });
      if (o.feel) changeFeel(o.feel);
      if (o.set) Object.assign(st.flags, o.set);
      if (o.add) st.press += o.add.press || 0;
      jump(o.go); run();
    };
    box.appendChild(b);
  });
}

function finish(kind) {
  auto = skip = false; syncBtns();
  const got = JSON.parse(localStorage.getItem('serap_endings') || '{}'); got[kind] = true; localStorage.setItem('serap_endings', JSON.stringify(got));
  localStorage.removeItem('serap_save_auto');
  setTimeout(() => {
    $('#endTitle').textContent = ENDINGS[kind].title; $('#endText').textContent = ENDINGS[kind].text + `\n\nЗаметок о Сере собрано: ${(st.notes || []).length} из ${NOTES_TOTAL}`;
    $('#ending').classList.remove('hidden');
  }, 900);
}

// ── Интерактив Серы ──
let reactT = null, leanOn = false;
const seraEl = () => document.querySelector('.char[data-who="sera"]:not([data-dying])');
const isCrying = () => st.chars.sera && /^sad/.test(st.chars.sera.expr);
// когда Сера плачет — никаких языков и поглаживаний: вытирает слёзы, хмурится, опускает голову
const CRY_MAP = { pat: 'wipe', hop: 'wipe', shy: 'wipe', tongue: 'frown', shake: 'frown', shiver: 'down' };
function hoverLean(on) {
  const el = seraEl(); if (!el || el.dataset.reacting) return;
  const crying = isCrying();
  if (on && !leanOn) { leanOn = true; setImg(el, crying ? 'sera_sadwipe' : 'sera_lean'); el.classList.add(crying ? 'react-wipeloop' : 'react-lean'); }
  else if (!on && leanOn) { leanOn = false; el.classList.remove('react-lean', 'react-wipeloop'); if (st.chars.sera) setImg(el, 'sera_' + st.chars.sera.expr); }
}
function hearts(n, dark) {
  for (let k = 0; k < n; k++) setTimeout(() => { const h = document.createElement('span'); h.className = 'heart' + (dark ? ' dark' : ''); h.textContent = dark ? '✝' : '♡';
    h.style.left = (38 + Math.random() * 24) + '%'; h.style.top = (25 + Math.random() * 25) + '%'; $('#fxl').appendChild(h); setTimeout(() => h.remove(), 1900); }, k * 160);
}
const REACT = { // спрайт, длительность, эффекты
  pat:    { spr: 'pat',    ms: 2700, frames: true, fx: () => hearts(6) },
  tongue: { spr: 'tongue', ms: 1500, fx: () => hearts(2, true) },
  hop:    { spr: 'neutral', ms: 1200, fx: () => hearts(3) },
  shy:    { spr: 'shy',    ms: 1600, fx: () => hearts(2) },
  shake:  { spr: 'cold',   ms: 1100 },
  shiver: { spr: 'sad',    ms: 900 },
  wipe:   { spr: 'sadwipe',  ms: 2000 },
  frown:  { spr: 'sadfrown', ms: 1600 },
  down:   { spr: 'saddown',  ms: 2000 },
};
// «погладить экран»: ладонь гладит туда-сюда (pat2→pat3→pat4→pat3, ~6 кадров/с)
let patT = null;
function patAnim(el, ms) {
  const seq = ['sera_pat2','sera_pat3','sera_pat4','sera_pat3']; let k = 0; const t0 = Date.now();
  setTimeout(() => { if (!el.dataset.reacting) return; patT = setInterval(() => {
    if (!el.dataset.reacting || Date.now() - t0 > ms - 400) { clearInterval(patT); if (el.dataset.reacting) setImg(el, 'sera_pat'); return; }
    setImg(el, seq[k++ % seq.length]); }, 170); }, 320);
}
// v8: покадровые эмоции Серы — [кадр, мс]; после последнего кадра возвращается текущая эмоция
const ANIM = {
  yawn:   [['yawn1', 380], ['yawn2', 950], ['yawn3', 650]],
  cover:  [['cover1', 350], ['cover2', 1300]],
  giggle: [['giggle1', 260], ['giggle2', 260], ['giggle1', 260], ['giggle2', 260], ['giggle1', 300]],
  huff:   [['huff1', 700], ['huff2', 1000]],
  // v10: теребит цепочку на чокере, кричит сквозь слёзы, показывает «V»
  chain:  [['chain1', 520], ['chain2', 760], ['chain1', 520], ['chain2', 900]],
  shout:  [['shout1', 420], ['shout2', 700], ['shout1', 520], ['shout2', 800]],
  vsign:  [['vsign1', 650], ['vsign2', 1000]],
};
for (const k in ANIM) REACT[k] = { seq: ANIM[k], ms: ANIM[k].reduce((a, f) => a + f[1], 0), fx: k === 'cover' ? () => hearts(2) : null };
function seqAnim(el, seq) {
  let k = 0;
  (function nx() { if (!el.dataset.reacting || k >= seq.length) return; setImg(el, 'sera_' + seq[k][0]); patT = setTimeout(nx, seq[k++][1]); })();
}
// заранее декодируем кадры, чтобы смена была мгновенной
['sera_pat','sera_pat2','sera_pat3','sera_pat4'].concat(...Object.values(ANIM).map(a => a.map(f => 'sera_' + f[0])))
  .forEach(k => { if (A.sprites[k]) { const i = new Image(); i.src = A.sprites[k]; i.decode && i.decode().catch(() => {}); } });
function react(kind) {
  if (isCrying() && CRY_MAP[kind]) kind = CRY_MAP[kind];
  const el = seraEl(), R = REACT[kind]; if (!el || !R || !st.chars.sera) return;
  leanOn = false; el.classList.remove('react-lean', 'react-wipeloop');
  clearTimeout(reactT); el.className = el.className.replace(/\breact-\S+/g, '').trim();
  void el.offsetWidth; el.dataset.reacting = 1;
  clearInterval(patT); clearTimeout(patT);
  if (R.seq) seqAnim(el, R.seq); else setImg(el, 'sera_' + R.spr);
  el.classList.add('react-' + (kind === 'shy' ? 'hop' : kind)); R.fx && R.fx();
  if (R.frames) patAnim(el, R.ms);
  reactT = setTimeout(() => { clearInterval(patT); clearTimeout(patT); el.classList.remove('react-' + (kind === 'shy' ? 'hop' : kind)); delete el.dataset.reacting; if (st.chars.sera) setImg(el, 'sera_' + st.chars.sera.expr); }, R.ms);
}
// ── Сохранения ──
function snapshot(nlog = 0) { if (st.mode === 'map' && st.map && PixelMap.isOpen()) st.map.pos = PixelMap.pos(); return JSON.stringify({ st: { ...st, i: st.mode === 'map' ? st.i : Math.max(0, st.i - 1) }, date: new Date().toLocaleString('ru-RU'), log: nlog ? log.slice(-nlog) : undefined }); }
function saveSlot(n, silent) {
  // журнал (с точками отката) сохраняется вместе со слотом; при нехватке места — короче
  for (const nl of n === 'auto' ? [500, 200, 50, 0] : [200, 60, 0]) { try { localStorage.setItem('serap_save_' + n, snapshot(nl)); break; } catch (e) { if (!nl) console.warn('save failed', e); } }
  if (!silent) toast('Сохранено'); }
function loadSlot(n) {
  const raw = localStorage.getItem('serap_save_' + n); if (!raw) return;
  const d = JSON.parse(raw); log.length = 0; if (d.log) d.log.forEach(e => log.push(e)); restoreState(d.st);
}
function restoreState(s) {
  auto = skip = false; syncBtns(); clearTimeout(tTimer); typing = waiting = false; if (cutKill) cutKill();
  Object.assign(st, { notes: [], mode: '', map: null }, s); delete st.nc; closeModal(); PixelMap.close(); $('#card').classList.add('hidden'); $('#cut').classList.add('hidden'); $('#side').classList.add('hidden');
  $('#chars').innerHTML = ''; const chars = st.chars; st.chars = {};
  if (st.bg) setBg(st.bg, true);
  Object.entries(chars).forEach(([w, c]) => showChar(w, c.expr, c.pos));
  setRain(st.rain); applyRain(); if (st.music) Sound.music(st.music);
  $('#chapter').textContent = st.chapter || '';
  ['#ending','#choices','#title','#nameScreen'].forEach(s => $(s).classList.add('hidden')); inChoice = false;
  begin();
}
function slotsUI(mode) {
  let h = `<h2>${mode === 'save' ? 'Сохранить' : 'Загрузить'}</h2><div class="slots">`;
  for (let k = 1; k <= 6; k++) { const r = localStorage.getItem('serap_save_' + k); const d = r && JSON.parse(r);
    h += `<button data-slot="${k}">Слот ${k}<br><small>${d ? d.date + '<br>' + (d.st.chapter || '') : '— пусто —'}</small></button>`; }
  h += '</div><button id="mClose">Закрыть</button>'; openModal(h);
  document.querySelectorAll('[data-slot]').forEach(b => b.onclick = () => { const k = b.dataset.slot;
    if (mode === 'save') { saveSlot(k); slotsUI('save'); } else if (localStorage.getItem('serap_save_' + k)) loadSlot(k); });
}

// ── Модальные окна ──
function openModal(html) { $('#modalBody').innerHTML = html; $('#modal').classList.remove('hidden'); const c = $('#mClose'); if (c) c.onclick = closeModal; }
function closeModal() { $('#modal').classList.add('hidden'); }
function settings() {
  openModal(`<h2>Настройки</h2>
  <label>Скорость текста <input type="range" id="sSpeed" min="5" max="120" value="${opts.speed}"></label>
  <label>Громкость музыки <input type="range" id="sMusic" min="0" max="1" step=".05" value="${opts.music}"></label>
  <label>Пауза в авто-режиме <input type="range" id="sAuto" min="600" max="4000" step="100" value="${opts.autoDelay}"></label>
  <button id="mClose">Готово</button>`);
  $('#sSpeed').oninput = e => { opts.speed = +e.target.value; persist(); };
  $('#sMusic').oninput = e => { opts.music = +e.target.value; Sound.setVol('music', opts.music); persist(); };
  $('#sAuto').oninput = e => { opts.autoDelay = +e.target.value; persist(); };
}
const persist = () => localStorage.setItem('serap_opts', JSON.stringify(opts));
function endingsList() {
  const got = JSON.parse(localStorage.getItem('serap_endings') || '{}');
  openModal(`<h2>Концовки</h2><ul class="endlist">${Object.entries(ENDINGS).map(([k, e]) => `<li>${got[k] ? '✝ ' + e.title : '??? — не открыта'}</li>`).join('')}</ul><button id="mClose">Закрыть</button>`);
}
function showLog() {
  let ch = null, h = '';
  log.forEach((l, k) => {
    const c = l.s && l.s.chapter; if (c && c !== ch) { ch = c; h += `<h3 class="lch">${c}</h3>`; }
    const cls = [l.th ? 'th' : '', l.ch ? 'chs' : '', l.s ? 'rb' : ''].filter(Boolean).join(' ');
    h += `<div${cls ? ` class="${cls}"` : ''}${l.s ? ` data-k="${k}" title="Вернуться к этому моменту"` : ''}>${l.n ? `<b>${l.n}:</b> ` : ''}${l.t}${l.s ? '<i class="rbi">↺</i>' : ''}</div>`;
  });
  openModal(`<h2>Журнал</h2><p class="nsub">Нажми на реплику или выбор, чтобы вернуться к этому моменту и перепройти его</p><div class="log">${h || '<div>Пока пусто.</div>'}</div><button id="mClose">Закрыть</button>`);
  const lg = document.querySelector('.log'); lg.scrollTop = lg.scrollHeight;
  lg.querySelectorAll('[data-k]').forEach(d => d.onclick = () => confirmRollback(+d.dataset.k));
}
function confirmRollback(k) {
  const l = log[k]; if (!l || !l.s) return;
  openModal(`<h2>Вернуться?</h2><p class="rbq">${l.n ? `<b>${l.n}:</b> ` : ''}${l.t}</p><p class="nsub">Игра продолжится с этого места. Всё, что было после, можно будет пройти заново — в том числе выбрать другой вариант.</p><div class="menu"><button id="rbYes">Вернуться сюда</button><button id="rbNo">Назад к журналу</button></div>`);
  $('#rbYes').onclick = () => rollback(k); $('#rbNo').onclick = showLog;
}
function rollback(k) {
  const l = log[k]; if (!l || !l.s) return;
  if (breathOn) { toast('Сначала закончи дыхание'); return; }
  const notes = (st.notes || []).slice(0, l.s.nc || 0);
  log.length = k; // эта реплика снова попадёт в журнал, когда будет показана
  ['#ending','#choices','#title','#nameScreen'].forEach(s => $(s).classList.add('hidden')); inChoice = false;
  restoreState(Object.assign({}, l.s, { notes }));
  toast('↺ Возврат в прошлое');
}
function gameMenu() {
  openModal(`<h2>Меню</h2><div class="menu"><button id="mResume">Продолжить</button><button id="mSet">Настройки</button><button id="mTitle">В главное меню</button></div>`);
  $('#mResume').onclick = closeModal; $('#mSet').onclick = settings; $('#mTitle').onclick = () => { closeModal(); toTitle(); };
}

// ── Управление ──
function syncBtns() { document.querySelector('[data-a=auto]').classList.toggle('on', auto); document.querySelector('[data-a=skip]').classList.toggle('on', skip); }
$('#controls').onclick = e => {
  e.stopPropagation(); const a = e.target.dataset.a; if (!a) return;
  if (a === 'auto') { auto = !auto; skip = false; syncBtns(); if (auto && waiting) advance(); }
  if (a === 'skip') { skip = !skip; auto = false; syncBtns(); if (skip && (waiting || typing)) advance(); }
  if (a === 'notes') showNotes(); if (a === 'log') showLog(); if (a === 'save') slotsUI('save'); if (a === 'load') slotsUI('load'); if (a === 'menu') gameMenu();
};
$('#textbox').onclick = () => { if (skip) { skip = false; syncBtns(); } advance(); };
$('#chars').parentElement.addEventListener('click', e => { if (e.target.closest('#textbox,#choices,.screen,#controls')) return; if (!$('#textbox').classList.contains('hidden')) advance(); });
addEventListener('keydown', e => {
  if (!$('#modal').classList.contains('hidden')) { if (e.key === 'Escape') closeModal(); return; }
  if (st.mode === 'map' && PixelMap.isOpen() && $('#title').classList.contains('hidden')) { if (e.key === 'Escape') gameMenu(); return; }
  if ($('#textbox').classList.contains('hidden') || !$('#title').classList.contains('hidden')) return;
  if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); advance(); }
  if (e.key === 'Control') { skip = true; syncBtns(); advance(); }
  if (e.key === 'Escape') gameMenu();
  if (e.key.toLowerCase() === 'n' || e.key.toLowerCase() === 'т') showNotes();
  if (e.key.toLowerCase() === 'a') document.querySelector('[data-a=auto]').click();
});
addEventListener('keyup', e => { if (e.key === 'Control') { skip = false; syncBtns(); } });
document.addEventListener('click', () => Sound.init(), { once: true });

// ── Карточка главы ──
let cardT = null;
function showCard([big, small]) {
  const c = $('#card'); c.querySelector('.cBig').textContent = big; c.querySelector('.cSmall').textContent = small || '';
  $('#textbox').classList.add('hidden'); $('#side').classList.add('hidden'); c.classList.remove('hidden', 'out'); void c.offsetWidth; c.classList.add('in');
  const done = () => { clearTimeout(cardT); c.onclick = null; c.classList.add('out'); setTimeout(() => { c.classList.add('hidden'); c.classList.remove('in', 'out'); $('#textbox').classList.remove('hidden'); run(); }, 600); };
  c.onclick = done; cardT = setTimeout(done, skip ? 300 : 3000);
}

// ── Пиксельная прогулка ──
function openMap() {
  hideChar('all'); $('#textbox').classList.add('hidden'); $('#side').classList.add('hidden'); $('#choices').classList.add('hidden');
  const m = st.map; const left = m.visits - m.done.length;
  if (m.bg) setBg(m.bg); Sound.loc('map'); if (m.music) { st.music = m.music; Sound.music(m.music); }
  setRain(false); Sound.rain(true); // в пиксельном режиме дождь рисует сам PixelMap
  $('#chapter').textContent = st.chapter || '';
  const task = m.items ? `${m.task} · ${(m.got || []).length}/${m.items.length}` : m.timer != null ? m.task : `${m.task || 'Куда пойти?'} · осталось: ${left}`;
  PixelMap.open({ title: m.title, task, time: m.time, spots: m.spots, done: m.done, pos: m.pos, follow: m.follow, home: m.home, quiet: !!m.scenes && !m.npcsOn,
    world: m.world, start: m.start, items: m.items, got: m.got || (m.got = []), itemLines: m.itemLines, itemLabel: m.itemLabel, itemsDone: m.itemsDone, info: m.info, extra: m.extra, npcs: m.npcs,
    lines: m.lines, seraBench: m.seraBench, noSera: m.noSera, timer: m.timer, tleft: m.tleft,
    onItem: n => { $('#pixTask').textContent = `${m.task} · ${n}/${m.items.length}`; saveSlot('auto', true); }, onTick: t => { m.tleft = t; } }, id => {
    m.pos = PixelMap.pos();
    if (id === '__items' || id === '__late') { const a = id === '__late' ? (m.late || m.after) : m.after; st.map = null; st.mode = ''; $('#textbox').classList.remove('hidden'); jump(a); run(); return; }
    m.done.push(id);
    if (m.scenes && m.scenes[id]) { st.mode = ''; $('#textbox').classList.remove('hidden'); jump(m.scenes[id]); run(); return; } const n = (st.flags['v_' + id] || 0) + 1; st.flags['v_' + id] = n;
    st.mode = ''; $('#textbox').classList.remove('hidden'); jump(STORY[id + '_' + n] ? id + '_' + n : id + '_3'); run();
  });
  saveSlot('auto', true);
}
window.__pix = { enter: id => PixelMap.enter(id), state: () => st, react: k => react(k) };
$('#pixNotes').onclick = e => { e.stopPropagation(); showNotes(); };
$('#pixMenu').onclick = e => { e.stopPropagation(); gameMenu(); };
$('#pixSave').onclick = e => { e.stopPropagation(); slotsUI('save'); };
})();
