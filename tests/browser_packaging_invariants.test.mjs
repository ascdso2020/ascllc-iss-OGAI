import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const dockerfile = readFileSync('Dockerfile', 'utf8');
const wrapper = readFileSync('scripts/holyclaude-chromium', 'utf8');

function aptPackageLines(source) {
  return source
    .split('\n')
    .filter((line) => !line.trimStart().startsWith('#'))
    .filter((line) => !line.includes('playwright install'));
}

test('Dockerfile uses pinned Playwright packages and shared browser storage', () => {
  assert.match(dockerfile, /playwright@1\.61\.0/);
  assert.match(dockerfile, /playwright==1\.61\.0/);
  assert.match(dockerfile, /PLAYWRIGHT_BROWSERS_PATH=\/ms-playwright/);
  assert.match(dockerfile, /NODE_PATH=\/usr\/local\/lib\/node_modules/);
  assert.match(dockerfile, /CHROME_PATH=\/usr\/bin\/chromium/);
  assert.match(dockerfile, /PUPPETEER_EXECUTABLE_PATH=\/usr\/bin\/chromium/);
});

test('Dockerfile does not install Debian chromium as the browser authority', () => {
  const packageLines = aptPackageLines(dockerfile).join('\n');
  assert.doesNotMatch(packageLines, /^\s*chromium \\/m);
  assert.doesNotMatch(packageLines, /\bapt-get install\b[^\n]*\bchromium\b/);
});

test('Dockerfile installs regular Playwright Chromium at build time', () => {
  assert.match(dockerfile, /PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm i -g/);
  assert.match(dockerfile, /playwright install --with-deps --no-shell chromium/);
  assert.doesNotMatch(dockerfile, /--only-shell/);
  assert.match(dockerfile, /chmod -R a\+rX \/ms-playwright/);
  assert.match(dockerfile, /ln -sf \/usr\/local\/bin\/holyclaude-chromium \/usr\/bin\/chromium/);
});

test('Dockerfile verifies Node, Python, and CloudCLI resolve the same packaged browser', () => {
  assert.match(dockerfile, /NODE_CHROMIUM_PATH=/);
  assert.match(dockerfile, /PYTHON_CHROMIUM_PATH=/);
  assert.match(dockerfile, /test "\$NODE_CHROMIUM_PATH" = "\$PYTHON_CHROMIUM_PATH"/);
  assert.match(dockerfile, /createRequire\('file:\/\/\/usr\/local\/lib\/node_modules\/@cloudcli-ai\/cloudcli\/dist-server\/server\/index\.js'\)/);
  assert.match(dockerfile, /const playwright = require\('playwright'\)/);
  assert.match(dockerfile, /playwright\.chromium\.executablePath\(\)/);
});

test('chromium wrapper resolves Playwright Chromium and fails closed', () => {
  assert.match(wrapper, /^#!\/bin\/sh/);
  assert.match(wrapper, /PLAYWRIGHT_BROWSERS_PATH:-\/ms-playwright/);
  assert.match(wrapper, /chromium-\*\/chrome-linux\*\/chrome/);
  assert.match(wrapper, /Playwright Chromium executable not found/);
  assert.match(wrapper, /exit 127/);
  assert.match(wrapper, /exec "\$BROWSER_BIN"/);
});
