// Playwright MCP browser_run_code_unsafe; serve the current export on port 4187.
// Runtime health is automatic; inspect screenshots to verify gameplay outcomes.
async (page) => {
  const browser = await page.context().browser().browserType().launch({ headless: true, channel: 'chrome' });
  const report = { browser: browser.version(), cases: [] };
  const output = `/tmp/wanderlight-web-actions-${Date.now()}`;
  try {
    // Keep a clean user-facing baseline: synchronous WebGL wrappers can change
    // the very stalls being measured. Diagnostic runs are reported separately.
    for (const { scene, instrumentGL } of [
      { scene: 'house-route', instrumentGL: false },
      { scene: 'interior', instrumentGL: false },
      { scene: 'interior', instrumentGL: true },
      { scene: 'battle', instrumentGL: false },
    ]) {
      const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
      try {
        const testPage = await context.newPage();
        await testPage.addInitScript(instrumentGL => {
          window.__glTiming = {};
          if (!instrumentGL) return;
          for (const name of ['texImage2D', 'compressedTexImage2D', 'bufferData', 'compileShader', 'linkProgram', 'getProgramParameter', 'drawElements', 'drawArrays', 'readPixels']) {
            const original = WebGL2RenderingContext.prototype[name];
            WebGL2RenderingContext.prototype[name] = function (...args) {
              if (!window.__cadence?.active) return original.apply(this, args);
              const began = performance.now();
              const result = original.apply(this, args);
              const key = window.__cadence.phase + ':' + name;
              const metric = window.__glTiming[key] ||= { count: 0, totalMs: 0, maxMs: 0 };
              const elapsed = performance.now() - began;
              metric.count++;
              metric.totalMs += elapsed;
              metric.maxMs = Math.max(metric.maxMs, elapsed);
              return result;
            };
          }
        }, instrumentGL);
        const runName = `${scene}-${instrumentGL ? 'diagnostic' : 'baseline'}`;
        const result = { scene, instrumentGL, errors: [], profiles: [], screenshots: [] };
        testPage.on('pageerror', error => result.errors.push(error.message));
        testPage.on('console', message => {
          if (message.text().startsWith('MAP_BUILD_PROFILE')) result.profiles.push(message.text());
          if (message.type() === 'error' || message.text().includes('SCRIPT ERROR:')) result.errors.push(message.text());
        });
        await testPage.route('http://127.0.0.1:4187/', async route => {
          const response = await route.fetch();
          const html = await response.text();
          if (!html.includes('"args":[]')) throw new Error('Export argument injection point changed');
          await route.fulfill({ response, body: html.replace('"args":[]', '"args":' + JSON.stringify(['--', `--${scene}-preview`, '--mute-audio', '--profile-map-build'])) });
        });
        await testPage.goto('http://127.0.0.1:4187/');
        await testPage.waitForFunction(() => !document.getElementById('status'), null, { timeout: 45000 });
        await testPage.waitForTimeout(1000);
        const capture = async label => {
          const path = `${output}-${runName}-${label}.png`;
          await testPage.screenshot({ path });
          result.screenshots.push({ label, path });
        };
        await capture('before');
        await testPage.evaluate(() => {
          window.__cadence = { active: true, samples: [], byPhase: {}, slowFrames: [], phase: 'idle', last: null };
          const sample = now => {
            const probe = window.__cadence;
            if (probe.last !== null) {
              const interval = now - probe.last;
              probe.samples.push(interval);
              (probe.byPhase[probe.phase] ||= []).push(interval);
              if (interval > 50) probe.slowFrames.push({ phase: probe.phase, ms: interval });
            }
            probe.last = now;
            if (probe.active) requestAnimationFrame(sample);
          };
          requestAnimationFrame(sample);
        });
        const phase = label => testPage.evaluate(label => { window.__cadence.phase = label; }, label);
        if (scene === 'house-route') {
          await phase('first-enter-house');
          await testPage.keyboard.press('Space');
          await testPage.waitForTimeout(1800);
          await capture('first-entered');
        }
        if (scene === 'interior' || scene === 'house-route') {
          await phase('walk');
          await testPage.keyboard.down('w');
          await testPage.waitForTimeout(600);
          await testPage.keyboard.up('w');
          await capture('walked');
          await phase('return-walk');
          await testPage.keyboard.down('s');
          await testPage.waitForTimeout(600);
          await testPage.keyboard.up('s');
          await testPage.waitForTimeout(200);
          await phase('exit-to-village');
          await testPage.keyboard.press('Space');
          await testPage.waitForTimeout(1800);
          await capture('exit');
          await phase('reenter-house');
          await testPage.keyboard.press('Space');
          await testPage.waitForTimeout(1800);
          await capture('reentered');
          await phase('warm-exit-to-village');
          await testPage.keyboard.press('Space');
          await testPage.waitForTimeout(1800);
          await capture('warm-exit');
        } else {
          for (let actor = 0; actor < 2; actor++) {
            await phase(`normal-attack-${actor}`);
            await testPage.keyboard.press('1');
            await testPage.keyboard.press('Enter');
            await testPage.waitForTimeout(1100);
          }
          // Middle enemy card at the verified 1280x720 layout; select AoE after it
          // so the existing number shortcut moves focus back to Confirm.
          await testPage.mouse.click(820, 485);
          await testPage.keyboard.press('3');
          await capture('range');
          await phase('aoe-and-enemy-turn');
          await testPage.keyboard.press('Enter');
          await testPage.waitForTimeout(220);
          await capture('impact');
          await testPage.waitForTimeout(5500);
          await capture('round-end');
        }
        result.cadence = await testPage.evaluate(() => {
          window.__cadence.active = false;
          const samples = window.__cadence.samples.sort((a, b) => a - b);
          const byPhase = Object.fromEntries(Object.entries(window.__cadence.byPhase).map(([phase, frames]) => {
            frames.sort((a, b) => a - b);
            return [phase, { count: frames.length, p95Ms: frames[Math.floor(frames.length * 0.95)], maxMs: frames[frames.length - 1] }];
          }));
          return { count: samples.length, medianMs: samples[Math.floor(samples.length * 0.5)], p95Ms: samples[Math.floor(samples.length * 0.95)], maxMs: samples[samples.length - 1], over33ms: samples.filter(x => Math.round(x * 10) / 10 > 33.4).length, slowFrames: window.__cadence.slowFrames, byPhase };
        });
        result.runtimeClean = result.errors.length === 0;
        result.glTiming = await testPage.evaluate(() => Object.entries(window.__glTiming).sort((a, b) => b[1].totalMs - a[1].totalMs).slice(0, 12));
        report.cases.push(result);
      } finally { await context.close(); }
    }
    return report;
  } finally { await browser.close(); }
}
