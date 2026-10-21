'use strict';

// node tests/browser-smoke.cjs
// Optional: PLAYWRIGHT_MODULE=/path/to/playwright
//           PLAYWRIGHT_CHROMIUM_EXECUTABLE=/path/to/chrome
//           SYMBIONT_WEB_DIR=/path/to/export
// Tests only a fresh browser profile; the native Godot save is not used.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const fsp = require('node:fs/promises');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');

const project = path.resolve(__dirname, '..');
const webRoot = path.resolve(process.env.SYMBIONT_WEB_DIR || path.join(project, 'build', 'web'));
const diagnostics = path.join(project, 'artifacts', 'browser-smoke');
const screenshots = path.join(project, 'artifacts', 'screenshots');
let desktopStickPixels;

function loadPlaywright() {
  const candidates = [
    process.env.PLAYWRIGHT_MODULE,
    path.join(project, 'node_modules', 'playwright'),
    'playwright',
    path.resolve(project, '..', 'indie-forge', 'node_modules', 'playwright'),
  ].filter(Boolean);
  for (const candidate of candidates) {
    try { return require(candidate); } catch (error) {
      if (process.env.PLAYWRIGHT_MODULE === candidate) throw error;
    }
  }
  throw new Error('Playwright was not found. Set PLAYWRIGHT_MODULE to the installed package.');
}

function findBrowser(chromium) {
  const candidates = [process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE, chromium.executablePath()];
  const cache = process.env.PLAYWRIGHT_BROWSERS_PATH || path.join(process.env.LOCALAPPDATA || '', 'ms-playwright');
  if (fs.existsSync(cache)) {
    for (const directory of fs.readdirSync(cache).filter(name => /^chromium-\d+$/.test(name)).sort().reverse()) {
      candidates.push(path.join(cache, directory, 'chrome-win64', 'chrome.exe'));
      candidates.push(path.join(cache, directory, 'chrome-win', 'chrome.exe'));
      candidates.push(path.join(cache, directory, 'chrome-linux64', 'chrome'));
      candidates.push(path.join(cache, directory, 'chrome-mac', 'Chromium.app', 'Contents', 'MacOS', 'Chromium'));
    }
  }
  candidates.push(
    path.join(process.env.PROGRAMFILES || 'C:\\Program Files', 'Google', 'Chrome', 'Application', 'chrome.exe'),
    path.join(process.env['PROGRAMFILES(X86)'] || 'C:\\Program Files (x86)', 'Microsoft', 'Edge', 'Application', 'msedge.exe'),
    '/usr/bin/chromium', '/usr/bin/chromium-browser', '/usr/bin/google-chrome',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  );
  const executable = candidates.find(candidate => candidate && fs.existsSync(candidate));
  if (!executable) throw new Error('No Chromium browser found. Install Playwright Chromium or set PLAYWRIGHT_CHROMIUM_EXECUTABLE.');
  return executable;
}

async function startServer() {
  const mime = { '.html': 'text/html; charset=utf-8', '.js': 'application/javascript', '.wasm': 'application/wasm', '.png': 'image/png', '.pck': 'application/octet-stream' };
  const server = http.createServer(async (request, response) => {
    try {
      const pathname = decodeURIComponent(new URL(request.url, 'http://127.0.0.1').pathname);
      if (pathname === '/favicon.ico') { response.writeHead(204); response.end(); return; }
      const filename = path.resolve(webRoot, '.' + (pathname === '/' ? '/index.html' : pathname));
      if (filename !== webRoot && !filename.startsWith(webRoot + path.sep)) {
        response.writeHead(403); response.end(); return;
      }
      const stat = await fsp.stat(filename);
      if (!stat.isFile()) { response.writeHead(404); response.end(); return; }
      response.writeHead(200, {
        'Content-Type': mime[path.extname(filename)] || 'application/octet-stream',
        'Content-Length': stat.size,
        'Cache-Control': 'no-store',
      });
      if (request.method === 'HEAD') { response.end(); return; }
      fs.createReadStream(filename).on('error', () => response.destroy()).pipe(response);
    } catch {
      response.writeHead(404); response.end();
    }
  });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  return { server, url: `http://127.0.0.1:${server.address().port}/` };
}

const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

async function framePixels(page, buffer, region = { x: 200, y: 150, width: 850, height: 425, step: 5 }) {
  // Decode the actual compositor screenshot, avoiding WebGL back-buffer timing.
  return page.evaluate(async ({ data, region }) => {
    const image = new Image();
    image.src = 'data:image/png;base64,' + data;
    await image.decode();
    const canvas = document.createElement('canvas');
    canvas.width = image.width;
    canvas.height = image.height;
    const context = canvas.getContext('2d');
    context.drawImage(image, 0, 0);
    const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
    const result = [];
    // Ignore HUD and screen edges. A few animated organs cannot satisfy the
    // large changed-area threshold used for movement and modal transitions.
    for (let y = region.y; y < region.y + region.height; y += region.step) {
      for (let x = region.x; x < region.x + region.width; x += region.step) {
        const i = (y * canvas.width + x) * 4;
        result.push(pixels[i], pixels[i + 1], pixels[i + 2]);
      }
    }
    return result;
  }, { data: buffer.toString('base64'), region });
}

function hostMarker(pixels) {
  // The host's purple organic armour is unique in the clear starting area.
  // Track its image position while the camera remains clamped at the left edge.
  const points = [];
  for (let row = 0; row < 85; row++) {
    for (let column = 0; column < 170; column++) {
      const x = 200 + column * 5;
      const y = 150 + row * 5;
      if (x < 300 || x >= 700 || y < 300 || y >= 425) continue;
      const i = (row * 170 + column) * 3;
      const [r, g, b] = pixels.slice(i, i + 3);
      if (r > 42 && b > 42 && g < Math.min(r, b) * .72 && b > r * .72 && r > b * .48) points.push({ x, y });
    }
  }
  assert(points.length >= 3, 'Host armour marker was not visible in the mission starting area');
  const median = values => values.sort((a, b) => a - b)[Math.floor(values.length / 2)];
  return { x: median(points.map(p => p.x)), y: median(points.map(p => p.y)), samples: points.length };
}

function difference(a, b) {
  assert.equal(a.length, b.length);
  let changed = 0;
  let total = 0;
  for (let i = 0; i < a.length; i += 3) {
    const value = (Math.abs(a[i] - b[i]) + Math.abs(a[i + 1] - b[i + 1]) + Math.abs(a[i + 2] - b[i + 2])) / 3;
    total += value;
    if (value > 12) changed++;
  }
  return { changedFraction: changed / (a.length / 3), meanDelta: total / (a.length / 3) };
}

async function keyHold(page, key, milliseconds) {
  await page.keyboard.down(key);
  try { await delay(milliseconds); } finally { await page.keyboard.up(key); }
}

async function runContext(browser, url, mobile) {
  const name = mobile ? 'touch' : 'desktop';
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    hasTouch: mobile,
    isMobile: mobile,
    ...(mobile ? { userAgent: 'Mozilla/5.0 (Linux; Android 13; Symbiont Test) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Mobile Safari/537.36' } : {}),
  });
  const page = await context.newPage();
  const logs = [];
  const errors = [];
  const warnings = [];
  const abortedWasmRequests = [];
  const resources = {};
  let closing = false;
  page.on('console', message => {
    logs.push(message.text());
    if (message.type() === 'error') errors.push(message.text());
    if (message.type() === 'warning') warnings.push(message.text());
  });
  page.on('pageerror', error => errors.push(error.stack || error.message));
  page.on('requestfailed', request => {
    if (closing) return;
    const failure = request.failure()?.errorText;
    // Record cancelled WASM transfers separately from runtime errors. A 200
    // response, completed Godot startup and functioning game are all mandatory;
    // cancellation alone does not establish a failure of the loaded module.
    if (failure === 'net::ERR_ABORTED' && new URL(request.url()).pathname.endsWith('/index.wasm')) {
      abortedWasmRequests.push({ url: request.url(), failure });
    } else errors.push(`${request.url()}: ${failure}`);
  });
  page.on('response', response => {
    const filename = new URL(response.url()).pathname.split('/').pop();
    if (['index.wasm', 'index.pck'].includes(filename)) resources[filename] = response.status();
  });
  const result = { name, viewport: '1280x720', touch: mobile, errors, warnings, abortedWasmRequests, resources, transitions: {} };
  const click = (x, y) => mobile ? page.touchscreen.tap(x, y) : page.mouse.click(x, y);
  async function shot(phase, final = false) {
    const filename = final ? path.join(screenshots, mobile ? '10_web_touch.png' : '09_web_desktop.png') : path.join(diagnostics, `${name}_${phase}.png`);
    const data = await page.screenshot({ path: filename, animations: 'disabled' });
    return { data, pixels: await framePixels(page, data), path: filename };
  }
  try {
    console.log(`[${name}] loading Godot WASM`);
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 90_000 });
    await page.waitForFunction(() => !document.getElementById('status'), null, { timeout: 90_000 });
    await delay(700);
    assert(logs.some(line => line.includes('Godot Engine')), 'Godot startup log was not observed');
    assert.equal(resources['index.wasm'], 200, 'WASM did not load successfully');
    assert.equal(resources['index.pck'], 200, 'PCK did not load successfully');
    const rectangle = await page.locator('#canvas').boundingBox();
    assert(rectangle && rectangle.width === 1280 && rectangle.height === 720, `Unexpected canvas: ${JSON.stringify(rectangle)}`);
    const title = await shot('title');
    await click(320, 420);
    await delay(400);
    const tutorial = await shot('tutorial');
    result.transitions.titleToTutorial = difference(title.pixels, tutorial.pixels);
    assert(result.transitions.titleToTutorial.changedFraction > .15, 'Start button did not leave the title');
    await click(640, 480);
    await delay(450);
    const ship = await shot('ship');
    result.transitions.tutorialToShip = difference(tutorial.pixels, ship.pixels);
    assert(result.transitions.tutorialToShip.changedFraction > .15, 'Tutorial acknowledgement did not reveal the ship');
    const stickPixels = await framePixels(page, ship.data, { x: 90, y: 580, width: 40, height: 40, step: 2 });
    if (!mobile) desktopStickPixels = stickPixels;
    else {
      result.browserTouchPoints = await page.evaluate(() => navigator.maxTouchPoints);
      assert(result.browserTouchPoints > 0, 'Touch emulation was not active');
      assert(desktopStickPixels, 'Desktop baseline is required for automatic touch UI verification');
      result.transitions.automaticTouchControls = difference(desktopStickPixels, stickPixels);
      assert(result.transitions.automaticTouchControls.changedFraction > .7,
        'Fresh touch profile did not automatically show its left joystick');
    }
    await keyHold(page, 'KeyA', 2000);
    await keyHold(page, 'KeyW', 1100);
    await delay(400);
    const moved = await shot('moved');
    result.transitions.wasdMovement = difference(ship.pixels, moved.pixels);
    assert(result.transitions.wasdMovement.changedFraction > .12, 'WASD did not visibly move the host/camera');
    await page.keyboard.press('KeyE');
    await delay(400);
    const map = await shot('navigation');
    result.transitions.organContact = difference(moved.pixels, map.pixels);
    assert(result.transitions.organContact.changedFraction > .15, 'E did not open navigation near the organ');
    await click(830, 360);
    await delay(2200);
    const mission = await shot('mission');
    result.transitions.missionLaunch = difference(map.pixels, mission.pixels);
    assert(result.transitions.missionLaunch.changedFraction > .15, 'Mission launch did not reveal gameplay');
    if (mobile) {
      const cdp = await context.newCDPSession(page);
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: 110, y: 600, id: 0 }] });
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: 160, y: 600, id: 0 }] });
      await delay(900);
      await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
      await delay(300);
      const touched = await shot('touch_moved');
      result.transitions.touchMovement = difference(mission.pixels, touched.pixels);
      result.touchHostBefore = hostMarker(mission.pixels);
      result.touchHostAfter = hostMarker(touched.pixels);
      assert(result.touchHostAfter.x - result.touchHostBefore.x > 45,
        'Touch drag did not move the visible host to the right');
      await cdp.detach();
    }
    await delay(500);
    const final = await shot('final', true);
    result.screenshot = path.relative(project, final.path).replaceAll(path.sep, '/');
    result.startup = logs.filter(line => line.includes('Godot Engine') || line.includes('OpenGL'));
    assert.deepEqual(errors, [], `${name}: browser/runtime errors were observed`);
    result.status = 'passed';
    console.log(`[${name}] passed: WASM, menu, tutorial, WASD, organ contact, mission${mobile ? ', touch' : ''}`);
    return result;
  } catch (error) {
    result.status = 'failed';
    result.failure = error.stack || error.message;
    result.console = logs;
    await page.screenshot({ path: path.join(diagnostics, `${name}_failure.png`) }).catch(() => {});
    throw Object.assign(error, { smokeResult: result });
  } finally {
    closing = true;
    await context.close();
  }
}

async function main() {
  assert(fs.existsSync(path.join(webRoot, 'index.html')), 'Web export is missing; export the Web preset first.');
  await fsp.mkdir(diagnostics, { recursive: true });
  await fsp.mkdir(screenshots, { recursive: true });
  const { chromium } = loadPlaywright();
  const executablePath = findBrowser(chromium);
  const { server, url } = await startServer();
  let browser;
  const report = { status: 'running', webRoot, executablePath, host: '127.0.0.1', contexts: [] };
  try {
    browser = await chromium.launch({
      executablePath,
      headless: true,
      args: ['--enable-webgl', '--ignore-gpu-blocklist', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
    });
    report.browserVersion = browser.version();
    for (const mobile of [false, true]) report.contexts.push(await runContext(browser, url, mobile));
    report.status = 'passed';
    console.log(`BROWSER_SMOKE_OK: ${report.contexts.map(item => item.name).join(' and ')}; 0 browser/runtime errors; WASM and PCK loaded`);
  } catch (error) {
    if (error.smokeResult) report.contexts.push(error.smokeResult);
    report.status = 'failed';
    report.failure = error.stack || error.message;
    throw error;
  } finally {
    await fsp.writeFile(path.join(diagnostics, 'report.json'), JSON.stringify(report, null, 2) + os.EOL, 'utf8');
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
}

main().catch(error => { console.error(error.stack || error); process.exitCode = 1; });
