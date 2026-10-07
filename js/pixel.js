// Пиксельный режим: прогулка по двору (canvas 320×180, масштаб без сглаживания)
window.PixelMap = (() => {
const W = 320, H = 180;
let cv, cx, bgC, running = false, cfg = null, onEnter = null, raf = 0, last = 0;
const keys = {};
const hero = { x: 60, y: 120, dir: 'down', t: 0, moving: false, target: null, autoEnter: null };
let cat = { x: 120, y: 150, vx: 8, t: 0 };
let msgT = 0, msgText = '';

// ── Спрайт героя: чёрные лохматые волосы, бледная кожа, чёрная футболка, серые джоггеры ──
const PAL = { K:'#15131a', k:'#2b2733', S:'#f4e2d8', s:'#dcc0b2', E:'#2a2030', T:'#1d1c24', t:'#34313f', J:'#8d8d98', j:'#6b6b76', B:'#0e0e12', W:'#d9d9de', R:'#b8324e' };
const HEAD_D = ['..KkKKkK..','.KKKKKKKK.','KKKKKKKKKK','KKSKKSKKKk','.KSSSSSSK.','.KSESSESK.','..SSsSSS..','...SSSS...'];
const HEAD_U = ['..KkKKkK..','.KKKKKKKK.','KKKKKKKKKK','KKKKKKKKKK','.KKkKKKKK.','.KKKKKKKK.','..KSSSSK..','...SSSS...'];
const HEAD_S = ['..KkKKkK..','.KKKKKKKK.','KKKKKKKKK.','KKKKKSKSK.','.KKSSSSSS.','.KKSSSESS.','..KSSSSs..','...SSSS...'];
const BODY_F = ['.TTTTTTTT.','TTtTTTTtTT','STTTTTTTTS','STTTTTTTTS','R.TTTTTT.s'];
const BODY_S = ['..TTTTTT..','.TTTTTTTT.','.TTtTTTTT.','..TSTTTT..','..TRTTT...'];
const LEGS_F = [['..JJJJJJ..','..JJ..JJ..','..jJ..Jj..','..BB..BB..'], ['..JJJJJJ..','..JJ..JJ..','.JJ....JJ.','.BB....BB.']];
const LEGS_S = [['..JJJJJ...','..JJ.JJ...','..jJ.Jj...','..BB.BB...'], ['..JJJJJ...','.JJ...JJ..','.jJ...jJ..','.BB....BB.']];
function frame(dir, f) {
  const head = dir === 'up' ? HEAD_U : dir === 'down' ? HEAD_D : HEAD_S;
  const body = dir === 'left' || dir === 'right' ? BODY_S : BODY_F;
  const legs = (dir === 'left' || dir === 'right' ? LEGS_S : LEGS_F)[f];
  return head.concat(body, legs);
}
function drawRows(rows, x, y, flip) {
  rows.forEach((r, j) => { for (let i = 0; i < r.length; i++) { const c = r[flip ? r.length - 1 - i : i]; if (c !== '.') { cx.fillStyle = PAL[c]; cx.fillRect(x + i, y + j, 1, 1); } } });
}

// ── Фон двора (рисуется один раз) ──
function rnd(seed) { let s = seed; return () => (s = (s * 16807) % 2147483647) / 2147483647; }
function paintBg(time) {
  bgC = document.createElement('canvas'); bgC.width = W; bgC.height = H; const g = bgC.getContext('2d'); const R = rnd(7);
  const sky = { day: ['#9aa3b5', '#d8b48f'], eve: ['#3a2f5c', '#c7728a'], night: ['#0d0b1d', '#2c2347'] }[time] || ['#9aa3b5', '#d8b48f'];
  const gr = g.createLinearGradient(0, 0, 0, 70); gr.addColorStop(0, sky[0]); gr.addColorStop(1, sky[1]); g.fillStyle = gr; g.fillRect(0, 0, W, 100);
  const dark = time !== 'day'; const lit = dark ? .55 : .12;
  // дальние трубы ТЭЦ и панельки
  g.fillStyle = dark ? '#2a2540' : '#8c8e9e'; g.fillRect(150, 6, 5, 40); g.fillRect(162, 10, 5, 36);
  g.fillStyle = dark ? '#5a3348' : '#b8656b'; g.fillRect(150, 10, 5, 3); g.fillRect(162, 14, 5, 3);
  g.fillStyle = dark ? '#211d33' : '#7d8091'; for (let x = 0; x < W; x += 34) g.fillRect(x, 30 + (x % 3) * 3, 30, 60);
  const win = (x, y, w, h) => { g.fillStyle = R() < lit ? (R() < .5 ? '#ffd27a' : '#ffb35c') : (dark ? '#262236' : '#5d6372'); g.fillRect(x, y, w, h); };
  // фасады
  function panel(x0, w, top, col) { g.fillStyle = col; g.fillRect(x0, top, w, 96 - top); g.fillStyle = 'rgba(0,0,0,.18)'; for (let y = top + 11; y < 96; y += 11) g.fillRect(x0, y, w, 1);
    for (let y = top + 3; y < 86; y += 11) for (let x = x0 + 4; x < x0 + w - 6; x += 10) win(x, y, 5, 6); }
  panel(0, 122, 14, dark ? '#4a4658' : '#a9a7a2');            // дом героя и Серы
  panel(124, 78, 22, dark ? '#4c4256' : '#b3a99c');           // дом с кафе
  g.fillStyle = dark ? '#3b3f3a' : '#8f978c'; g.fillRect(204, 62, 62, 34); // павильон магазина
  g.fillStyle = dark ? '#53403d' : '#b98d78'; g.fillRect(268, 26, 52, 70); // колледж (кирпич)
  g.fillStyle = 'rgba(0,0,0,.2)'; for (let y = 30; y < 96; y += 4) g.fillRect(268, y, 52, 1);
  for (let y = 32; y < 80; y += 14) for (let x = 273; x < 316; x += 11) { g.fillStyle = '#e7dccb'; g.fillRect(x - 1, y - 1, 7, 10); win(x, y, 5, 8); }
  // подъезд Серы
  g.fillStyle = dark ? '#2d2a35' : '#6d6a70'; g.fillRect(52, 70, 22, 3); g.fillStyle = '#3d2f2a'; g.fillRect(57, 76, 12, 20); g.fillStyle = '#8f7a5a'; g.fillRect(66, 85, 1, 3);
  g.fillStyle = '#ffd98a'; g.fillRect(62, 73, 3, 2);
  // кафе «Луна»
  g.fillStyle = '#2b1b18'; g.fillRect(132, 70, 62, 26); g.fillStyle = dark ? '#ffbe6e' : '#e8b077'; g.fillRect(136, 74, 20, 14); g.fillRect(174, 74, 16, 14);
  g.fillStyle = '#5a3a2a'; g.fillRect(159, 75, 11, 21); g.fillStyle = '#f7e3a1'; g.beginPath(); g.arc(165, 66, 4, 0, 7); g.fill(); g.fillStyle = dark ? '#4c4256' : '#b3a99c'; g.beginPath(); g.arc(167, 65, 3.4, 0, 7); g.fill();
  // магазин 24
  g.fillStyle = '#1f7a45'; g.fillRect(206, 56, 58, 8); g.fillStyle = '#e9fff0'; g.font = 'bold 7px monospace'; g.fillText('24 ЧАСА', 214, 63);
  g.fillStyle = dark ? '#d9f7ff' : '#bfe0e8'; g.fillRect(208, 68, 18, 20); g.fillRect(244, 68, 18, 20); g.fillStyle = '#5b6a6e'; g.fillRect(229, 70, 12, 26);
  // колледж: крыльцо и вывеска
  g.fillStyle = '#e7dccb'; g.fillRect(282, 72, 24, 3); g.fillRect(284, 75, 2, 21); g.fillRect(302, 75, 2, 21); g.fillStyle = '#4a2f26'; g.fillRect(288, 78, 12, 18);

  // тротуар, асфальт, газоны
  g.fillStyle = dark ? '#5d5a63' : '#a5a29c'; g.fillRect(0, 96, W, 9); g.fillStyle = 'rgba(0,0,0,.15)'; for (let x = 0; x < W; x += 12) g.fillRect(x, 96, 1, 9);
  g.fillStyle = dark ? '#33313b' : '#6f6d72'; g.fillRect(0, 105, W, 75);
  for (let k = 0; k < 140; k++) { g.fillStyle = R() < .5 ? 'rgba(255,255,255,.05)' : 'rgba(0,0,0,.12)'; g.fillRect(R() * W | 0, 105 + R() * 75 | 0, 2, 1); }
  // лужи
  [[150, 140, 26, 5], [228, 158, 34, 6], [96, 165, 22, 4]].forEach(([x, y, w, h]) => { g.fillStyle = dark ? '#4e5a7a' : '#9fb0c4'; g.beginPath(); g.ellipse(x, y, w / 2, h / 2, 0, 0, 7); g.fill(); g.fillStyle = 'rgba(255,255,255,.25)'; g.fillRect(x - w / 4, y - 1, w / 3, 1); });
  // площадка: качели
  g.fillStyle = '#7b2d2d'; g.fillRect(250, 116, 2, 22); g.fillRect(276, 116, 2, 22); g.fillRect(250, 116, 28, 2); g.fillStyle = '#999'; g.fillRect(259, 118, 1, 12); g.fillRect(267, 118, 1, 12); g.fillStyle = '#5a3a1f'; g.fillRect(257, 130, 12, 2);
  // лавочка у подъезда
  g.fillStyle = '#2f6b3e'; g.fillRect(18, 106, 30, 3); g.fillRect(18, 110, 30, 2); g.fillStyle = '#222'; g.fillRect(20, 112, 2, 5); g.fillRect(44, 112, 2, 5);
  // фонари
  [[100, 'L'], [200, 'L'], [300, 'L']].forEach(([x]) => { g.fillStyle = '#2a2a30'; g.fillRect(x, 70, 2, 35); g.fillRect(x - 3, 70, 8, 2); g.fillStyle = dark ? '#ffe2a0' : '#ddd'; g.fillRect(x - 2, 72, 6, 2);
    if (dark) { const lg = g.createRadialGradient(x + 1, 100, 2, x + 1, 100, 26); lg.addColorStop(0, 'rgba(255,214,140,.35)'); lg.addColorStop(1, 'rgba(255,214,140,0)'); g.fillStyle = lg; g.fillRect(x - 26, 74, 54, 52); } });
  return bgC;
}
function tree(x, y, dark) {
  cx.fillStyle = '#3d2a1e'; cx.fillRect(x - 1, y - 10, 3, 10);
  const cols = dark ? ['#6b5a24', '#8a7428', '#4d4320'] : ['#c79a2c', '#e0b640', '#9a7a22'];
  [[0, -16, 9], [-6, -12, 6], [6, -12, 6], [0, -22, 6]].forEach(([dx, dy, r], i) => { cx.fillStyle = cols[i % 3]; cx.beginPath(); cx.arc(x + dx, y + dy, r, 0, 7); cx.fill(); });
}
function granny(x, y) { // Баба Валя на лавочке
  const p = { h:'#efe3c8', f:'#e07a6a', c:'#7a5233', s:'#f1d9c7', d:'#6b3d4a', g:'#c9c9c9' };
  const rows = ['.hhfh.', 'hssssh', 'hsgsgh', '.ssss.', 'cccccc', 'cccccc', 'dddddd', 'dd..dd'];
  rows.forEach((r, j) => { for (let i = 0; i < 6; i++) if (r[i] !== '.') { cx.fillStyle = p[r[i]]; cx.fillRect(x + i, y + j, 1, 1); } });
}
function drawCat(dt) {
  cat.t += dt; cat.x += cat.vx * dt; if (cat.x > 200 || cat.x < 80) cat.vx *= -1;
  const x = cat.x | 0, y = cat.y, f = (cat.t * 6 | 0) % 2;
  cx.fillStyle = '#2a2a2a'; cx.fillRect(x, y, 6, 3); cx.fillRect(cat.vx > 0 ? x + 5 : x - 2, y - 2, 3, 3); cx.fillRect(cat.vx > 0 ? x - 2 : x + 6, y - 2 + f, 2, 1);
  cx.fillRect(x + 1, y + 3, 1, 1 + f); cx.fillRect(x + 4, y + 3, 1, 2 - f);
}

// ── Логика ──
const SPOTS = {
  home:    { x: 63, y: 104, label: 'Домой' },
  valya:   { x: 33, y: 120, label: 'Лавочка у подъезда' },
  cafe:    { x: 164, y: 104, label: 'Кафе «Луна»' },
  store:   { x: 235, y: 104, label: 'Магазин «24 часа»' },
  college: { x: 294, y: 104, label: 'Художественный колледж' },
};
function near() { let best = null, bd = 16; Object.entries(SPOTS).forEach(([id, s]) => { if (id !== 'home' && !cfg.spots.includes(id)) return; const d = Math.hypot(s.x - hero.x, s.y - hero.y); if (d < bd) { bd = d; best = id; } }); return best; }
function act(id) {
  if (!id) return;
  if (id === 'home') return say('Рано возвращаться. Хочется ещё куда-нибудь заглянуть.');
  if (cfg.done.includes(id)) return say('Сегодня я тут уже был.');
  stop(); onEnter && onEnter(id);
}
function say(t) { msgText = t; msgT = 2.4; }
function update(dt) {
  let dx = 0, dy = 0;
  if (keys.ArrowLeft || keys.a) dx--; if (keys.ArrowRight || keys.d) dx++; if (keys.ArrowUp || keys.w) dy--; if (keys.ArrowDown || keys.s) dy++;
  if (dx || dy) { hero.target = null; hero.autoEnter = null; }
  else if (hero.target) { const vx = hero.target.x - hero.x, vy = hero.target.y - hero.y, d = Math.hypot(vx, vy); if (d < 1.5) { hero.target = null; if (hero.autoEnter) { const a = hero.autoEnter; hero.autoEnter = null; act(a); } } else { dx = vx / d; dy = vy / d; } }
  hero.moving = !!(dx || dy);
  if (hero.moving) { const l = Math.hypot(dx, dy); hero.x += dx / l * 62 * dt; hero.y += dy / l * 62 * dt; hero.t += dt;
    hero.dir = Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'right' : 'left') : (dy > 0 ? 'down' : 'up'); }
  hero.x = Math.max(6, Math.min(W - 6, hero.x)); hero.y = Math.max(102, Math.min(170, hero.y));
}
function render(dt, time) {
  cx.drawImage(bgC, 0, 0);
  const dark = cfg.time !== 'day';
  if (cfg.spots.includes('valya')) granny(30, 104);
  drawCat(dt);
  const n = near();
  // метки над точками
  Object.entries(SPOTS).forEach(([id, s]) => { if (id === 'home' || !cfg.spots.includes(id)) return; const done = cfg.done.includes(id);
    const by = s.y - 26 + Math.sin(time / 300 + s.x) * 1.5; cx.fillStyle = done ? 'rgba(160,160,170,.7)' : (n === id ? '#ffe36b' : '#ff6b9a');
    if (done) { cx.fillRect(s.x - 2, by + 3, 1, 1); cx.fillRect(s.x - 1, by + 4, 1, 1); cx.fillRect(s.x, by + 3, 1, 1); cx.fillRect(s.x + 1, by + 2, 1, 1); cx.fillRect(s.x + 2, by + 1, 1, 1); }
    else { cx.fillRect(s.x, by, 2, 5); cx.fillRect(s.x, by + 6, 2, 2); } });
  // тень + герой
  cx.fillStyle = 'rgba(0,0,0,.3)'; cx.fillRect((hero.x | 0) - 4, (hero.y | 0) - 1, 9, 2);
  const f = hero.moving ? ((hero.t * 7 | 0) % 2) : 0, bob = hero.moving && f ? -1 : 0;
  drawRows(frame(hero.dir, f), (hero.x | 0) - 5, (hero.y | 0) - 17 + bob, hero.dir === 'left');
  // деревья на переднем плане
  [[12, 178], [118, 182], [190, 180], [312, 179]].forEach(([x, y]) => tree(x, y, dark));
  if (dark) { cx.fillStyle = cfg.time === 'night' ? 'rgba(10,6,30,.35)' : 'rgba(40,10,60,.18)'; cx.fillRect(0, 0, W, H); }
  // подсказки (HTML)
  const pr = document.getElementById('pixPrompt');
  if (msgT > 0) { msgT -= dt; pr.textContent = msgText; pr.classList.add('show'); }
  else if (n) { const done = n !== 'home' && cfg.done.includes(n); pr.innerHTML = `<b>E</b> · ${SPOTS[n].label}${done ? ' <i>(уже был)</i>' : ''}`; pr.classList.add('show'); }
  else pr.classList.remove('show');
}
function loop(t) {
  if (!running) return; const dt = Math.min(.05, (t - last) / 1000 || 0); last = t;
  if (document.getElementById('modal').classList.contains('hidden')) update(dt);
  render(dt, t); raf = requestAnimationFrame(loop);
}
function kd(e) {
  if (!running || !document.getElementById('modal').classList.contains('hidden')) return;
  const k = e.key.length === 1 ? e.key.toLowerCase() : e.key;
  const map = { 'ц':'w', 'ф':'a', 'ы':'s', 'в':'d', 'у':'e' }; const kk = map[k] || k;
  if (['ArrowLeft','ArrowRight','ArrowUp','ArrowDown',' '].includes(kk)) e.preventDefault();
  if (kk === 'e' || kk === 'Enter' || kk === ' ') { act(near()); return; }
  keys[kk] = true;
}
function ku(e) { const k = e.key.length === 1 ? e.key.toLowerCase() : e.key; const map = { 'ц':'w', 'ф':'a', 'ы':'s', 'в':'d' }; keys[map[k] || k] = false; }
function click(e) {
  const r = cv.getBoundingClientRect(); const x = (e.clientX - r.left) / r.width * W, y = (e.clientY - r.top) / r.height * H;
  let hit = null; Object.entries(SPOTS).forEach(([id, s]) => { if ((id === 'home' || cfg.spots.includes(id)) && Math.abs(x - s.x) < 14 && y > s.y - 40 && y < s.y + 10) hit = id; });
  hero.target = hit ? { x: SPOTS[hit].x, y: SPOTS[hit].y + 2 } : { x, y }; hero.autoEnter = hit;
}
function open(c, cb) {
  cfg = c; onEnter = cb; cv = document.getElementById('pix'); cx = cv.getContext('2d'); cv.width = W; cv.height = H; cx.imageSmoothingEnabled = false;
  paintBg(c.time || 'day');
  if (c.pos) { hero.x = c.pos.x; hero.y = c.pos.y; } else { hero.x = 63; hero.y = 112; hero.dir = 'down'; }
  hero.target = null; hero.autoEnter = null; for (const k in keys) keys[k] = false;
  document.getElementById('pixDay').textContent = c.title || ''; document.getElementById('pixTask').textContent = c.task || '';
  const wrap = document.getElementById('pixwrap');
  if (!wrap.querySelector('.psign')) [['Подъезд №3', 63, 66], ['Кафе «Луна»', 164, 57], ['24 часа', 235, 50], ['Колледж искусств', 294, 25]].forEach(([t, x, y]) => {
    const d = document.createElement('div'); d.className = 'psign'; d.textContent = t; d.style.left = (x / W * 100) + '%'; d.style.top = (y / H * 100) + '%'; wrap.appendChild(d); });
  wrap.classList.remove('hidden');
  if (!running) { running = true; last = performance.now(); raf = requestAnimationFrame(loop); }
}
function stop() { running = false; cancelAnimationFrame(raf); if (cfg) cfg.pos = { x: hero.x, y: hero.y }; document.getElementById('pixwrap').classList.add('hidden'); }
addEventListener('keydown', kd); addEventListener('keyup', ku);
document.addEventListener('DOMContentLoaded', () => {});
setTimeout(() => { const c = document.getElementById('pix'); if (c) c.addEventListener('click', click); }, 0);
return { open, close: stop, enter: id => act(id), pos: () => ({ x: hero.x, y: hero.y }), isOpen: () => running };
})();
