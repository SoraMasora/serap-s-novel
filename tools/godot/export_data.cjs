// Конвертер исходной веб-версии (js/*.js, assets/*.js) → данные Godot-проекта.
// Запуск из корня репо: node tools/godot/export_data.cjs [--assets]
//  - всегда: godot/data/story.json (сцены, концовки, правила выбора концовки)
//  - с --assets: декодирует base64-ассеты в godot/assets/** (бинарники не коммитятся, см. docs/PORTING_CONTRACT.md)
'use strict';
const fs = require('fs'), path = require('path'), vm = require('vm');
const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(ROOT, 'godot');
const html = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
const scripts = [...html.matchAll(/<script src="([^"]+)"><\/script>/g)].map(m => m[1]);

// ── 1. Сценарий ──
const ctx = vm.createContext({ window: {}, console });
for (const s of ['js/story.js', 'js/story3.js', 'js/story_loop.js']) vm.runInContext(fs.readFileSync(path.join(ROOT, s), 'utf8'), ctx, { filename: s });
vm.runInContext('this.__o = { STORY, ENDINGS, LOOP, pickEnding: pickEnding.toString() };', ctx);
const { STORY, ENDINGS, LOOP, pickEnding } = ctx.__o;

// JS-лямбда условия → выражение Godot Expression (база — StoryRunner: flag(), num(), notes_count(); входы feel, press)
function convCond(src, sVar, fVar) {
  let e = src;
  e = e.replace(/\(\s*s\.notes\s*\|\|\s*\[\]\s*\)\.length/g, 'notes_count()');
  const flagRe = fVar ? new RegExp(`(?:${sVar}\\.flags|${fVar})\\.(\\w+)`, 'g') : new RegExp(`${sVar}\\.flags\\.(\\w+)`, 'g');
  e = e.replace(new RegExp(flagRe.source + '\\s*(>=|<=|>|<|===|==)\\s*(\\d+)', 'g'), (m, k, op, n) => `num("${k}") ${op.replace('===', '==')} ${n}`);
  e = e.replace(flagRe, (m, k) => `flag("${k}")`);
  e = e.replace(new RegExp(`\\b${sVar}\\.(feel|press)\\b`, 'g'), '$1');
  e = e.replace(/&&/g, ' and ').replace(/\|\|/g, ' or ').replace(/!(?!=)/g, 'not ');
  e = e.replace(/\s+/g, ' ').trim();
  if (/\bs\.|=>|\bf\.|[{};]/.test(e)) throw new Error('Не удалось сконвертировать условие: ' + src + ' → ' + e);
  return e;
}
function condFromFn(fn) {
  const m = fn.toString().match(/^\s*\(?\s*(\w+)\s*\)?\s*=>\s*([\s\S]+)$/);
  if (!m) throw new Error('Неизвестная форма when: ' + fn);
  return convCond(m[2], m[1], null);
}
// Dynamic JS dialogue is evaluated at build time, not re-written in GDScript.
// 8 loop levels × cross/train/ending flags. History-dependent fragments remain tokens.
function dynamicText(fn) {
  const texts = [], lookup = [];
  const saved = {mem: LOOP.mem, list: LOOP.list, flash: LOOP.flash, word: LOOP.word};
  Object.assign(LOOP, {
    mem: (_s, k) => `{{mem:${k}}}`, list: (_s, cur) => cur ? '{{list:current}}' : '{{list}}',
    flash: (_s, salt) => `{{flash:${salt}}}`, word: id => `{{word:${id}}}`
  });
  try {
    for (let n=0;n<8;n++) for (let cross=0;cross<2;cross++) for (let train=0;train<2;train++) for (let good=0;good<2;good++) {
      const text = fn({flags:{loop:n,d_cross:!!cross,d_train:!!train,lend:good?'good':'other',dord:['first'],dth:'current'}});
      let i=texts.indexOf(text); if(i<0) {i=texts.length; texts.push(text);} lookup.push(i);
    }
  } finally { Object.assign(LOOP,saved); }
  return {loop_text:texts,lookup};
}
function value(v) {
  if (typeof v === 'function') return dynamicText(v);
  if (Array.isArray(v)) return v.map(value);
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).map(([k,x])=>[k,value(x)]));
  return v;
}
function conv(c) {
  if (Array.isArray(c)) { const o = { say: [c[0], c[1] === undefined ? null : value(c[1])] }; if (c.length > 2) o.say.push(value(c[2])); return o; }
  return Object.fromEntries(Object.entries(c).map(([k,v])=>[k,k==='when'?condFromFn(v):value(v)]));
}
const scenes = {};
for (const [k, sc] of Object.entries(STORY)) scenes[k] = sc.map(conv);
// pickEnding → упорядоченные правила
const rules = [];
const body = pickEnding.replace(/^[^{]*\{/, '').replace(/\}\s*$/, '');
for (const m of body.matchAll(/if\s*\((.+?)\)\s*return\s*'(\w+)'/g)) rules.push({ when: convCond(m[1], 's', 'f'), go: m[2] });
const fin = [...body.matchAll(/^\s*return\s*'(\w+)'/gm)].pop(); rules.push({ when: 'true', go: fin[1] });
// проверка ссылочной целостности
const missing = [];
const goKeys = ['go', 'fail', 'after', 'late'];
for (const [k, sc] of Object.entries(scenes)) sc.forEach((c, i) => {
  for (const g of goKeys) if (typeof c[g] === 'string' && !scenes[c[g]]) missing.push(`${k}[${i}].${g}=${c[g]}`);
  if (c.breath) for (const g of ['go', 'fail']) if (c.breath[g] && !scenes[c.breath[g]]) missing.push(`${k}[${i}].breath.${g}`);
  if (c.choice) c.choice.forEach((o, j) => { if (!scenes[o.go]) missing.push(`${k}[${i}].choice[${j}]=${o.go}`); });
  if (c.tier) for (const t of Object.values(c.tier)) if (t && !scenes[t]) missing.push(`${k}[${i}].tier=${t}`);
  if (c.map) { if (c.map.after && !scenes[c.map.after]) missing.push(`${k}.map.after`); for (const v of Object.values(c.map.scenes || {})) if (!scenes[v]) missing.push(`${k}.map.scenes=${v}`); }
});
for (const r of rules) if (!scenes[r.go]) missing.push('ending ' + r.go);
if (missing.length) { console.error('MISSING', missing); process.exit(1); }
const notes = new Set(); Object.values(STORY).forEach(sc => sc.forEach(c => { if (c && c.note) notes.add(c.note); }));
const story = { version: 2, source: 'js/story.js + js/story3.js + js/story_loop.js', loop: Object.fromEntries(Object.entries(LOOP).filter(([,v]) => typeof v !== 'function')), start: 'start', notes_total: notes.size, ending_rules: rules, endings: ENDINGS, scenes };
fs.mkdirSync(path.join(OUT, 'data'), { recursive: true });
fs.writeFileSync(path.join(OUT, 'data', 'story.json'), JSON.stringify(story, null, 1) + '\n');
console.log('story.json: scenes', Object.keys(scenes).length, 'rules', rules.length, 'notes', notes.size);

// ── 2. Ассеты ──
if (process.argv.includes('--assets')) {
  const actx = vm.createContext({ window: {}, console }); actx.window = actx;
  for (const s of scripts.filter(s => s.startsWith('assets/'))) vm.runInContext(fs.readFileSync(path.join(ROOT, s), 'utf8'), actx, { filename: s });
  const A = actx.ASSETS; const manifest = {}; let n = 0, bytes = 0;
  const EXT = { 'image/webp': 'webp', 'image/png': 'png', 'image/jpeg': 'jpg' };
  for (const [group, items] of Object.entries(A)) {
    const dir = path.join(OUT, 'assets', group); fs.mkdirSync(dir, { recursive: true }); manifest[group] = {};
    for (const [key, val] of Object.entries(items)) {
      let buf, ext;
      const m = /^data:([^;]+);base64,/.exec(val);
      if (m) { ext = EXT[m[1]]; if (!ext) throw new Error('mime ' + m[1]); buf = Buffer.from(val.slice(m[0].length), 'base64'); }
      else { buf = Buffer.from(val, 'base64'); ext = 'mp3'; }
      const file = `${key}.${ext}`; fs.writeFileSync(path.join(dir, file), buf);
      manifest[group][key] = `res://assets/${group}/${file}`; n++; bytes += buf.length;
    }
  }
  // Маркеры окна реплик из css/style.css (блок «v13: крест-маркер»): #textbox::after → cross_mark, #next → next_mark
  const css = fs.readFileSync(path.join(ROOT, 'css', 'style.css'), 'utf8');
  const v13 = css.slice(css.indexOf('/* v13: крест-маркер'));
  for (const [sel, key] of [['#textbox::after', 'cross_mark'], ['#next', 'next_mark']]) {
    const blk = v13.slice(v13.indexOf(sel));
    const mm = /url\(data:image\/png;base64,([A-Za-z0-9+/=]+)\)/.exec(blk);
    if (!mm) throw new Error('css marker ' + sel);
    const buf = Buffer.from(mm[1], 'base64'); fs.writeFileSync(path.join(OUT, 'assets', 'ui', key + '.png'), buf);
    manifest.ui[key] = `res://assets/ui/${key}.png`; n++; bytes += buf.length;
  }
  fs.writeFileSync(path.join(OUT, 'data', 'assets_manifest.json'), JSON.stringify(manifest, null, 1) + '\n');
  console.log('assets:', n, 'files,', (bytes / 1e6).toFixed(1), 'MB');
}
