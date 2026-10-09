// Дымовой тест веб-сборки Godot в headless Chromium: загрузка, титул, новая игра, реплики, скриншоты.
// Запуск: (cd godot/build/web && python3 -m http.server 8765 &) ; NODE_PATH=/vercel/sandbox/node_modules node tools/godot/web_smoke.cjs [outdir]
'use strict';
const { chromium } = require('playwright');
const out = process.argv[2] || 'shots/godot';
require('fs').mkdirSync(out, { recursive: true });
(async () => {
  const b = await chromium.launch({ executablePath: process.env.CHR || '/usr/local/bin/chromium',
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required'] });
  const page = await b.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [], logs = [];
  page.on('console', m => { const t = m.text(); logs.push(`[${m.type()}] ${t}`); if (m.type() === 'error' || /SCRIPT ERROR|^ERROR/.test(t)) errors.push(t); });
  page.on('pageerror', e => errors.push('PAGEERROR ' + e.message));
  const t0 = Date.now();
  await page.goto('http://127.0.0.1:8765/index.html');
  await page.waitForFunction(() => { const c = document.querySelector('canvas'); return c && c.width > 0; }, null, { timeout: 120000 });
  await page.waitForTimeout(12000);
  console.log('boot_ms', Date.now() - t0);
  await page.screenshot({ path: `${out}/01_title.png` });
  const steps = JSON.parse(process.env.STEPS || '[]'); // [[x,y,'name'|null, waitMs, keys?]]
  let k = 2;
  for (const [x, y, name, wait, keys] of steps) {
    if (x != null) await page.mouse.click(x, y);
    if (keys) await page.keyboard.type(keys);
    await page.waitForTimeout(wait || 1500);
    if (name) await page.screenshot({ path: `${out}/${String(k++).padStart(2, '0')}_${name}.png` });
  }
  require('fs').writeFileSync(`${out}/console.log`, logs.join('\n'));
  console.log('ERRORS', errors.length ? JSON.stringify(errors.slice(0, 20)) : 'none');
  await page.close(); await b.close(); process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
