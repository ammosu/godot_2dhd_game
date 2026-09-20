// Serve build/web at 127.0.0.1:4193. Run with Playwright MCP filename.
// Isolated browser contexts; preview mode suppresses autosaves.
async (page) => {
  const browser = await page.context().browser().browserType().launch({headless: true, channel: 'chrome'});
  const report = {browser: browser.version(), scenes: []};
  const prefix = `/tmp/wanderlight-web-story-${Date.now()}`;
  try {
    for (const scene of ['memory', 'ending', 'shard']) {
      const context = await browser.newContext({viewport: {width: 1280, height: 720}});
      try {
        const testPage = await context.newPage();
        const result = {scene, errors: [], screenshots: [], loaded: false};
        testPage.on('pageerror', e => result.errors.push(e.message));
        testPage.on('console', message => {
          const text = message.text();
          if (message.type() === 'error' || /SCRIPT ERROR:|ERROR:/.test(text)) result.errors.push(text);
          if (text.includes('Wanderlight playable slice loaded')) result.loaded = true;
        });
        await testPage.route('http://127.0.0.1:4193/', async route => {
          const response = await route.fetch();
          const html = await response.text();
          if (!html.includes('"args":[]')) throw new Error('Missing argument injection point');
          await route.fulfill({response, body: html.replace('"args":[]', '"args":' + JSON.stringify(['--', '--story-preview', `--story-${scene}`, '--mute-audio']))});
        });
        await testPage.goto('http://127.0.0.1:4193/');
        await testPage.waitForFunction(() => !document.getElementById('status'), null, {timeout: 45000});
        await testPage.waitForTimeout(2000);
        const capture = async label => {
          const path = `${prefix}-${scene}-${label}.png`;
          await testPage.screenshot({path});
          result.screenshots.push(path);
        };
        await capture('first');
        const pages = scene === 'ending' ? 8 : 2;
        for (let i = 1; i <= pages; i++) {
          await testPage.keyboard.press('Space');
          await testPage.waitForTimeout(180);
          if (scene === 'ending' && [2, 5].includes(i)) {
            await capture(`page-${i}`);
            await testPage.waitForTimeout(1600);
            await capture(`page-${i}-settled`);
          }
        }
        await capture('closed');
        result.contextLost = await testPage.locator('canvas').evaluate(c => c.getContext('webgl2')?.isContextLost() ?? true);
        result.runtimeClean = result.loaded && !result.contextLost && result.errors.length === 0;
        report.scenes.push(result);
      } finally { await context.close(); }
    }
    report.runtimeClean = report.scenes.every(s => s.runtimeClean);
    return report;
  } finally { await browser.close(); }
}
