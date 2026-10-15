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
  const LOC = { cg_walkhome:'roofs', yard_father:'roofs', cg_shoulders:'roofs', cg_hit:'roofs', end_gone:'roofs', end_home:'roofs', end_expo:'sudno', end_letters:'sudno', street:'roofs', street_rain:'roofs', yard:'roofs', roof:'roofs', court:'roofs', map:'roofs',
    room:'sudno', heroroom:'sudno', stairs:'sudno', kitchen:'sudno', empty:'sudno', title:'sudno', cg_father:'sudno', bug1:'sudno', bug_art:'sudno',
    store:'elektro', cafe:'elektro', college:'elektro', cg_shift:'elektro', cg_cafe:'elektro', cg_study:'sudno', cg_roof:'roofs', cg_swing:'roofs', end_good1:'roofs', end_good2:'roofs', end_good3:'roofs',
    platform:'roofs', underpass:'roofs', cg_platform:'roofs', cg_train1:'roofs', cg_train2:'roofs', cg_reconcile:'roofs', cg_angel:'roofs',
    clinic:'sudno', cg_clinic:'sudno', cg_leaflet1:'sudno', cg_leaflet2:'sudno', cg_quarrel:'sudno', cg_panic:'sudno',
    cg_store_help:'elektro', cg_roof_quiet:'roofs', cg_guests:'sudno', cg_tea:'sudno', cg_sing:'roofs', cg_take:'roofs', cg_dumplings:'sudno', cg_canvas:'sudno' };
  // v18: CG петли «Это не конец»
  ['d_room', 'd_store', 'd_cross', 'd_neck', 'x_scream', 'c_sketch', 'c_icon', 'h_snow', 't_landing'].forEach(k => LOC[k] = 'sudno');
  ['d_road', 'd_train', 'd_cliff', 't_roof', 't_sky', 't_sky2', 't_hand', 't_angel'].forEach(k => LOC[k] = 'roofs');
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
    droneOn(mode === 'drone'); // v18: меню после смерти — гул вместо музыки
    if (mode === 'tense') { playTrack(null); if (!timer) { step = 0; tick(); } return; }
    clearTimeout(timer); timer = null;
    playTrack(mode && mode !== 'drone' ? (LOC[loc] || 'sudno') : null);
  }
  // v18: «гул» — расстроенные пилы на 37 Гц под дышащим фильтром, тонкий звон сверху, шорох; живёт на шине музыки
  let drone = null;
  function droneOn(on) {
    if (on && !drone) {
      const out = ctx.createGain(); out.gain.value = 0.0001; out.connect(musicGain);
      const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 260; lp.Q.value = 2.2; lp.connect(out);
      const lfo = ctx.createOscillator(), lg = ctx.createGain(); lfo.frequency.value = 0.07; lg.gain.value = 120; lfo.connect(lg); lg.connect(lp.frequency);
      const all = [lfo];
      [[36.7, 'sawtooth', 0.15], [36.95, 'sawtooth', 0.15], [55.1, 'triangle', 0.12], [73.2, 'triangle', 0.07]].forEach(([fr, ty, v]) => {
        const o = ctx.createOscillator(), g = ctx.createGain(); o.type = ty; o.frequency.value = fr; g.gain.value = v; o.connect(g); g.connect(lp); all.push(o); });
      const hi = ctx.createOscillator(), hg = ctx.createGain(), tr = ctx.createOscillator(), tg = ctx.createGain();
      hi.frequency.value = 1567; hg.gain.value = 0.004; tr.frequency.value = 5.3; tg.gain.value = 0.0035; tr.connect(tg); tg.connect(hg.gain); hi.connect(hg); hg.connect(out); all.push(hi, tr);
      const ns = ctx.createBufferSource(); ns.buffer = noiseBuf(4); ns.loop = true; const bp = ctx.createBiquadFilter(); bp.type = 'bandpass'; bp.frequency.value = 700; bp.Q.value = 0.6;
      const ng = ctx.createGain(); ng.gain.value = 0.035; ns.connect(bp); bp.connect(ng); ng.connect(out); all.push(ns);
      all.forEach(n => n.start()); out.gain.linearRampToValueAtTime(0.55, ctx.currentTime + 2.5); drone = { out, all };
    } else if (!on && drone) {
      const d = drone, n = ctx.currentTime; drone = null; d.out.gain.cancelScheduledValues(n); d.out.gain.setValueAtTime(d.out.gain.value, n); d.out.gain.linearRampToValueAtTime(0.0001, n + 1.4);
      setTimeout(() => d.all.forEach(x => { try { x.stop(); } catch (e) {} }), 1600);
    }
  }
  // v18: ветер со снегом — шум под «качающимся» фильтром
  let windSrc = null, windG = null, windLfo = null;
  function wind(on) {
    if (!on && !ctx) return; init();
    if (on && !windSrc) {
      windSrc = ctx.createBufferSource(); windSrc.buffer = noiseBuf(5); windSrc.loop = true;
      const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 520; lp.Q.value = 4;
      windLfo = ctx.createOscillator(); const lg = ctx.createGain(); windLfo.frequency.value = 0.13; lg.gain.value = 260; windLfo.connect(lg); lg.connect(lp.frequency);
      windG = ctx.createGain(); windG.gain.value = 0.0001; windSrc.connect(lp); lp.connect(windG); windG.connect(master); windSrc.start(); windLfo.start();
      windG.gain.linearRampToValueAtTime(0.14 * vol.rain * 2, ctx.currentTime + 2.5);
    } else if (!on && windSrc) {
      const s = windSrc, l = windLfo, g = windG.gain, n = ctx.currentTime; windSrc = windLfo = null;
      g.cancelScheduledValues(n); g.setValueAtTime(g.value, n); g.linearRampToValueAtTime(0.0001, n + 1.5); setTimeout(() => { s.stop(); l.stop(); }, 1600);
    }
  }
  // v18: тишина перед скримером — общий звук гаснет на sec секунд (сам скример идёт мимо этой шины)
  function hush(sec) {
    if (!ctx) return; const g = master.gain, n = ctx.currentTime;
    g.cancelScheduledValues(n); g.setValueAtTime(g.value, n); g.linearRampToValueAtTime(0.0001, n + 0.08); g.setValueAtTime(0.0001, n + sec); g.linearRampToValueAtTime(0.8, n + sec + 1.2);
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
  // v10: поезд, гудок, хлопок двери, сердцебиение, рвётся бумага, вибрация телефона
  function swell(t, dur, v, freq, type = 'lowpass', q = 0.7) { const s = ctx.createBufferSource(); s.buffer = noiseBuf(dur + 0.1); const fl = ctx.createBiquadFilter(); fl.type = type; fl.frequency.value = freq; fl.Q.value = q;
    const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(v, t + dur * 0.45); g.gain.exponentialRampToValueAtTime(0.0001, t + dur); s.connect(fl); fl.connect(g); g.connect(sfxOut()); s.start(t); s.stop(t + dur + 0.1); }
  function horn(t, dur = 1.1, v = 0.07) { [311, 370].forEach(f => { const o = ctx.createOscillator(), fl = ctx.createBiquadFilter(), g = ctx.createGain(); o.type = 'sawtooth'; o.frequency.value = f; fl.type = 'lowpass'; fl.frequency.value = 1400;
    g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(v, t + 0.06); g.gain.setValueAtTime(v, t + dur - 0.15); g.gain.exponentialRampToValueAtTime(0.0001, t + dur); o.connect(fl); fl.connect(g); g.connect(sfxOut()); o.start(t); o.stop(t + dur + 0.05); }); }
  SFX.train = t => { swell(t, 6.5, 0.5, 260); swell(t + 0.4, 5.5, 0.12, 1800, 'bandpass', 0.6); for (let i = 0; i < 16; i++) { const tt = t + 1 + i * 0.3 + (i % 2) * 0.09; thump(tt, 0.18 + 0.12 * Math.sin(i / 15 * Math.PI), 160, 70, 0.07); } horn(t + 0.3); };
  SFX.horn = t => horn(t, 1.3, 0.08);
  SFX.slam = t => { thump(t, 1, 110, 35, 0.35); nz(t, 0.25, 0.5, 900, 0.8); sample('door', t - 0.02, 0.5); thump(t + 0.12, 0.3, 300, 120, 0.06); };
  SFX.heart = t => { [0, 0.24, 0.85, 1.09, 1.7, 1.94].forEach((d, i) => thump(t + d, i % 2 ? 0.35 : 0.55, 70, 38, 0.14)); };
  SFX.tear = t => { for (let i = 0; i < 7; i++) nz(t + i * 0.035 + Math.random() * 0.02, 0.06, 0.25, 2500 + Math.random() * 2500, 0.8, 'highpass'); sample('paper', t + 0.2, 0.5); };
  SFX.phone = t => { [0, 0.5].forEach(d => { const o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'square'; o.frequency.value = 120; g.gain.setValueAtTime(0.0001, t + d); g.gain.linearRampToValueAtTime(0.04, t + d + 0.02); g.gain.setValueAtTime(0.04, t + d + 0.32); g.gain.exponentialRampToValueAtTime(0.0001, t + d + 0.36);
    const fl = ctx.createBiquadFilter(); fl.type = 'lowpass'; fl.frequency.value = 400; o.connect(fl); fl.connect(g); g.connect(sfxOut()); o.start(t + d); o.stop(t + d + 0.4); }); };
  ['keys', 'steps', 'step', 'bump', 'drop', 'knock', 'creak', 'cloth', 'paper', 'latch', 'unlock'].forEach(k => { SFX[k] = t => { sample(k, t, k === 'steps' ? 0.8 : 1) || (FALLBACK[k] && FALLBACK[k](t)); }; });
  // ── v18: звуки петли ──
  // скример серафима: кольцевая модуляция расстроенных пил + свист шума + перегруз + удар; мимо master (не глохнет от hush)
  SFX.scream = t => {
    const comp = ctx.createDynamicsCompressor(); comp.threshold.value = -12; comp.ratio.value = 8; const out = ctx.createGain(); out.gain.value = 0.75; comp.connect(out); out.connect(ctx.destination);
    const sh = ctx.createWaveShaper(), c = new Float32Array(1024); for (let i = 0; i < 1024; i++) c[i] = Math.tanh((i / 512 - 1) * 3.5); sh.curve = c; sh.connect(comp);
    const env = ctx.createGain(); env.gain.setValueAtTime(0.0001, t); env.gain.exponentialRampToValueAtTime(1, t + 0.025); env.gain.setValueAtTime(1, t + 1.9); env.gain.exponentialRampToValueAtTime(0.0001, t + 2.7); env.connect(sh);
    const rm = ctx.createGain(); rm.gain.value = 0; rm.connect(env);
    const car = ctx.createOscillator(); car.frequency.setValueAtTime(97, t); car.frequency.linearRampToValueAtTime(61, t + 2.6); car.connect(rm.gain);
    const vib = ctx.createOscillator(), vg = ctx.createGain(); vib.frequency.value = 7.5; vg.gain.value = 38; vib.connect(vg);
    [0, 7, -9, 13].forEach(det => { const o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'sawtooth';
      o.frequency.setValueAtTime(420 + det, t); o.frequency.exponentialRampToValueAtTime(990 + det * 3, t + 0.3); o.frequency.linearRampToValueAtTime(820 + det * 2, t + 1.6); o.frequency.exponentialRampToValueAtTime(300, t + 2.7);
      vg.connect(o.frequency); g.gain.value = 0.2; o.connect(g); g.connect(rm); o.start(t); o.stop(t + 2.8); });
    const ns = ctx.createBufferSource(); ns.buffer = noiseBuf(3); const bp = ctx.createBiquadFilter(); bp.type = 'bandpass'; bp.Q.value = 3;
    bp.frequency.setValueAtTime(600, t); bp.frequency.exponentialRampToValueAtTime(3800, t + 0.4); bp.frequency.exponentialRampToValueAtTime(1200, t + 2.6);
    const ngn = ctx.createGain(); ngn.gain.value = 0.8; ns.connect(bp); bp.connect(ngn); ngn.connect(env);
    const b = ctx.createOscillator(), bg = ctx.createGain(); b.frequency.setValueAtTime(90, t); b.frequency.exponentialRampToValueAtTime(28, t + 1.2); bg.gain.setValueAtTime(1, t); bg.gain.exponentialRampToValueAtTime(0.0001, t + 1.4); b.connect(bg); bg.connect(comp);
    [car, vib, ns, b].forEach(n => n.start(t)); [car, vib, ns].forEach(n => n.stop(t + 2.8)); b.stop(t + 1.5);
  };
  SFX.glitch = t => { for (let i = 0; i < 6; i++) ping(t + i * 0.045 + Math.random() * 0.02, 200 + Math.random() * 3000, 0.04, 0.05, 'square'); nz(t, 0.2, 0.16, 2400, 0.7, 'highpass'); };
  SFX.whisper = t => { for (let i = 0; i < 5; i++) { const tt = t + i * 0.16 + Math.random() * 0.05, s = ctx.createBufferSource(), bp = ctx.createBiquadFilter(), g = ctx.createGain(); s.buffer = noiseBuf(0.3);
    bp.type = 'bandpass'; bp.frequency.value = 1800 + Math.random() * 2200; bp.Q.value = 6; g.gain.setValueAtTime(0.0001, tt); g.gain.linearRampToValueAtTime(0.12, tt + 0.06); g.gain.exponentialRampToValueAtTime(0.0001, tt + 0.2);
    let last = g; if (ctx.createStereoPanner) { const p = ctx.createStereoPanner(); p.pan.value = i % 2 ? -0.8 : 0.8; g.connect(p); last = p; }
    s.connect(bp); bp.connect(g); last.connect(sfxOut()); s.start(tt); s.stop(tt + 0.3); } };
  SFX.brake = t => { const o = ctx.createOscillator(), g = ctx.createGain(), bp = ctx.createBiquadFilter(), v = ctx.createOscillator(), vg = ctx.createGain();
    o.type = 'sawtooth'; o.frequency.setValueAtTime(2300, t); o.frequency.linearRampToValueAtTime(1900, t + 1.4); v.frequency.value = 23; vg.gain.value = 60; v.connect(vg); vg.connect(o.frequency);
    bp.type = 'bandpass'; bp.frequency.value = 2400; bp.Q.value = 4; g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.09, t + 0.08); g.gain.setValueAtTime(0.09, t + 1.1); g.gain.exponentialRampToValueAtTime(0.0001, t + 1.5);
    o.connect(bp); bp.connect(g); g.connect(sfxOut()); o.start(t); v.start(t); o.stop(t + 1.6); v.stop(t + 1.6); nz(t, 1.4, 0.12, 3000, 1.5); };
  SFX.toll = t => { [[196, 0.16, 6], [392.6, 0.08, 4.5], [466.2, 0.05, 3.5], [587.3, 0.04, 3], [784, 0.03, 2.2], [98, 0.08, 5]].forEach(([fr, v, d]) => ping(t, fr, d, v)); };
  SFX.thud = t => { thump(t, 1, 90, 30, 0.4); nz(t, 0.15, 0.4, 300, 0.8, 'lowpass'); };
  SFX.wings = t => { for (let i = 0; i < 4; i++) swell(t + i * 0.42, 0.38, 0.22, 600 + i * 50, 'lowpass', 0.8); };
  SFX.gust = t => swell(t, 2.4, 0.3, 700, 'bandpass', 0.7);
  // ── 0.7.4: новый скример ──
  // крик: три «голоса» (пила → форманты «а» на крике), вибрато и дребезг, обрывы плёнки на 1.15 с,
  // диссонансный кластер, металлический FM-скрежет, суб-удар; мимо master — как SFX.scream
  SFX.shriek = t => {
    const comp = ctx.createDynamicsCompressor(); comp.threshold.value = -14; comp.knee.value = 6; comp.ratio.value = 12; comp.attack.value = 0.002; comp.release.value = 0.2;
    const out = ctx.createGain(); out.gain.value = 0.95; comp.connect(out); out.connect(ctx.destination);
    const sh = ctx.createWaveShaper(), c = new Float32Array(2048); for (let i = 0; i < 2048; i++) c[i] = Math.tanh((i / 1024 - 1) * 2.6); sh.curve = c; sh.connect(comp);
    const gate = ctx.createGain(); gate.gain.setValueAtTime(1, t); for (let k = 0; k < 6; k++) { const a = t + 1.15 + k * 0.05; gate.gain.setValueAtTime(0.06, a); gate.gain.setValueAtTime(1, a + 0.025); } gate.connect(sh);
    const env = ctx.createGain(); env.gain.setValueAtTime(0.0001, t); env.gain.exponentialRampToValueAtTime(1, t + 0.012); env.gain.setValueAtTime(1, t + 2.3); env.gain.exponentialRampToValueAtTime(0.0001, t + 3.3); env.connect(gate);
    const formants = [[950, 7, 1], [1550, 9, 0.75], [2900, 11, 0.5], [4100, 13, 0.28]].map(([f, q, v]) => { const bp = ctx.createBiquadFilter(), g = ctx.createGain();
      bp.type = 'bandpass'; bp.frequency.value = f; bp.Q.value = q; g.gain.value = v * 2.2; bp.connect(g); g.connect(env); return bp; });
    const vib = ctx.createOscillator(), vg = ctx.createGain(); vib.frequency.setValueAtTime(5.5, t); vib.frequency.linearRampToValueAtTime(9, t + 2.5); vg.gain.value = 26; vib.connect(vg);
    const jit = ctx.createOscillator(), jg = ctx.createGain(); jit.type = 'square'; jit.frequency.value = 23; jg.gain.value = 11; jit.connect(jg);
    [[1, 0, 0.5], [1.059, 0.03, 0.34], [0.943, 0.06, 0.3]].forEach(([m, d, v]) => { const o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'sawtooth';
      o.frequency.setValueAtTime(620 * m, t + d); o.frequency.exponentialRampToValueAtTime(1180 * m, t + d + 0.07); o.frequency.linearRampToValueAtTime(1320 * m, t + 0.9);
      o.frequency.linearRampToValueAtTime(1040 * m, t + 2.1); o.frequency.exponentialRampToValueAtTime(380 * m, t + 3.2); vg.connect(o.frequency); jg.connect(o.frequency);
      g.gain.setValueAtTime(0.0001, t + d); g.gain.exponentialRampToValueAtTime(v, t + d + 0.01); formants.forEach(bp => g.connect(bp)); o.connect(g); o.start(t + d); o.stop(t + 3.35); });
    const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 1800; const cl = ctx.createGain(); cl.gain.setValueAtTime(0.0001, t); cl.gain.exponentialRampToValueAtTime(1, t + 0.02); cl.gain.exponentialRampToValueAtTime(0.0001, t + 3.0); lp.connect(cl); cl.connect(comp);
    [110, 116.5, 164.8, 174.6, 246.9].forEach(f => { const o = ctx.createOscillator(), g = ctx.createGain(); o.type = 'sawtooth'; o.frequency.value = f; g.gain.value = 0.07; o.connect(g); g.connect(lp); o.start(t); o.stop(t + 3.1); });
    const br = ctx.createBufferSource(); br.buffer = noiseBuf(3.4); const bf = ctx.createBiquadFilter(); bf.type = 'bandpass'; bf.frequency.value = 2600; bf.Q.value = 1.2;
    const bgn = ctx.createGain(); bgn.gain.value = 0.32; br.connect(bf); bf.connect(bgn); bgn.connect(env);
    const car = ctx.createOscillator(), mod = ctx.createOscillator(), mg = ctx.createGain(), cg = ctx.createGain(); car.frequency.setValueAtTime(2700, t); car.frequency.linearRampToValueAtTime(3400, t + 2.6);
    mod.frequency.value = 431; mg.gain.value = 1600; mod.connect(mg); mg.connect(car.frequency);
    cg.gain.setValueAtTime(0.0001, t); cg.gain.exponentialRampToValueAtTime(0.09, t + 0.05); cg.gain.setValueAtTime(0.09, t + 2.2); cg.gain.exponentialRampToValueAtTime(0.0001, t + 3.0); car.connect(cg); cg.connect(gate);
    const b = ctx.createOscillator(), bg = ctx.createGain(); b.frequency.setValueAtTime(110, t); b.frequency.exponentialRampToValueAtTime(32, t + 0.7);
    bg.gain.setValueAtTime(1.2, t); bg.gain.exponentialRampToValueAtTime(0.0001, t + 1.1); b.connect(bg); bg.connect(comp);
    const bn = ctx.createBufferSource(); bn.buffer = noiseBuf(0.4); const bl = ctx.createBiquadFilter(); bl.type = 'lowpass'; bl.frequency.value = 900; const bng = ctx.createGain();
    bng.gain.setValueAtTime(0.9, t); bng.gain.exponentialRampToValueAtTime(0.0001, t + 0.35); bn.connect(bl); bl.connect(bng); bng.connect(comp);
    [vib, jit, br, car, mod, b, bn].forEach(n => n.start(t)); [vib, jit, br, car, mod].forEach(n => n.stop(t + 3.4)); b.stop(t + 1.2); bn.stop(t + 0.4);
  };
  // звон в ушах после удара (тихо, биения 7350/7420 Гц)
  SFX.ring = t => { [[7350, 0.035], [7420, 0.02]].forEach(([f, v]) => { const o = ctx.createOscillator(), g = ctx.createGain(); o.frequency.value = f;
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(v, t + 0.08); g.gain.setValueAtTime(v, t + 0.6); g.gain.exponentialRampToValueAtTime(0.0001, t + 3.1);
    o.connect(g); g.connect(sfxOut()); o.start(t); o.stop(t + 3.2); }); };
  // вдох и выдох у самого левого уха
  SFX.breath = t => { [[0, 0.75, 1000, 1500, 0.22], [0.95, 0.6, 1300, 800, 0.3]].forEach(([d, dur, f0, f1, v]) => {
    const s = ctx.createBufferSource(), bp = ctx.createBiquadFilter(), g = ctx.createGain(); s.buffer = noiseBuf(dur + 0.1); bp.type = 'bandpass'; bp.Q.value = 2.2;
    bp.frequency.setValueAtTime(f0, t + d); bp.frequency.linearRampToValueAtTime(f1, t + d + dur);
    g.gain.setValueAtTime(0.0001, t + d); g.gain.linearRampToValueAtTime(v, t + d + dur * 0.6); g.gain.exponentialRampToValueAtTime(0.0001, t + d + dur);
    let last = g; if (ctx.createStereoPanner) { const p = ctx.createStereoPanner(); p.pan.value = -0.75; g.connect(p); last = p; }
    s.connect(bp); bp.connect(g); last.connect(sfxOut()); s.start(t + d); s.stop(t + d + dur + 0.1); }); };
  function sfx(k) { if (!ctx) return; if (ctx.state === 'suspended') ctx.resume(); const f = SFX[k]; if (f) f(ctx.currentTime + 0.02); }
  function blip() { if (!ctx || mode === null && !rainSrc) return; }
  function setVol(k, v) { vol[k] = v; if (ctx) { if (k === 'music') { musicGain.gain.value = v; trackBus.gain.value = v * TRK; } } }
  return { init, music, rain, wind, hush, setVol, vol, blip, sfx, loc: setLoc, get mode() { return mode; }, get track() { return curTrack; }, get time() { const t = curTrack && T[curTrack]; return t ? +t.a.currentTime.toFixed(1) : -1; }, get samples() { return Object.keys(BUF); } };
})();
