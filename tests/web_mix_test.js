// Playwright MCP browser_run_code_unsafe; serve build/web on port 4187.
// Observe the sum of destination-bound audio, per channel, without changing it.
async (page) => {
  const browser = await page.context().browser().browserType().launch({ headless: true, channel: 'chrome' });
  const report = { browser: browser.version(), cases: [] };
  try {
    for (const { scene, streamLoops } of [
      { scene: 'village', streamLoops: false }, { scene: 'battle', streamLoops: false },
      { scene: 'village', streamLoops: true }, { scene: 'battle', streamLoops: true },
    ]) {
      const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
      try {
        const tab = await context.newPage();
        const result = { scene, streamLoops, errors: [] };
        tab.on('pageerror', error => result.errors.push(error.message));
        tab.on('console', message => { if (message.type() === 'error') result.errors.push(message.text()); });
        await tab.addInitScript(() => {
          const originalConnect = AudioNode.prototype.connect;
          const destinations = new Map();
          const channels = [];
          window.__mixProbe = { channels, phase: 'idle', phases: {}, active: false };
          AudioNode.prototype.connect = function (...args) {
            const connected = originalConnect.apply(this, args);
            if (args[0] instanceof AudioDestinationNode) {
              let splitter = destinations.get(args[0]);
              if (!splitter) {
                splitter = this.context.createChannelSplitter(2);
                destinations.set(args[0], splitter);
                for (let channel = 0; channel < 2; channel++) {
                  const analyser = this.context.createAnalyser();
                  analyser.fftSize = 2048;
                  const silent = this.context.createGain();
                  silent.gain.value = 0;
                  originalConnect.call(splitter, analyser, channel, 0);
                  originalConnect.call(analyser, silent);
                  originalConnect.call(silent, this.context.destination);
                  channels.push(analyser);
                }
              }
              originalConnect.call(this, splitter, args[1] || 0, 0);
            }
            return connected;
          };
          setInterval(() => {
            const probe = window.__mixProbe;
            if (!probe.active) return;
            const metrics = probe.phases[probe.phase] ||= channels.map(() => ({ peak: 0, energy: 0, samples: 0, nearFullScale: 0, windows: 0, silentWindows: 0 }));
            channels.forEach((analyser, index) => {
              const metric = metrics[index];
              if (!metric) return;
              const samples = new Float32Array(analyser.fftSize);
              analyser.getFloatTimeDomainData(samples);
              metric.windows++;
              let windowPeak = 0;
              for (const value of samples) {
                windowPeak = Math.max(windowPeak, Math.abs(value));
                metric.peak = Math.max(metric.peak, Math.abs(value));
                metric.energy += value * value;
                metric.samples++;
                if (Math.abs(value) >= 0.999) metric.nearFullScale++;
              }
              if (windowPeak < 0.00001) metric.silentWindows++;
            });
          }, 10);
        });
        await tab.route('http://127.0.0.1:4187/', async route => {
          const response = await route.fetch();
          const html = await response.text();
          if (!html.includes('"args":[]')) throw new Error('Missing export argument injection point');
          const args = ['--', `--${scene === 'village' ? 'house-route' : scene}-preview`];
          if (streamLoops) args.push('--stream-loop-audio');
          await route.fulfill({ response, body: html.replace('"args":[]', '"args":' + JSON.stringify(args)) });
        });
        await tab.goto('http://127.0.0.1:4187/');
        await tab.waitForFunction(() => !document.getElementById('status'), null, { timeout: 45000 });
        await tab.locator('canvas').click({ position: { x: 20, y: 20 } });
        await tab.waitForTimeout(500);
        const phase = async name => tab.evaluate(name => {
          window.__mixProbe.phase = name;
          window.__mixProbe.active = true;
        }, name);
        await phase('background');
        await tab.waitForTimeout(3000);
        if (scene === 'battle') {
          for (let actor = 0; actor < 2; actor++) {
            await phase(`attack-${actor}`);
            await tab.keyboard.press('1');
            await tab.keyboard.press('Enter');
            await tab.waitForTimeout(1100);
          }
          await phase('aoe-enemy-round');
          // Center enemy places all three opponents within the AoE preview.
          await tab.mouse.click(820, 485);
          await tab.keyboard.press('3');
          await tab.keyboard.press('Enter');
          await tab.waitForTimeout(6500);
        } else {
          await phase('loop-boundaries');
          await tab.waitForTimeout(26000);
          await phase('first-enter-house');
          await tab.keyboard.press('Space');
          await tab.waitForTimeout(2000);
          await phase('return-to-village');
          await tab.keyboard.press('Space');
          await tab.waitForTimeout(2000);
          await phase('walk-with-background');
          await tab.keyboard.down('w');
          await tab.waitForTimeout(1000);
          await tab.keyboard.up('w');
          await tab.waitForTimeout(1000);
        }
        result.phases = await tab.evaluate(() => {
          window.__mixProbe.active = false;
          return Object.fromEntries(Object.entries(window.__mixProbe.phases).map(([phase, channels]) => [phase,
            channels.map(({ peak, energy, samples, nearFullScale, windows, silentWindows }) => ({ peak, rms: Math.sqrt(energy / Math.max(1, samples)), samples, nearFullScale, windows, silentWindows }))]));
        });
        result.screenshot = `/tmp/wanderlight-mix-${scene}-${Date.now()}.png`;
        await tab.screenshot({ path: result.screenshot });
        const values = Object.values(result.phases).flat();
        result.observedOutput = values.length >= 2 && values.every(value => value.samples > 0) && values.some(value => value.peak > 0.001);
        result.noObservedFullScale = values.length > 0 && values.every(value => value.nearFullScale === 0);
        // Windows overlap and timer polling can miss samples. This is a diagnostic,
        // not proof of gapless playback, subjective balance, or absence of clipping.
        report.cases.push(result);
      } finally { await context.close(); }
    }
    return report;
  } finally { await browser.close(); }
}
