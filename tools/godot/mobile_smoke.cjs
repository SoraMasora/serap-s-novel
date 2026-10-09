// Смоук мобильной веб-сборки Godot в headless Chromium с эмуляцией телефона (касания, альбомная ориентация).
// Запуск: (cd godot/build/web && python3 -m http.server 8765 &) ; NODE_PATH=<node_modules> node tools/godot/mobile_smoke.cjs [outdir]
// env: VW/VH — размер экрана в CSS-пикселях (по умолчанию 844×390, iPhone 13 в альбомной), DSF — плотность,
//      STEPS — JSON [[x, y, name|null, waitMs, keys?, kind?]] в долях экрана (0..1); kind: 'tap' | 'hold:<ms>' | 'drag:<dx>,<dy>,<ms>'
'use strict';
const { chromium, devices } = require('playwright');
const fs = require('fs');
const out = process.argv[2] || 'shots/mobile';
fs.mkdirSync(out, { recursive: true });
(async () => {
  const W = +(process.env.VW || 844), H = +(process.env.VH || 390);
  const b = await chromium.launch({ executablePath: process.env.CHR || (fs.existsSync('/usr/local/bin/chromium') ? '/usr/local/bin/chromium' : undefined),
    args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required'] });
  const ctx = await b.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: +(process.env.DSF || 1), isMobile: true, hasTouch: true,
    userAgent: process.env.UA || devices['Pixel 7'].userAgent });
  const page = await ctx.newPage();
  const errors = [], logs = [];
  page.on('console', m => { const t = m.text(); logs.push(`[${m.type()}] ${t}`); if (m.type() === 'error' || /SCRIPT ERROR|^ERROR|USER ERROR/.test(t)) errors.push(t); });
  page.on('pageerror', e => errors.push('PAGEERROR ' + e.message));
  const t0 = Date.now();
  await page.goto('http://127.0.0.1:8765/index.html');
  await page.waitForFunction(() => { const c = document.querySelector('canvas'); return c && c.width > 0; }, null, { timeout: 120000 });
  await page.waitForTimeout(+(process.env.BOOT_WAIT || 12000));
  console.log('boot_ms', Date.now() - t0);
  await page.screenshot({ path: `${out}/01_title.png` });
  const cdp = await ctx.newCDPSession(page);
  const touch = (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts });
  const steps = JSON.parse(process.env.STEPS || '[]');
  let k = 2;
  for (const [fx, fy, name, wait, keys, kind] of steps) {
    if (fx != null) {
      const x = fx * W, y = fy * H, kd = kind || 'tap';
      if (kd === 'tap') { await touch('touchStart', [{ x, y, id: 1 }]); await page.waitForTimeout(60); await touch('touchEnd', []); }
      else if (kd.startsWith('hold:')) { await touch('touchStart', [{ x, y, id: 1 }]); await page.waitForTimeout(+kd.slice(5)); await touch('touchEnd', []); }
      else if (kd.startsWith('drag:')) { const [dx, dy, ms] = kd.slice(5).split(',').map(Number);
        await touch('touchStart', [{ x, y, id: 1 }]);
        for (let i = 1; i <= 8; i++) { await touch('touchMove', [{ x: x + dx * W * i / 8, y: y + dy * H * i / 8, id: 1 }]); await page.waitForTimeout(30); }
        await page.waitForTimeout(ms || 800); if (name) await page.screenshot({ path: `${out}/${String(k++).padStart(2, '0')}_${name}_hold.png` });
        await touch('touchEnd', []); }
    }
    if (keys) await page.keyboard.type(keys);
    await page.waitForTimeout(wait || 1500);
    if (name) await page.screenshot({ path: `${out}/${String(k++).padStart(2, '0')}_${name}.png` });
  }
  fs.writeFileSync(`${out}/console.log`, logs.join('\n'));
  console.log('ERRORS', errors.length ? JSON.stringify(errors.slice(0, 20)) : 'none');
  await page.close(); await b.close(); process.exit(0);
})().catch(e => { console.error(e); process.exit(1); });
