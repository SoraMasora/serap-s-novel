// Запекание процедурной графики/звука исходной веб-версии в файлы для Godot (воспроизводимо, тем же кодом).
// Запуск из корня репо: NODE_PATH=/vercel/sandbox/node_modules node tools/godot/bake_web.cjs
//  pixel: js/pixel.js → godot/assets/pixel/{world}_{time}_{bg|fg|light|halo}.png, hero.png, npc_*.png, data/pixel_bake.json
//  audio: js/audio.js (WebAudio через OfflineAudioContext) → godot/assets/sfx_baked/*.wav (затем ffmpeg → .ogg)
'use strict';
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const { chromium } = require('playwright');
const ROOT = path.resolve(__dirname, '..', '..'), OUT = path.join(ROOT, 'godot');
// Пиксель-арт импортируется без потерь и без мипмапов (иначе мыло/артефакты) — задаём параметры импорта заранее
const PIXEL_IMPORT = '[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=0\nmipmaps/generate=false\n';
const save = (p, dataUrl) => { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, Buffer.from(dataUrl.split(',')[1], 'base64'));
  if (p.includes(path.join('assets', 'pixel')) && !fs.existsSync(p + '.import')) fs.writeFileSync(p + '.import', PIXEL_IMPORT); };

const BAKE_FN = `
function __bake(w, time) {
  world = w; paintBg(time); paintFg(time);
  const out = { bg: bgC.toDataURL(), fg: fgC.toDataURL(), lamps: bgC.lamps || [], puddles: bgC.puddles || [] };
  if (time !== 'day') {
    const l = document.createElement('canvas'); l.width = WW; l.height = H; const g = l.getContext('2d');
    g.fillStyle = time === 'night' ? 'rgba(6,4,22,.62)' : 'rgba(26,10,44,.38)'; g.fillRect(0, 0, WW, H);
    g.globalCompositeOperation = 'destination-out';
    const glow = (x, y, r, a) => { const gg = g.createRadialGradient(x, y, 1, x, y, r); gg.addColorStop(0, 'rgba(0,0,0,' + a + ')'); gg.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gg; g.fillRect(x - r, y - r, r * 2, r * 2); };
    out.lamps.forEach(x => { glow(x + 1, 92, 34, .9); glow(x + 1, 70, 8, 1); });
    (w === 'station' ? [[205, 80, 26], [300, 80, 16], [383, 80, 10], [470, 62, 10]] : [[97, 74, 16], [329, 84, 28], [424, 82, 30], [515, 86, 16]]).forEach(([x, y, r]) => glow(x, y, r, .85));
    out.light = l.toDataURL();
    const h = document.createElement('canvas'); h.width = WW; h.height = H; const hg = h.getContext('2d');
    out.lamps.forEach(x => { const gg = hg.createRadialGradient(x + 1, 96, 2, x + 1, 96, 30); gg.addColorStop(0, 'rgba(90,60,20,.35)'); gg.addColorStop(1, 'rgba(0,0,0,0)'); hg.fillStyle = gg; hg.fillRect(x - 30, 66, 62, 62); });
    out.halo = h.toDataURL();
  }
  return out;
}
function __bakeHero() {
  const FW = 16, FH = 32, dirs = ['down', 'up', 'left', 'right'], frames = ['w0', 'w1', 'w2', 'w3', 'idle', 'breathe', 'blink'];
  const c = document.createElement('canvas'); c.width = FW * frames.length; c.height = FH * dirs.length; const save = cx; cx = c.getContext('2d');
  dirs.forEach((d, r) => frames.forEach((f, k) => {
    hero.dir = d; hero.moving = f[0] === 'w'; hero.t = hero.moving ? (+f[1]) / 8 + 0.01 : 0;
    hero.idleT = f === 'breathe' ? 2.7 : f === 'blink' ? 3.9 : 0;
    cx.save(); cx.beginPath(); cx.rect(k * FW, r * FH, FW, FH); cx.clip(); drawHero(k * FW + 8, r * FH + 28); cx.restore();
  }));
  cx = save; return { png: c.toDataURL(), fw: FW, fh: FH, anchor: [8, 28], dirs, frames };
}
function __bakeNpc(id) {
  const n = NPC[id], w = n.r[0].length + 2, h = n.r.length + 2, c = document.createElement('canvas'); c.width = w * 2; c.height = h; const g = c.getContext('2d');
  [0, -1].forEach((bob, k) => { const ox = k * w + 1, oy = 1;
    g.fillStyle = 'rgba(0,0,0,.3)'; g.fillRect(ox - 1, oy + n.r.length - 1, n.r[0].length + 2, 2);
    n.r.forEach((r, j) => { for (let i = 0; i < r.length; i++) if (r[i] !== '.') { g.fillStyle = n.p[r[i]]; g.fillRect(ox + i, oy + j + (j < 6 ? bob : 0), 1, 1); } }); });
  return { png: c.toDataURL(), fw: w, fh: h, offset: [-1, -1] };
}
`;

async function bakePixel(page) {
  let src = fs.readFileSync(path.join(ROOT, 'js/pixel.js'), 'utf8');
  const marker = 'return { open, close: stop,';
  if (!src.includes(marker)) throw new Error('pixel.js: не найден маркер return');
  src = src.replace(marker, BAKE_FN + '\nreturn { __bake, __bakeHero, __bakeNpc, open, close: stop,');
  await page.setContent('<html><body></body></html>');
  await page.addScriptTag({ content: src });
  const meta = { worlds: {}, npcs: {} };
  for (const w of ['yard', 'station']) for (const t of ['day', 'eve', 'night']) {
    const o = await page.evaluate(([w, t]) => PixelMap.__bake(w, t), [w, t]);
    const base = path.join(OUT, 'assets', 'pixel', `${w}_${t}`);
    for (const k of ['bg', 'fg', 'light', 'halo']) if (o[k]) save(`${base}_${k}.png`, o[k]);
    meta.worlds[w] = { lamps: o.lamps, puddles: o.puddles };
  }
  const hero = await page.evaluate(() => PixelMap.__bakeHero()); save(path.join(OUT, 'assets', 'pixel', 'hero.png'), hero.png); delete hero.png; meta.hero = hero;
  for (const id of ['valya', 'timur', 'margo', 'sera', 'matvey', 'sera_sit']) {
    const n = await page.evaluate(id => PixelMap.__bakeNpc(id), id); save(path.join(OUT, 'assets', 'pixel', `npc_${id}.png`), n.png); delete n.png; meta.npcs[id] = n;
  }
  fs.writeFileSync(path.join(OUT, 'data', 'pixel_bake.json'), JSON.stringify(meta, null, 1) + '\n');
  console.log('pixel: ok');
}

// ── Звук: подменяем AudioContext на OfflineAudioContext и рендерим каждый SFX/петлю ──
const toWav = (chs, sr) => { const n = chs[0].length, nc = chs.length, b = Buffer.alloc(44 + n * nc * 2);
  b.write('RIFF', 0); b.writeUInt32LE(36 + n * nc * 2, 4); b.write('WAVEfmt ', 8); b.writeUInt32LE(16, 16); b.writeUInt16LE(1, 20); b.writeUInt16LE(nc, 22);
  b.writeUInt32LE(sr, 24); b.writeUInt32LE(sr * nc * 2, 28); b.writeUInt16LE(nc * 2, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(n * nc * 2, 40);
  for (let i = 0; i < n; i++) for (let c = 0; c < nc; c++) b.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(chs[c][i] * 32767))), 44 + (i * nc + c) * 2);
  return b; };
async function renderAudio(page, job) {
  // job: {kind:'sfx', key, loc, dur} | {kind:'tense', dur} | {kind:'rain', dur}
  let src = fs.readFileSync(path.join(ROOT, 'js/audio.js'), 'utf8');
  // виртуальные часы для процедурного «tense» (в оффлайн-контексте currentTime стоит на 0 до рендера)
  src = src.replace('const t = ctx.currentTime + 0.05;', 'const t = (window.__vt || 0) + 0.05;')
           .replace('step++; timer = setTimeout(tick, b * 1000); return;', 'step++; window.__vt = (window.__vt || 0) + b; if (window.__vt < window.__DUR - 0.5) tick(); else timer = 1; return;');
  const sfxJs = fs.readFileSync(path.join(ROOT, 'assets/sfx.js'), 'utf8');
  await page.setContent('<html><body></body></html>');
  const res = await page.evaluate(async ({ src, sfxJs, job }) => {
    const SR = 44100; window.__DUR = job.dur;
    OfflineAudioContext.prototype.resume = function () { return Promise.resolve(); }; // в оффлайне resume не нужен
    window.AudioContext = function () { const c = new OfflineAudioContext(2, Math.ceil(SR * job.dur), SR); window.__ctx = c; return c; };
    (0, eval)(sfxJs); (0, eval)(src + ';window.Sound = Sound;');
    Sound.init(); // режим calm → трек по локации (треков нет в странице — тишина)
    await new Promise(r => setTimeout(r, 400)); // декодирование сэмплов Kenney
    const ctx = window.__ctx;
    if (job.kind === 'sfx') { if (job.loc) Sound.loc(job.loc); Sound.sfx(job.key); }
    if (job.kind === 'tense') { window.__vt = 0; Sound.music('tense'); }
    if (job.kind === 'rain') { const n = ctx.createBufferSource(); const b = ctx.createBuffer(1, SR * job.dur, SR); const d = b.getChannelData(0); for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
      n.buffer = b; const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 1400; const hp = ctx.createBiquadFilter(); hp.type = 'highpass'; hp.frequency.value = 300;
      const g = ctx.createGain(); g.gain.value = 0.18 * 0.5 * 2; n.connect(hp); hp.connect(lp); lp.connect(g); g.connect(ctx.destination); n.start(0); }
    const buf = await ctx.startRendering();
    return [0, 1].map(c => Array.from(buf.getChannelData(c)));
  }, { src, sfxJs, job });
  return res;
}
async function bakeAudio(page) {
  const dir = path.join(OUT, 'assets', 'sfx_baked'); fs.mkdirSync(dir, { recursive: true });
  const SFX = ['door', 'enter', 'bell', 'train', 'horn', 'slam', 'heart', 'tear', 'phone', 'keys', 'steps', 'step', 'bump', 'drop', 'knock', 'creak', 'cloth', 'paper', 'latch', 'unlock'];
  const DUR = { train: 7.5, heart: 2.4, steps: 3.0, door: 2.0 };
  const jobs = SFX.map(k => ({ kind: 'sfx', key: k, dur: DUR[k] || 1.6, name: k })).concat([{ kind: 'sfx', key: 'door', loc: 'store', dur: 2.0, name: 'door_shop' }, { kind: 'tense', dur: 9.6 + 0.6, name: 'music_tense' }, { kind: 'rain', dur: 6, name: 'rain_loop' }]);
  for (const j of jobs) {
    const chs = await renderAudio(page, j);
    // обрезаем хвостовую тишину у SFX
    if (j.kind === 'sfx') { let e = chs[0].length; while (e > 4410 && Math.abs(chs[0][e - 1]) < 1e-4 && Math.abs(chs[1][e - 1]) < 1e-4) e--; chs[0] = chs[0].slice(0, e + 2205); chs[1] = chs[1].slice(0, e + 2205); }
    if (j.kind === 'tense') { chs[0] = chs[0].slice(0, 44100 * 9.6); chs[1] = chs[1].slice(0, 44100 * 9.6); }
    const wav = path.join(dir, j.name + '.wav'); fs.writeFileSync(wav, toWav(chs, 44100));
    execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', wav, '-c:a', 'libvorbis', '-q:a', '5', wav.replace(/\.wav$/, '.ogg')]); fs.unlinkSync(wav);
  }
  console.log('audio: ok', jobs.length);
}
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHR || '/usr/local/bin/chromium', args: ['--autoplay-policy=no-user-gesture-required'] });
  const page = await b.newPage();
  page.on('pageerror', e => { console.error('PAGEERROR', e.message); process.exitCode = 1; });
  try { const only = process.argv[2]; if (!only || only === 'pixel') await bakePixel(page); if (!only || only === 'audio') await bakeAudio(page); }
  catch (e) { console.error(e); process.exitCode = 1; }
  await page.close(); await b.close(); process.exit(process.exitCode || 0);
})();
