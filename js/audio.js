// Звук: треки по локациям (Молчат Дома, Радиотехника), процедурный индастриал «tense» и дождь, SFX на сэмплах Kenney (CC0).
const Sound = (() => {
  const TRK = 0.3; // v8: треки тише (30% от ползунка)
  let ctx, master, musicGain, rainGain, reverb, trackBus, timer = null, mode = null, step = 0, rainSrc = null;
  let vol = { music: 0.6, rain: 0.5 };
  function init() {
    if (ctx) return;
    ctx = new (window.AudioContext || window.webkitAudioContext)();
    master = ctx.createGain(); master.gain.value = 0.8; master.connect(ctx.destination);
    musicGain = ctx.createGain(); musicGain.gain.value = vol.music; 
    reverb = ctx.createConvolver(); reverb.buffer = impulse(3.2);
    const wet = ctx.createGain(); wet.gain.value = 0.45;
    musicGain.connect(master); musicGain.connect(reverb); reverb.connect(wet); wet.connect(master);
    rainGain = ctx.createGain(); rainGain.gain.value = 0; rainGain.connect(master);
    trackBus = ctx.createGain(); trackBus.gain.value = vol.music * TRK; trackBus.connect(master);
    loadSamples();
    if (mode === null) { mode = 'calm'; update(); }
  }
  function impulse(sec) {
    const len = ctx.sampleRate * sec, b = ctx.createBuffer(2, len, ctx.sampleRate);
    for (let c = 0; c < 2; c++) { const d = b.getChannelData(c); for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 2.6); }
    return b;
  }
  const f = n => 440 * Math.pow(2, (n - 69) / 12);
  function piano(note, t, dur = 2.5, v = 0.18) {
    [1, 2, 3].forEach((h, i) => {
      const o = ctx.createOscillator(), g = ctx.createGain();
      o.type = i ? 'sine' : 'triangle'; o.frequency.value = f(note) * h;
      const a = v / (h * h);
      g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(a, t + 0.01);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur / h);
      o.connect(g); g.connect(musicGain); o.start(t); o.stop(t + dur);
    });
  }
  function noiseBuf(sec = 1) {
    const b = ctx.createBuffer(1, ctx.sampleRate * sec, ctx.sampleRate), d = b.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1; return b;
  }
  function kick(t, v = 0.9) {
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.frequency.setValueAtTime(140, t); o.frequency.exponentialRampToValueAtTime(38, t + 0.25);
    g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.4);
    o.connect(g); g.connect(master); o.start(t); o.stop(t + 0.45);
  }
  function hit(t, v = 0.25, freq = 1800) {
    const s = ctx.createBufferSource(); s.buffer = noiseBuf(0.3);
    const fl = ctx.createBiquadFilter(); fl.type = 'bandpass'; fl.frequency.value = freq; fl.Q.value = 0.8;
    const g = ctx.createGain(); g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.18);
    s.connect(fl); fl.connect(g); g.connect(musicGain); s.start(t);
  }
  function bass(note, t, dur) {
    const o = ctx.createOscillator(), g = ctx.createGain(), sh = ctx.createWaveShaper(), lp = ctx.createBiquadFilter();
    o.type = 'sawtooth'; o.frequency.value = f(note);
    const c = new Float32Array(256); for (let i = 0; i < 256; i++) { const x = i / 128 - 1; c[i] = Math.tanh(x * 4); } sh.curve = c;
    lp.type = 'lowpass'; lp.frequency.value = 500;
    g.gain.setValueAtTime(0.12, t); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    o.connect(sh); sh.connect(lp); lp.connect(g); g.connect(musicGain); o.start(t); o.stop(t + dur);
  }
  // Темы
  const themes = {
    calm: { bpm: 66, prog: [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]], mel: [76, 74, 72, 71, 72, 69, 67, 69] },
    sad: { bpm: 56, prog: [[52, 55, 59], [48, 52, 55], [45, 48, 52], [47, 50, 54]], mel: [71, 69, 67, 66, 67, 64, 62, 64] },
    warm: { bpm: 76, prog: [[48, 52, 55], [55, 59, 62], [57, 60, 64], [53, 57, 60]], mel: [72, 74, 76, 79, 77, 76, 74, 72] },
  };
  function tick() {
    const t = ctx.currentTime + 0.05;
    if (mode !== 'tense') { timer = null; return; }
    if (mode === 'tense') {
      const b = 60 / 100 / 2; // восьмые
      if (step % 4 === 0) kick(t); if (step % 8 === 4) hit(t, 0.35, 1200);
      if (step % 2 === 1) hit(t, 0.08, 6000);
      const bl = [40, 40, 43, 40, 38, 40, 41, 39][Math.floor(step / 2) % 8]; if (step % 2 === 0) bass(bl, t, b * 1.8);
      step++; timer = setTimeout(tick, b * 1000); return;
    }
    const th = themes[mode]; const beat = 60 / th.bpm;
    const bar = Math.floor(step / 8) % th.prog.length, s8 = step % 8, ch = th.prog[bar];
    if (s8 === 0) { piano(ch[0] - 12, t, 4, 0.16); }
    const arp = [0, 1, 2, 1, 2, 1, 0, 1][s8]; piano(ch[arp], t, 2.2, 0.08);
    if (s8 % 2 === 0 && Math.random() < 0.55) piano(th.mel[(step / 2 + bar) % th.mel.length | 0], t, 3, 0.11);
    step++; timer = setTimeout(tick, beat / 2 * 1000);
  }
  // ── Музыка: три трека по локациям (assets/music*.js), «tense» — процедурный индастриал ──
  const LOC = { street:'roofs', street_rain:'roofs', yard:'roofs', roof:'roofs', court:'roofs', map:'roofs',
    room:'sudno', heroroom:'sudno', stairs:'sudno', kitchen:'sudno', empty:'sudno', title:'sudno', cg_father:'sudno', bug1:'sudno', bug_art:'sudno',
    store:'elektro', cafe:'elektro', college:'elektro', cg_shift:'elektro', cg_cafe:'elektro', cg_study:'sudno', cg_roof:'roofs', cg_swing:'roofs', end_good1:'roofs', end_good2:'roofs', end_good3:'roofs' };
  let loc = 'title', curTrack = null; const T = {};
  function trackEl(k) {
    if (T[k]) return T[k];
    const b64 = window.ASSETS && ASSETS.music && ASSETS.music[k]; if (!b64) return null;
    const bin = atob(b64), u8 = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i);
    const a = new Audio(URL.createObjectURL(new Blob([u8], { type: 'audio/mpeg' }))); a.loop = true; a.preload = 'auto';
    const t = { a, g: null };
    try { const src = ctx.createMediaElementSource(a); t.g = ctx.createGain(); t.g.gain.value = 0; src.connect(t.g); t.g.connect(trackBus); } catch (e) { a.volume = 0; }
    return (T[k] = t);
  }
  function fade(t, to, sec) {
    if (t.g) { const g = t.g.gain, n = ctx.currentTime; g.cancelScheduledValues(n); g.setValueAtTime(g.value, n); g.linearRampToValueAtTime(to, n + sec); }
    else { clearInterval(t.iv); const from = t.a.volume, t0 = Date.now(); t.iv = setInterval(() => { const q = Math.min(1, (Date.now() - t0) / (sec * 1000)); t.a.volume = Math.max(0, Math.min(1, (from + (to - from) * q) * vol.music * TRK)); if (q >= 1) clearInterval(t.iv); }, 50); }
  }
  function playTrack(k) {
    if (k === curTrack) { const t = k && T[k]; if (t && t.a.paused) t.a.play().catch(() => {}); return; }
    const old = curTrack && T[curTrack]; curTrack = k;
    if (old) { fade(old, 0, 1.6); clearTimeout(old.stopT); old.stopT = setTimeout(() => { if (curTrack !== Object.keys(T).find(x => T[x] === old)) old.a.pause(); }, 1700); }
    const t = k && trackEl(k); if (!t) return;
    clearTimeout(t.stopT); t.a.play().catch(() => {}); fade(t, 1, old ? 2.2 : 1.2);
  }
  function update() {
    if (!ctx) return;
    if (mode === 'tense') { playTrack(null); if (!timer) { step = 0; tick(); } return; }
    clearTimeout(timer); timer = null;
    playTrack(mode ? (LOC[loc] || 'sudno') : null);
  }
  function music(m) {
    init(); if (ctx.state === 'suspended') ctx.resume();
    if (!m || m === 'none') m = null;
    if (m === mode && (m !== null)) { update(); return; }
    mode = m; update();
  }
  function setLoc(k) { if (!k) return; loc = k; if (ctx) update(); }
  // браузер мог заблокировать автозапуск — возобновляем при следующем клике
  document.addEventListener('click', () => { if (ctx && curTrack && T[curTrack] && T[curTrack].a.paused) T[curTrack].a.play().catch(() => {}); });
  function rain(on) {
    init();
    if (on && !rainSrc) {
      rainSrc = ctx.createBufferSource(); rainSrc.buffer = noiseBuf(4); rainSrc.loop = true;
      const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 1400;
      const hp = ctx.createBiquadFilter(); hp.type = 'highpass'; hp.frequency.value = 300;
      rainSrc.connect(hp); hp.connect(lp); lp.connect(rainGain); rainSrc.start();
      rainGain.gain.linearRampToValueAtTime(0.18 * vol.rain * 2, ctx.currentTime + 2);
    } else if (!on && rainSrc) {
      rainGain.gain.linearRampToValueAtTime(0, ctx.currentTime + 1.5);
      const s = rainSrc; rainSrc = null; setTimeout(() => s.stop(), 1600);
    }
  }

  // ── Звуковые эффекты (процедурно) ──
  let sfxGain = null;
  function sfxOut() { if (!sfxGain) { sfxGain = ctx.createGain(); sfxGain.gain.value = 0.9; sfxGain.connect(master); } return sfxGain; }
  function ping(t, fr, dur, v, type = 'sine') { const o = ctx.createOscillator(), g = ctx.createGain(); o.type = type; o.frequency.value = fr;
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + 0.004); g.gain.exponentialRampToValueAtTime(0.0001, t + dur); o.connect(g); g.connect(sfxOut()); o.start(t); o.stop(t + dur + 0.02); }
  function nz(t, dur, v, freq, q = 1, type = 'bandpass') { const s = ctx.createBufferSource(); s.buffer = noiseBuf(dur + 0.05); const fl = ctx.createBiquadFilter(); fl.type = type; fl.frequency.value = freq; fl.Q.value = q;
    const g = ctx.createGain(); g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur); s.connect(fl); fl.connect(g); g.connect(sfxOut()); s.start(t); s.stop(t + dur + 0.05); }
  function thump(t, v = 0.6, f0 = 120, f1 = 45, dur = 0.22) { const o = ctx.createOscillator(), g = ctx.createGain(); o.frequency.setValueAtTime(f0, t); o.frequency.exponentialRampToValueAtTime(f1, t + dur);
    g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur + 0.05); o.connect(g); g.connect(sfxOut()); o.start(t); o.stop(t + dur + 0.1); }
  // Сэмплы: Kenney RPG Audio + Impact Sounds (CC0), assets/sfx.js
  const BUF = {};
  function loadSamples() {
    const S = (window.ASSETS && ASSETS.sfx) || {};
    Object.keys(S).forEach(k => { const bin = atob(S[k]), u8 = new Uint8Array(bin.length); for (let i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i);
      ctx.decodeAudioData(u8.buffer, b => { BUF[k] = b; }, () => {}); });
  }
  function sample(k, t, v = 1, rate = 1) { const b = BUF[k]; if (!b) return false; const s = ctx.createBufferSource(), g = ctx.createGain(); s.buffer = b; s.playbackRate.value = rate; g.gain.value = v; s.connect(g); g.connect(sfxOut()); s.start(t); return true; }
  const bell = t => { ping(t, 2093, 1.2, 0.10); ping(t + 0.09, 2637, 1.0, 0.07); ping(t + 0.2, 2093, 0.8, 0.04); };
  const SHOP = { store:1, cafe:1, cg_shift:1 };
  const FALLBACK = {
    door: t => { thump(t + 0.8, 0.35, 90, 40); },
    keys: t => { for (let i = 0; i < 9; i++) { const tt = t + i * 0.055 + Math.random() * 0.03; ping(tt, 3200 + Math.random() * 2600, 0.18, 0.05, 'triangle'); } },
    steps: t => { for (let i = 0; i < 6; i++) nz(t + i * 0.42, 0.12, 0.35, 380 + (i % 2) * 60, 1.2); },
    step: t => { nz(t, 0.09, 0.18, 420, 1.2); },
    bump: t => { thump(t, 0.8, 140, 40, 0.25); },
    drop: t => { [0, 0.13, 0.22, 0.4].forEach((d, i) => ping(t + d, 900 + i * 370, 0.25, 0.06, 'triangle')); },
    knock: t => { [0, 0.22, 0.44].forEach(d => thump(t + d, 0.5, 220, 90, 0.08)); },
  };
  const SFX = {
    door: t => { if (SHOP[loc]) bell(t); sample('door', t + (SHOP[loc] ? 0.05 : 0), 0.9) || FALLBACK.door(t); },
    enter: t => { ping(t, 660, 0.25, 0.06, 'square'); ping(t + 0.08, 990, 0.3, 0.05, 'square'); },
    bell: t => bell(t),
  };
  ['keys', 'steps', 'step', 'bump', 'drop', 'knock', 'creak', 'cloth', 'paper', 'latch', 'unlock'].forEach(k => { SFX[k] = t => { sample(k, t, k === 'steps' ? 0.8 : 1) || (FALLBACK[k] && FALLBACK[k](t)); }; });
  function sfx(k) { if (!ctx) return; if (ctx.state === 'suspended') ctx.resume(); const f = SFX[k]; if (f) f(ctx.currentTime + 0.02); }
  function blip() { if (!ctx || mode === null && !rainSrc) return; }
  function setVol(k, v) { vol[k] = v; if (ctx) { if (k === 'music') { musicGain.gain.value = v; trackBus.gain.value = v * TRK; } } }
  return { init, music, rain, setVol, vol, blip, sfx, loc: setLoc, get mode() { return mode; }, get track() { return curTrack; }, get time() { const t = curTrack && T[curTrack]; return t ? +t.a.currentTime.toFixed(1) : -1; }, get samples() { return Object.keys(BUF); } };
})();
