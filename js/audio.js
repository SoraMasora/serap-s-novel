// Процедурная музыка на WebAudio: меланхоличное фортепиано, индастриал, дождь.
const Sound = (() => {
  let ctx, master, musicGain, rainGain, reverb, timer = null, mode = null, step = 0, rainSrc = null;
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
  function music(m) {
    init(); if (ctx.state === 'suspended') ctx.resume();
    if (m === mode) return; clearTimeout(timer); mode = m; step = 0;
    if (!m || m === 'none') { mode = null; return; }
    tick();
  }
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
  const SFX = {
    door: t => { ping(t, 2093, 1.2, 0.12); ping(t + 0.09, 2637, 1.0, 0.08); // колокольчик
      const o = ctx.createOscillator(), g = ctx.createGain(), fl = ctx.createBiquadFilter(); o.type = 'sawtooth'; o.frequency.setValueAtTime(180, t + 0.15); o.frequency.linearRampToValueAtTime(260, t + 0.7);
      fl.type = 'bandpass'; fl.frequency.value = 900; fl.Q.value = 6; g.gain.setValueAtTime(0, t + 0.15); g.gain.linearRampToValueAtTime(0.05, t + 0.3); g.gain.linearRampToValueAtTime(0, t + 0.75);
      o.connect(fl); fl.connect(g); g.connect(sfxOut()); o.start(t + 0.15); o.stop(t + 0.8); thump(t + 0.8, 0.35, 90, 40); },
    keys: t => { for (let i = 0; i < 9; i++) { const tt = t + i * 0.055 + Math.random() * 0.03; ping(tt, 3200 + Math.random() * 2600, 0.18, 0.05, 'triangle'); nz(tt, 0.04, 0.05, 7000, 2); } nz(t + 0.6, 0.08, 0.2, 1500, 3); thump(t + 0.62, 0.2, 400, 200, 0.05); },
    steps: t => { for (let i = 0; i < 6; i++) { const tt = t + i * 0.42; nz(tt, 0.12, 0.35, 380 + (i % 2) * 60, 1.2); nz(tt + 0.01, 0.09, 0.08, 2500, 0.7); } },
    step: t => { nz(t, 0.09, 0.18, 420, 1.2); nz(t, 0.06, 0.04, 2400, 0.7); },
    bump: t => { thump(t, 0.8, 140, 40, 0.25); nz(t, 0.12, 0.3, 600, 0.8); },
    drop: t => { [0, 0.13, 0.22, 0.4, 0.47].forEach((d, i) => { ping(t + d, 900 + i * 370, 0.25, 0.06, 'triangle'); ping(t + d, 2300 + i * 500, 0.12, 0.03); nz(t + d, 0.05, 0.12, 3000, 1.5); }); thump(t + 0.05, 0.35, 160, 70, 0.12); },
    knock: t => { [0, 0.22, 0.44].forEach(d => { thump(t + d, 0.5, 220, 90, 0.08); nz(t + d, 0.05, 0.2, 900, 2); }); },
    enter: t => { ping(t, 660, 0.25, 0.06, 'square'); ping(t + 0.08, 990, 0.3, 0.05, 'square'); },
  };
  function sfx(k) { if (!ctx) return; if (ctx.state === 'suspended') ctx.resume(); const f = SFX[k]; if (f) f(ctx.currentTime + 0.02); }
  function blip() { if (!ctx || mode === null && !rainSrc) return; }
  function setVol(k, v) { vol[k] = v; if (ctx) { if (k === 'music') musicGain.gain.value = v; } }
  return { init, music, rain, setVol, vol, blip, sfx, get mode() { return mode; } };
})();
