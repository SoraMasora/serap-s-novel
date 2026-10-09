// Эталон паритета: логика run()/choose()/breath()/openMap() из js/engine.js без DOM,
// на оригинальных данных js/story*.js (настоящие лямбды when и pickEnding).
// Детерминированный автоплей с ГПСЧ Парка–Миллера → godot/tests/fixtures/js_reference.json
// Запуск: node tools/godot/js_reference.cjs [N=40]
'use strict';
const fs = require('fs'), path = require('path'), vm = require('vm'), crypto = require('crypto');
const ROOT = path.resolve(__dirname, '..', '..');
const ctx = vm.createContext({ window: {}, console });
for (const s of ['js/story.js', 'js/story3.js']) vm.runInContext(fs.readFileSync(path.join(ROOT, s), 'utf8'), ctx);
vm.runInContext('this.__o = { STORY, ENDINGS, pickEnding };', ctx);
const { STORY, pickEnding } = ctx.__o;

function play(seed) {
  let rs = seed;
  const pick = n => { rs = (rs * 16807) % 2147483647; return rs % n; };
  const st = { scene: 'start', i: 0, feel: 50, press: 0, flags: {}, notes: [], name: 'Кирилл', bg: null, chars: {}, music: null, rain: false, chapter: '', mode: '', map: null };
  const tier = (s = st) => { if (s.feel < 40 || s.press >= 3) return 'cold'; if (s.feel >= 65 && s.press < 2) return 'warm'; return 'mid'; };
  const TV = v => (v && typeof v === 'object' && !Array.isArray(v) && ('mid' in v || 'warm' in v || 'cold' in v)) ? (tier() in v ? v[tier()] : v.mid) : v;
  const changeFeel = d => { st.feel = Math.max(0, Math.min(100, st.feel + d)); };
  const jump = l => { st.scene = l; st.i = 0; };
  const trace = [];
  let final = null, guard = 0;
  function run() { // возвращает блокирующее событие
    while (true) {
      if (++guard > 1e6) throw new Error('loop');
      const scene = STORY[st.scene]; const c = scene[st.i];
      if (!c) return { type: 'stall' };
      st.i++;
      if (Array.isArray(c)) { const t = TV(c[1]); if (t == null) continue; return { type: 'say' }; }
      if (c.tier) { const g = TV(c.tier); if (g) { jump(g); continue; } }
      if (c.card) return { type: 'card' };
      if (c.note) { const n = TV(c.note); if (n && !st.notes.includes(n)) st.notes.push(n); }
      if (c.chapter) st.chapter = c.chapter;
      if (c.bg) st.bg = c.bg;
      if (c.cut) return { type: 'cut' };
      if (c.music) st.music = c.music;
      if ('rain' in c) st.rain = c.rain;
      if (typeof c.feel === 'number' && !c.choice) changeFeel(c.feel);
      if (c.set && !c.choice) Object.assign(st.flags, c.set);
      if (c.add && !c.choice) st.press += c.add.press || 0;
      if (c.when) { if (c.when(st)) { jump(c.go); continue; } else continue; }
      if (c.go) { jump(c.go); continue; }
      if (c.breath) return { type: 'breath', cfg: c.breath };
      if (c.choice) return { type: 'choice', list: c.choice };
      if (c.ending) { jump(pickEnding(st)); continue; }
      if (c.map) { st.map = Object.assign({ done: [], pos: null }, JSON.parse(JSON.stringify(c.map))); st.mode = 'map'; return { type: 'map' }; }
      if (c.tomap) { if (st.map.done.length >= st.map.visits) { const a = st.map.after; st.map = null; st.mode = ''; jump(a); continue; } st.mode = 'map'; return { type: 'map' }; }
      if (c.final) return { type: 'final', kind: c.final };
    }
  }
  for (let n = 0; n < 5000 && !final; n++) {
    const at = `${st.scene}:${st.i}`;
    const e = run();
    if (e.type === 'say' || e.type === 'card' || e.type === 'cut') { trace.push(`${e.type}@${st.scene}:${st.i}`); continue; }
    if (e.type === 'choice') { const k = pick(e.list.length); const o = e.list[k]; trace.push(`choice@${st.scene}:${st.i}=${k}`);
      if (o.feel) changeFeel(o.feel); if (o.set) Object.assign(st.flags, o.set); if (o.add) st.press += o.add.press || 0; jump(o.go); continue; }
    if (e.type === 'breath') { const ok = pick(2) === 0, o = e.cfg; trace.push(`breath@${st.scene}:${st.i}=${ok ? 1 : 0}`);
      st.flags[o.flag || 'breathOk'] = ok; st.flags.breathScore = ok ? 100 : 0; if (ok && o.feel) changeFeel(o.feel); if (o.go) jump(ok ? o.go : (o.fail || o.go)); continue; }
    if (e.type === 'map') { const m = st.map; let id;
      if (m.items) id = '__items';
      else if (m.timer != null && m.late && pick(4) === 0) id = '__late';
      else { const av = m.spots.filter(s => !m.done.includes(s)); id = av[pick(av.length)]; }
      trace.push(`map@${st.scene}:${st.i}=${id}`);
      if (id === '__items' || id === '__late') { const a = id === '__late' ? (m.late || m.after) : m.after; st.map = null; st.mode = ''; jump(a); continue; }
      m.done.push(id);
      if (m.scenes && m.scenes[id]) { st.mode = ''; jump(m.scenes[id]); continue; }
      const k = (st.flags['v_' + id] || 0) + 1; st.flags['v_' + id] = k; st.mode = ''; jump(STORY[id + '_' + k] ? id + '_' + k : id + '_3'); continue; }
    if (e.type === 'final') { final = e.kind; trace.push(`final=${e.kind}`); break; }
    throw new Error('stall at ' + at);
  }
  const digest = crypto.createHash('sha256').update(trace.join('\n')).digest('hex');
  return { seed, ending: final, steps: trace.length, feel: st.feel, press: st.press, notes: st.notes.length, digest };
}
const N = +process.argv[2] || 40;
const seeds = Array.from({ length: N }, (_, k) => 1 + k * 7919);
const runs = seeds.map(play);
const out = { generator: 'tools/godot/js_reference.cjs', rng: 'park-miller 16807 mod 2^31-1; pick(n)=s%n', runs };
fs.mkdirSync(path.join(ROOT, 'godot/tests/fixtures'), { recursive: true });
fs.writeFileSync(path.join(ROOT, 'godot/tests/fixtures/js_reference.json'), JSON.stringify(out, null, 1) + '\n');
const ends = {}; runs.forEach(r => ends[r.ending] = (ends[r.ending] || 0) + 1);
console.log('runs', runs.length, 'endings', JSON.stringify(ends));
