// Движок визуальной новеллы
(() => {
const $ = s => document.querySelector(s);
const A = window.ASSETS || { bg:{}, sprites:{} };
const st = { scene:'start', i:0, feel:50, press:0, flags:{}, name:'Кирилл', bg:null, chars:{}, music:null, rain:false, chapter:'' };
let typing = false, full = '', tIdx = 0, tTimer = null, waiting = false, auto = false, skip = false, inChoice = false;
const log = [];
const opts = Object.assign({ speed: 28, music: 0.6, autoDelay: 1800 }, JSON.parse(localStorage.getItem('serap_opts') || '{}'));
Sound.setVol('music', opts.music);

// ── Заставка ──
A.title = A.title || {}; A.ui = A.ui || {};
document.documentElement.style.setProperty('--vine', `url(${A.ui.vine})`);
$('#logoImg').src = A.ui.logo;
document.querySelectorAll('#tAnim .tf').forEach(i => i.src = A.title[i.dataset.f]);
// ветки цветов на кнопках
function vineify(btn) { ['l','r'].forEach(s => { const v = document.createElement('span'); v.className = 'vine ' + s; btn.appendChild(v); }); }
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
  const n = $('#nameInput').value.trim(); Object.assign(st, { scene:'start', i:0, feel:50, press:0, flags:{}, name: n || 'Кирилл', bg:null, chars:{}, music:null, rain:false });
  log.length = 0; $('#nameScreen').classList.add('hidden'); begin();
};
$('#nameInput').onkeydown = e => { if (e.key === 'Enter') $('#nameOk').click(); };
$('#btnContinue').onclick = () => { Sound.init(); loadSlot('auto'); };
$('#btnSettings').onclick = settings;
$('#btnEndings').onclick = endingsList;
$('#endBack').onclick = toTitle;

function begin() { titleAnim(false); $('#title').classList.add('hidden'); $('#textbox').classList.remove('hidden'); $('#hud').classList.remove('hidden'); updateTrust(); run(); }
function toTitle() {
  auto = skip = false; syncBtns(); clearTimeout(tTimer);
  ['#ending','#modal','#textbox','#hud','#choices'].forEach(s => $(s).classList.add('hidden'));
  $('#chars').innerHTML = ''; Sound.music('calm'); Sound.rain(false); setRain(false);
  $('#title').classList.remove('hidden'); $('#side').classList.add('hidden'); titleAnim(true); refreshContinue();
}

// ── Фон и персонажи ──
let bgFront = $('#bg'), bgBack = $('#bg2');
function setBg(k, instant) {
  st.bg = k; const url = `url(${A.bg[k]})`;
  if (instant) { bgFront.style.backgroundImage = url; bgFront.style.opacity = 1; bgBack.style.opacity = 0; return; }
  bgBack.style.backgroundImage = url; bgBack.style.opacity = 1; bgFront.style.opacity = 0;
  [bgFront, bgBack] = [bgBack, bgFront];
}
const POS = { left:'28%', center:'50%', right:'72%' };
function showChar(who, expr, pos) {
  const key = who === 'father' ? 'father' : who + '_' + expr;
  const prev = st.chars[who];
  pos = pos || (prev && prev.pos) || 'center';
  st.chars[who] = { expr, pos };
  let el = document.querySelector(`.char[data-who="${who}"]:not([data-dying])`);
  if (!el) { el = document.createElement('img'); el.className = 'char fade breath'; el.dataset.who = who; $('#chars').appendChild(el); el.src = A.sprites[key]; el.style.left = POS[pos]; requestAnimationFrame(() => requestAnimationFrame(() => el.classList.remove('fade'))); }
  else { if (el.src !== A.sprites[key]) el.src = A.sprites[key]; el.style.left = POS[pos]; el.classList.remove('fade'); }
}
function hideChar(who) {
  const list = who === 'all' ? Object.keys(st.chars) : [who];
  list.forEach(w => { delete st.chars[w]; const el = document.querySelector(`.char[data-who="${w}"]:not([data-dying])`); if (el) { el.dataset.dying = 1; el.classList.add('fade'); setTimeout(() => el.remove(), 500); } });
}
function setSpeaker(name) {
  document.querySelectorAll('.char').forEach(el => {
    const who = el.dataset.who; const active = !name || (name === 'Сера' && who === 'sera') || (name === 'Пастор' && who === 'father') || (name === 'P' && who === 'hero');
    el.style.filter = active || Object.keys(st.chars).length < 2 ? '' : 'brightness(.6) drop-shadow(0 0 14px rgba(0,0,0,.6))';
  });
}

// ── Эффекты: дождь ──
const cv = $('#fx'), cx = cv.getContext('2d'); let drops = [], raining = false;
function resize() { cv.width = cv.clientWidth; cv.height = cv.clientHeight; } addEventListener('resize', resize); resize();
function setRain(on) { raining = on; st.rain = on; if (on && !drops.length) drops = Array.from({ length: 220 }, () => ({ x: Math.random(), y: Math.random(), s: .6 + Math.random() * .8 })); }
(function frame() {
  cx.clearRect(0, 0, cv.width, cv.height);
  if (raining) { cx.strokeStyle = 'rgba(190,200,230,.35)'; cx.lineWidth = 1; cx.beginPath();
    drops.forEach(d => { const x = d.x * cv.width, y = d.y * cv.height; cx.moveTo(x, y); cx.lineTo(x - 3 * d.s, y + 16 * d.s); d.y += .018 * d.s; d.x -= .002 * d.s; if (d.y > 1) { d.y = -.05; d.x = Math.random() * 1.1; } });
    cx.stroke(); }
  requestAnimationFrame(frame);
})();
function fx(kind) { const g = $('#game'); g.classList.remove(kind); void g.offsetWidth; g.classList.add(kind); setTimeout(() => g.classList.remove(kind), 700); }

// ── Доверие ──
function updateTrust() { $('#trust .fill').style.width = Math.max(0, Math.min(100, st.feel)) + '%'; }
function changeFeel(d) {
  st.feel = Math.max(0, Math.min(100, st.feel + d)); updateTrust();
  if (d >= 5) toast('Сера запомнит это ♡'); else if (d <= -5) toast('По доверию пошла трещина…');
}
let toastT; function toast(t) { const el = $('#toast'); el.textContent = t; el.classList.add('show'); clearTimeout(toastT); toastT = setTimeout(() => el.classList.remove('show'), 1800); }

// ── Исполнение сценария ──
const fmt = t => t.replace(/\{P\}/g, st.name);
function run() {
  while (true) {
    const scene = STORY[st.scene]; const c = scene[st.i];
    if (!c) return;
    st.i++;
    if (Array.isArray(c)) { say(c[0], c[1], c[2]); return; }
    if (c.chapter) { st.chapter = c.chapter; $('#chapter').textContent = c.chapter; }
    if (c.bg) { setBg(c.bg); document.querySelectorAll('#bg,#bg2').forEach(x => x.classList.remove('zoom')); }
    if (c.zoom) bgFront.classList.add('zoom');
    if (c.music) { st.music = c.music; Sound.music(c.music); }
    if ('rain' in c) { setRain(c.rain); Sound.rain(c.rain); }
    if (c.show) showChar(c.who || (c.show === 'father' ? 'father' : 'sera'), c.show, c.pos);
    if (c.hide) hideChar(c.hide);
    if (c.fx && !skip) fx(c.fx);
    if (c.react && !skip) react(c.react);
    if (typeof c.feel === 'number' && !c.choice) changeFeel(c.feel);
    if (c.set && !c.choice) Object.assign(st.flags, c.set);
    if (c.add && !c.choice) st.press += c.add.press || 0;
    if (c.when) { if (c.when(st)) { jump(c.go); continue; } else continue; }
    if (c.go) { jump(c.go); continue; }
    if (c.choice) { choose(c.choice); return; }
    if (c.ending) { jump(pickEnding(st)); continue; }
    if (c.final) { finish(c.final); return; }
  }
}
function jump(l) { st.scene = l; st.i = 0; }

function say(name, text, expr) {
  const nb = $('#namebox'), tx = $('#text');
  const disp = name === 'P' ? st.name : name;
  nb.textContent = disp; nb.className = name === 'P' ? 'gg' : name === 'Пастор' ? 'father' : '';
  tx.className = name ? '' : 'narr';
  setSpeaker(name === 'P' && !st.chars.hero ? null : name);
  const side = $('#side');
  if (name === 'P' && !st.chars.hero) { const src = A.sprites['hero_' + (expr || 'neutral')]; const im = side.querySelector('img');
    if (side.classList.contains('hidden') || im.getAttribute('src') !== src) { im.src = src; im.style.animation = 'none'; void im.offsetWidth; im.style.animation = ''; }
    side.classList.remove('hidden'); } else side.classList.add('hidden');
  full = fmt(text); tIdx = 0; typing = true; waiting = false; $('#next').classList.remove('show');
  log.push({ n: disp, t: full }); if (log.length > 200) log.shift();
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
  inChoice = true; skip = false; syncBtns(); saveSlot('auto', true);
  const box = $('#choices'); box.innerHTML = ''; box.classList.remove('hidden');
  list.forEach(o => {
    const b = document.createElement('button'); b.className = 'vbtn'; b.innerHTML = fmt(o.t) + (o.hint ? `<span class="hint">${o.hint}</span>` : ''); vineify(b);
    b.onmouseenter = () => hoverLean(true); b.onmouseleave = () => hoverLean(false);
    b.onclick = e => {
      e.stopPropagation(); box.classList.add('hidden'); inChoice = false; hoverLean(false);
      const rk = o.react || (o.feel >= 10 ? 'pat' : o.feel >= 5 ? 'hop' : o.feel <= -12 ? 'shake' : o.feel < 0 ? 'shiver' : null);
      if (rk) react(rk);
      log.push({ n: '→', t: fmt(o.t) });
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
    $('#endTitle').textContent = ENDINGS[kind].title; $('#endText').textContent = ENDINGS[kind].text + `\n\nДоверие Серы: ${st.feel}/100`;
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
  if (on && !leanOn) { leanOn = true; el.src = A.sprites[crying ? 'sera_sadwipe' : 'sera_lean']; el.classList.add(crying ? 'react-wipeloop' : 'react-lean'); }
  else if (!on && leanOn) { leanOn = false; el.classList.remove('react-lean', 'react-wipeloop'); el.src = A.sprites['sera_' + st.chars.sera.expr]; }
}
function hearts(n, dark) {
  for (let k = 0; k < n; k++) setTimeout(() => { const h = document.createElement('span'); h.className = 'heart' + (dark ? ' dark' : ''); h.textContent = dark ? '✝' : '♡';
    h.style.left = (38 + Math.random() * 24) + '%'; h.style.top = (25 + Math.random() * 25) + '%'; $('#fxl').appendChild(h); setTimeout(() => h.remove(), 1900); }, k * 160);
}
const REACT = { // спрайт, длительность, эффекты
  pat:    { spr: 'pat',    ms: 2400, fx: () => { hearts(6); const g = $('#game'); g.classList.add('patted'); setTimeout(() => g.classList.remove('patted'), 2300); toast('Сера гладит тебя по голове ♡'); } },
  tongue: { spr: 'tongue', ms: 1500, fx: () => hearts(2, true) },
  hop:    { spr: 'neutral', ms: 1200, fx: () => hearts(3) },
  shy:    { spr: 'shy',    ms: 1600, fx: () => hearts(2) },
  shake:  { spr: 'cold',   ms: 1100 },
  shiver: { spr: 'sad',    ms: 900 },
  wipe:   { spr: 'sadwipe',  ms: 2000 },
  frown:  { spr: 'sadfrown', ms: 1600 },
  down:   { spr: 'saddown',  ms: 2000 },
};
function react(kind) {
  if (isCrying() && CRY_MAP[kind]) kind = CRY_MAP[kind];
  const el = seraEl(), R = REACT[kind]; if (!el || !R || !st.chars.sera) return;
  leanOn = false; el.classList.remove('react-lean', 'react-wipeloop');
  clearTimeout(reactT); el.className = el.className.replace(/\breact-\S+/g, '').trim();
  void el.offsetWidth; el.dataset.reacting = 1;
  el.src = A.sprites['sera_' + R.spr]; el.classList.add('react-' + (kind === 'shy' ? 'hop' : kind)); R.fx && R.fx();
  reactT = setTimeout(() => { el.classList.remove('react-' + (kind === 'shy' ? 'hop' : kind)); delete el.dataset.reacting; if (st.chars.sera) el.src = A.sprites['sera_' + st.chars.sera.expr]; }, R.ms);
}
// клик по голове Серы — она реагирует
const pokes = ['tongue', 'shy', 'pat', 'tongue', 'hop'];
$('#chars').addEventListener('click', e => {
  const el = e.target.closest('.char[data-who="sera"]'); if (!el) return;
  const r = el.getBoundingClientRect(); if (e.clientY - r.top < r.height * .3) { e.stopPropagation(); const list = isCrying() ? ['wipe', 'frown', 'down'] : pokes; react(list[Math.floor(Math.random() * list.length)]); }
});

// ── Сохранения ──
function snapshot() { return JSON.stringify({ st: { ...st, i: Math.max(0, st.i - 1) }, date: new Date().toLocaleString('ru-RU') }); }
function saveSlot(n, silent) { localStorage.setItem('serap_save_' + n, snapshot()); if (!silent) toast('Сохранено'); }
function loadSlot(n) {
  const raw = localStorage.getItem('serap_save_' + n); if (!raw) return;
  const d = JSON.parse(raw); Object.assign(st, d.st); closeModal();
  $('#chars').innerHTML = ''; const chars = st.chars; st.chars = {};
  if (st.bg) setBg(st.bg, true);
  Object.entries(chars).forEach(([w, c]) => showChar(w, c.expr, c.pos));
  setRain(st.rain); Sound.rain(st.rain); if (st.music) Sound.music(st.music);
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
  openModal(`<h2>Журнал</h2><div class="log">${log.map(l => `<div>${l.n ? `<b>${l.n}:</b> ` : ''}${l.t}</div>`).join('')}</div><button id="mClose">Закрыть</button>`);
  const lg = document.querySelector('.log'); lg.scrollTop = lg.scrollHeight;
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
  if (a === 'log') showLog(); if (a === 'save') slotsUI('save'); if (a === 'load') slotsUI('load'); if (a === 'menu') gameMenu();
};
$('#textbox').onclick = () => { if (skip) { skip = false; syncBtns(); } advance(); };
$('#chars').parentElement.addEventListener('click', e => { if (e.target.closest('#textbox,#choices,.screen,#controls')) return; if (!$('#textbox').classList.contains('hidden')) advance(); });
addEventListener('keydown', e => {
  if (!$('#modal').classList.contains('hidden')) { if (e.key === 'Escape') closeModal(); return; }
  if ($('#textbox').classList.contains('hidden') || !$('#title').classList.contains('hidden')) return;
  if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); advance(); }
  if (e.key === 'Control') { skip = true; syncBtns(); advance(); }
  if (e.key === 'Escape') gameMenu();
  if (e.key.toLowerCase() === 'a') document.querySelector('[data-a=auto]').click();
});
addEventListener('keyup', e => { if (e.key === 'Control') { skip = false; syncBtns(); } });
document.addEventListener('click', () => Sound.init(), { once: true });
})();
