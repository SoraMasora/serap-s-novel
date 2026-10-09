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
for (const s of ['js/story.js', 'js/story3.js']) vm.runInContext(fs.readFileSync(path.join(ROOT, s), 'utf8'), ctx, { filename: s });
vm.runInContext('this.__o = { STORY, ENDINGS, pickEnding: pickEnding.toString() };', ctx);
const { STORY, ENDINGS, pickEnding } = ctx.__o;

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
function conv(c) {
  if (Array.isArray(c)) { const o = { say: [c[0], c[1] === undefined ? null : c[1]] }; if (c.length > 2) o.say.push(c[2]); return o; }
  const o = {};
  for (const [k, v] of Object.entries(c)) o[k] = (k === 'when') ? condFromFn(v) : v;
  return o;
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
const story = { version: 1, source: 'js/story.js + js/story3.js', start: 'start', notes_total: notes.size, ending_rules: rules, endings: ENDINGS, scenes };
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
  fs.writeFileSync(path.join(OUT, 'data', 'assets_manifest.json'), JSON.stringify(manifest, null, 1) + '\n');
  console.log('assets:', n, 'files,', (bytes / 1e6).toFixed(1), 'MB');
}
