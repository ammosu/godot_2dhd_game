// Independent audio-thread diagnostic, not subjective listening approval.
// Playwright MCP; serve the current export on 127.0.0.1:4187.
async (page) => {
  const browser = await page.context().browser().browserType().launch({ headless: true, channel: 'chrome' });
  const reports = [];
  try {
    for (const streamLoops of [false, true]) {
      const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
      try {
        const tab = await context.newPage();
        const result = { streamLoops, errors: [] };
        tab.on('pageerror', e => result.errors.push(e.message));
        tab.on('console', m => { if (m.type() === 'error') result.errors.push(m.text()); });
        await tab.addInitScript(() => {
          const connect = AudioNode.prototype.connect;
          const contexts = new Map();
          window.__capture = { nodes: [], results: [], errors: [] };
          const source = `class Capture extends AudioWorkletProcessor {
            constructor() {
              super(); this.active = false; this.frames = 0; this.peak = 0;
              this.silent = 0; this.maxSilent = 0; this.maxSilentAt = 0;
              this.port.onmessage = e => {
                if (e.data === 'start') { this.active = true; this.start = currentFrame; }
                if (e.data === 'stop') {
                  this.active = false;
                  this.port.postMessage({ frames: this.frames, sampleRate,
                    peak: this.peak, maxSilentMs: this.maxSilent * 1000 / sampleRate,
                    maxSilentAtSeconds: (this.maxSilentAt - this.start) / sampleRate });
                }
              };
            }
            process(inputs) {
              if (!this.active) return true;
              const channels = inputs[0];
              const count = channels[0]?.length || 128;
              for (let frame = 0; frame < count; frame++) {
                let peak = 0;
                for (const channel of channels) peak = Math.max(peak, Math.abs(channel[frame]));
                this.peak = Math.max(this.peak, peak);
                this.silent = peak < 0.00001 ? this.silent + 1 : 0;
                if (this.silent > this.maxSilent) {
                  this.maxSilent = this.silent; this.maxSilentAt = currentFrame + frame;
                }
                this.frames++;
              }
              return true; // Output stays zero: observation never doubles volume.
            }
          } registerProcessor('capture', Capture);`;
          AudioNode.prototype.connect = function (...args) {
            const output = connect.apply(this, args);
            if (!(args[0] instanceof AudioDestinationNode)) return output;
            let entry = contexts.get(this.context);
            if (!entry) {
              entry = { pending: [], node: null };
              contexts.set(this.context, entry);
              const url = URL.createObjectURL(new Blob([source], { type: 'text/javascript' }));
              this.context.audioWorklet.addModule(url).then(() => {
                entry.node = new AudioWorkletNode(this.context, 'capture', { numberOfInputs: 1, numberOfOutputs: 1, outputChannelCount: [2] });
                entry.node.port.onmessage = event => window.__capture.results.push(event.data);
                connect.call(entry.node, this.context.destination);
                for (const [node, channel] of entry.pending) connect.call(node, entry.node, channel, 0);
                entry.pending = [];
                window.__capture.nodes.push(entry.node);
              }).catch(error => window.__capture.errors.push(String(error))).finally(() => URL.revokeObjectURL(url));
            }
            if (entry.node) connect.call(this, entry.node, args[1] || 0, 0);
            else entry.pending.push([this, args[1] || 0]);
            return output;
          };
        });
        await tab.route('http://127.0.0.1:4187/', async route => {
          const response = await route.fetch(), html = await response.text();
          if (!html.includes('"args":[]')) throw new Error('Missing export arguments');
          const args = ['--', '--house-route-preview'];
          if (streamLoops) args.push('--stream-loop-audio');
          await route.fulfill({ response, body: html.replace('"args":[]', '"args":' + JSON.stringify(args)) });
        });
        await tab.goto('http://127.0.0.1:4187/');
        await tab.waitForFunction(() => !document.getElementById('status') && window.__capture.nodes.length > 0, null, { timeout: 45000 });
        await tab.locator('canvas').click({ position: { x: 20, y: 20 } });
        await tab.waitForTimeout(1000);
        await tab.evaluate(() => window.__capture.nodes.forEach(node => node.port.postMessage('start')));
        await tab.waitForTimeout(26000);
        await tab.keyboard.press('Space');
        await tab.waitForTimeout(2000);
        result.inside = `/tmp/audio-capture-${streamLoops}-inside-${Date.now()}.png`;
        await tab.screenshot({ path: result.inside });
        await tab.keyboard.press('Space');
        await tab.waitForTimeout(2000);
        await tab.evaluate(() => window.__capture.nodes.forEach(node => node.port.postMessage('stop')));
        await tab.waitForFunction(() => window.__capture.results.length === window.__capture.nodes.length);
        Object.assign(result, await tab.evaluate(() => ({ capture: window.__capture.results, captureErrors: window.__capture.errors })));
        reports.push(result);
      } finally { await context.close(); }
    }
    return reports;
  } finally { await browser.close(); }
}
