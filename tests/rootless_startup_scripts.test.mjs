import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const entrypoint = readFileSync('scripts/entrypoint.sh', 'utf8');
const bootstrap = readFileSync('scripts/bootstrap.sh', 'utf8');
const cloudcliRun = readFileSync('s6-overlay/s6-rc.d/cloudcli/run', 'utf8');

test('entrypoint gates root-only operations for non-root startup', () => {
  assert.match(entrypoint, /RUNNING_AS_ROOT=0/);
  assert.match(entrypoint, /run_as_claude\(\)/);
  assert.match(entrypoint, /chown_if_root\(\)/);
  assert.match(entrypoint, /Non-root startup detected/);
  assert.match(entrypoint, /groupmod -o -g/);
  assert.match(entrypoint, /usermod -o -u/);
});

test('bootstrap uses the same root-aware command helpers', () => {
  assert.match(bootstrap, /RUNNING_AS_ROOT=0/);
  assert.match(bootstrap, /run_as_claude\(\)/);
  assert.match(bootstrap, /chown_if_root\(\)/);
  assert.doesNotMatch(bootstrap, /^runuser /m);
});

test('cloudcli service skips s6 privilege drop when already non-root', () => {
  assert.match(cloudcliRun, /if \[ "\$\(id -u\)" = "0" \]/);
  assert.match(cloudcliRun, /exec s6-setuidgid claude cloudcli --port 3001/);
  assert.match(cloudcliRun, /exec cloudcli --port 3001/);
});
