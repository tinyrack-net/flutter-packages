'use strict';

const path = require('node:path');

const browserName = process.argv[2];
const root = process.env.PLAYWRIGHT_ROOT;
const target = process.env.TERMWORLD_WEB_URL || 'http://127.0.0.1:8080';
if (!root || !['chromium', 'firefox', 'webkit'].includes(browserName)) {
  throw new Error('PLAYWRIGHT_ROOT and chromium|firefox|webkit are required');
}
const playwright = require(path.join(root, 'node_modules', 'playwright'));

(async () => {
  const browser = await playwright[browserName].launch({headless: true});
  const page = await browser.newPage({viewport: {width: 1000, height: 700}});
  const failures = [];
  page.on('pageerror', error => failures.push(`pageerror: ${error.stack}`));
  page.on('console', message => {
    if (message.type() === 'error') failures.push(`console: ${message.text()}`);
  });
  try {
    await page.goto(target, {waitUntil: 'networkidle'});
    const selector = 'canvas[data-termworld-webgl-renderer="active"]';
    await page.waitForSelector(selector, {state: 'attached', timeout: 60000});
    const renderer = await page.evaluate(selector => {
      const canvas = document.querySelector(selector);
      const gl = canvas?.getContext('webgl2');
      if (!canvas || !gl) return null;
      globalThis.__termworldCanvas = canvas;
      globalThis.__termworldLoseContext = gl.getExtension('WEBGL_lose_context');
      return {
        width: canvas.width,
        height: canvas.height,
        version: gl.getParameter(gl.VERSION),
        program: Boolean(gl.getParameter(gl.CURRENT_PROGRAM)),
        texture: Boolean(gl.getParameter(gl.TEXTURE_BINDING_2D)),
      };
    }, selector);
    if (!renderer || renderer.width <= 0 || renderer.height <= 0) {
      throw new Error(`WebGL renderer has invalid dimensions: ${JSON.stringify(renderer)}`);
    }
    if (!renderer.version.includes('WebGL 2') || !renderer.program || !renderer.texture) {
      throw new Error(`WebGL2 pipeline is incomplete: ${JSON.stringify(renderer)}`);
    }

    const canLoseContext = await page.evaluate(() => Boolean(globalThis.__termworldLoseContext));
    if (canLoseContext) {
      await page.evaluate(() => globalThis.__termworldLoseContext.loseContext());
      await page.waitForFunction(
        () => globalThis.__termworldCanvas?.dataset.termworldWebglRenderer === 'lost',
      );
      await page.evaluate(() => globalThis.__termworldLoseContext.restoreContext());
      await page.waitForSelector(selector, {state: 'attached', timeout: 30000});
    }
    if (failures.length) throw new Error(failures.join('\n'));
  } finally {
    await browser.close();
  }
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
