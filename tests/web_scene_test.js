// Run through Playwright MCP browser_run_code_unsafe(filename: absolute path).
// Serve build/web on 127.0.0.1:4187. Preview args are injected only into the
// intercepted HTML response; exported files and normal browser saves stay intact.
async (page) => {
  const browser = await page.context().browser().browserType().launch({ headless: true, channel: 'chrome' });
  const report = { browser: browser.version(), viewport: [1280, 720], scenes: [] };
  const output = `/tmp/wanderlight-web-scenes-${Date.now()}`;
  try {
    for (const scene of ['village', 'interior', 'ruins', 'battle']) {
      const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
      try {
        const testPage = await context.newPage();
        const result = { scene, errors: [], warnings: [], loaded: false };
        testPage.on('pageerror', error => result.errors.push(error.message));
        testPage.on('console', message => {
          const text = message.text();
          if (message.type() === 'error' || text.includes('SCRIPT ERROR:') || text.startsWith('ERROR:')) result.errors.push(text);
          if (message.type() === 'warning') result.warnings.push(text);
          if (text.includes('Wanderlight playable slice loaded')) result.loaded = true;
        });
        await testPage.route('http://127.0.0.1:4187/', async route => {
          const response = await route.fetch();
          const html = await response.text();
          if (!html.includes('"args":[]')) throw new Error('Export argument injection point changed');
          await route.fulfill({ response, body: html.replace('"args":[]', '"args":' + JSON.stringify(['--', `--${scene}-preview`, '--mute-audio'])) });
        });
        const began = Date.now();
        await testPage.goto('http://127.0.0.1:4187/');
        await testPage.waitForFunction(() => !document.getElementById('status'), null, { timeout: 45000 });
        result.startupMs = Date.now() - began;
        await testPage.waitForTimeout(2500);
        result.cadence = await testPage.evaluate(async () => {
          const intervals = [];
          let last = performance.now();
          const until = last + 3000;
          await new Promise(resolve => {
            const sample = now => {
              intervals.push(now - last);
              last = now;
              if (now < until) requestAnimationFrame(sample); else resolve();
            };
            requestAnimationFrame(sample);
          });
          intervals.shift();
          intervals.sort((a, b) => a - b);
          return { samples: intervals.length, medianMs: intervals[Math.floor(intervals.length * 0.5)], p95Ms: intervals[Math.floor(intervals.length * 0.95)], over33ms: intervals.filter(x => x > 33.4).length };
        });
        result.canvas = await testPage.locator('canvas').evaluate(canvas => {
          const gl = canvas.getContext('webgl2');
          const debug = gl?.getExtension('WEBGL_debug_renderer_info');
          return { width: canvas.width, height: canvas.height, renderer: debug ? gl.getParameter(debug.UNMASKED_RENDERER_WEBGL) : 'unavailable', contextLost: gl?.isContextLost() ?? true };
        });
        result.screenshot = `${output}-${scene}.png`;
        await testPage.screenshot({ path: result.screenshot });
        result.pass = result.loaded && result.errors.length === 0 && !result.canvas.contextLost && result.cadence.samples > 10;
        report.scenes.push(result);
      } finally {
        await context.close();
      }
    }
    report.pass = report.scenes.every(scene => scene.pass);
    return report;
  } finally {
    await browser.close();
  }
}
