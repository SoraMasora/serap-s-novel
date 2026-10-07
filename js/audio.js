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
  function blip() { if (!ctx || mode === null && !rainSrc) return; }
  function setVol(k, v) { vol[k] = v; if (ctx) { if (k === 'music') musicGain.gain.value = v; } }
  return { init, music, rain, setVol, vol, blip, get mode() { return mode; } };
})();
