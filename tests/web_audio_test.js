// Run with Playwright MCP browser_run_code_unsafe(filename: absolute path).
// Serve the current Web export at http://127.0.0.1:4187 first.
// Uses a separate browser/profile; never writes the player's normal preferences.
async (page) => {
  const browser = await page.context().browser().browserType().launch({
    headless: true,
    channel: 'chrome',
    args: ['--autoplay-policy=document-user-activation-required'],
  });
  const report = { browser: browser.version(), errors: [] };
  try {
    const testPage = await browser.newPage({ viewport: { width: 1280, height: 720 } });
    const cdp = await testPage.context().newCDPSession(testPage);
    testPage.on('pageerror', error => report.errors.push(error.message));
    testPage.on('console', message => {
      if (message.type() === 'error') report.errors.push(message.text());
    });
    await testPage.addInitScript(() => {
      window.__audioProbe = { contexts: [], analysers: [], starts: [] };
      const Original = window.AudioContext;
      window.AudioContext = new Proxy(Original, {
        construct(Target, args) {
          const context = new Target(...args);
          window.__audioProbe.contexts.push(context);
          return context;
        },
      });
      const connect = AudioNode.prototype.connect;
      AudioNode.prototype.connect = function (...args) {
        const result = connect.apply(this, args);
        if (args[0] instanceof AudioDestinationNode) {
          const analyser = this.context.createAnalyser();
          analyser.fftSize = 2048;
          connect.call(this, analyser);
          // Keep the observer graph active with a silent output branch.
          const silent = this.context.createGain();
          silent.gain.value = 0;
          connect.call(analyser, silent);
          connect.call(silent, this.context.destination);
          window.__audioProbe.analysers.push(analyser);
        }
        return result;
      };
      const start = AudioBufferSourceNode.prototype.start;
      AudioBufferSourceNode.prototype.start = function (...args) {
        window.__audioProbe.starts.push(this);
        return start.apply(this, args);
      };
    });
    await testPage.goto('http://127.0.0.1:4187/');
    const deadline = Date.now() + 30000;
    while (Date.now() < deadline) {
      const ready = await cdp.send('Runtime.evaluate', {
        expression: 'Boolean(window.__audioProbe?.starts.length >= 2)',
        userGesture: false, returnByValue: true,
      });
      if (ready.result.value) break;
      await testPage.waitForTimeout(200);
    }
    // Playwright evaluate grants a synthetic user gesture. CDP explicitly does not.
    const read = async () => (await cdp.send('Runtime.evaluate', {
      userGesture: false, awaitPromise: true, returnByValue: true,
      expression: '(' + (async () => {
      let peak = 0;
      const end = performance.now() + 1200;
      while (performance.now() < end) {
        for (const analyser of window.__audioProbe.analysers) {
          const samples = new Float32Array(analyser.fftSize);
          analyser.getFloatTimeDomainData(samples);
          for (const sample of samples) peak = Math.max(peak, Math.abs(sample));
        }
        await new Promise(resolve => setTimeout(resolve, 25));
      }
      return {
        states: window.__audioProbe.contexts.map(context => context.state),
        activated: navigator.userActivation.hasBeenActive,
        analysers: window.__audioProbe.analysers.length,
        starts: window.__audioProbe.starts.map(source => ({duration: source.buffer?.duration, loop: source.loop,
          bufferPeak: Math.max(...source.buffer.getChannelData(0).slice(0, 16000).map(Math.abs))})),
        peak,
      };
      }).toString() + ')()',
    })).result.value;
    report.beforeGesture = await read();
    await testPage.locator('canvas').click();
    report.afterGesture = await read();
    await testPage.keyboard.press('m');
    // Exclude already-buffered samples when checking mute.
    await testPage.waitForTimeout(300);
    report.muted = await read();
    await testPage.keyboard.press('m');
    report.unmuted = await read();
    await testPage.keyboard.press('Space');
    report.afterDialogue = await read();
    // Godot's Web sample backend restarts sources at loop end instead of setting
    // AudioBufferSourceNode.loop. Verify actual repeats beyond the longest loop.
    await testPage.waitForTimeout(25000);
    report.afterLoopBoundary = await read();
    const checks = {
      gestureRequired: report.beforeGesture.states.length === 1 && !report.beforeGesture.activated
        && report.beforeGesture.states.every(state => state === 'suspended'),
      silentBeforeGesture: report.beforeGesture.peak === 0,
      runningAfterGesture: report.afterGesture.states.every(state => state === 'running'),
      audibleAfterGesture: report.afterGesture.peak > 0.001,
      muted: report.muted.peak < 0.00001,
      resumed: report.unmuted.peak > 0.001,
      musicLoop: report.afterLoopBoundary.starts.filter(source => Math.abs(source.duration - 24) < 0.01).length >= 2,
      ambienceLoop: report.afterLoopBoundary.starts.filter(source => Math.abs(source.duration - 11.5) < 0.01).length >= 2,
      audibleAfterLoopBoundary: report.afterLoopBoundary.peak > 0.001,
      dialogueCue: report.afterDialogue.starts.filter(source => Math.abs(source.duration - 0.14) < 0.01).length
        > report.unmuted.starts.filter(source => Math.abs(source.duration - 0.14) < 0.01).length,
      noRuntimeErrors: report.errors.length === 0,
    };
    report.checks = checks;
    report.pass = Object.values(checks).every(Boolean);
    return report;
  } finally {
    await browser.close();
  }
}
