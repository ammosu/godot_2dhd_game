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
      window.__audioProbe = { contexts: [], analysers: [], starts: [], schedules: [] };
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
        window.__audioProbe.schedules.push({
          buffer: this.buffer,
          calledAt: this.context.currentTime,
          scheduledAt: Math.max(this.context.currentTime, args[0] || 0),
          offset: args[1] || 0,
          duration: args[2] ?? this.buffer?.duration,
          rate: this.playbackRate.value,
        });
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
    report.loopScheduling = (await cdp.send('Runtime.evaluate', {
      userGesture: false, returnByValue: true,
      expression: '(' + (() => {
        const records = window.__audioProbe.schedules;
        const samePCM = (a, b) => {
          if (a === b) return true;
          if (!a || !b || a.length !== b.length || a.sampleRate !== b.sampleRate || a.numberOfChannels !== b.numberOfChannels) return false;
          for (let channel = 0; channel < a.numberOfChannels; channel++) {
            const left = a.getChannelData(channel), right = b.getChannelData(channel);
            for (let sample = 0; sample < left.length; sample++) if (left[sample] !== right[sample]) return false;
          }
          return true;
        };
        return [24, 11.5].map(duration => {
          const matching = records.filter(record => Math.abs((record.buffer?.duration || 0) - duration) < 0.01);
          const transitions = [];
          for (let index = 1; index < matching.length; index++) {
            const previous = matching[index - 1];
            const current = matching[index];
            // The backend may copy buffers at restart. Compare every PCM sample
            // after playback sampling, never by duration alone or on the hot path.
            if (!samePCM(previous.buffer, current.buffer) || previous.rate !== 1 || current.rate !== 1) continue;
            const previousEnd = previous.scheduledAt + Math.min(previous.duration, previous.buffer.duration - previous.offset);
            transitions.push({ gapMs: (current.scheduledAt - previousEnd) * 1000,
              schedulingLeadMs: (current.scheduledAt - current.calledAt) * 1000 });
          }
          return { duration, starts: matching.length, transitions };
        });
      }).toString() + ')()',
    })).result.value;
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
      loopSchedulingObserved: report.loopScheduling.every(loop => loop.transitions.length > 0),
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
