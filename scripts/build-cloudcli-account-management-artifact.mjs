import { createHash } from 'node:crypto';
import { readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { cp, mkdir, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(fileURLToPath(new URL('..', import.meta.url)));
const patchDir = path.join(repoRoot, 'vendor/patches/cloudcli-account-management');
const artifactDir = path.join(repoRoot, 'vendor/artifacts');
const upstreamRepo = 'https://github.com/siteboon/claudecodeui.git';
const upstreamCommit = '5884573a6975f53381759a28280afd9c8bb332c4';
const packageVersion = '1.36.1';
const artifactFile = `cloudcli-ai-cloudcli-${packageVersion}-holyclaude-account-management.tgz`;

const args = new Map();
for (let index = 2; index < process.argv.length; index += 2) {
  args.set(process.argv[index], process.argv[index + 1]);
}

const sourceArg = args.get('--source');
const keepWorkdir = args.get('--keep-workdir') === 'true';

function run(command, argsList, options = {}) {
  execFileSync(command, argsList, {
    stdio: 'inherit',
    ...options,
  });
}

function runCapture(command, argsList, options = {}) {
  return execFileSync(command, argsList, {
    encoding: 'utf8',
    ...options,
  }).trim();
}

function sha256(filePath) {
  return createHash('sha256').update(readFileSync(filePath)).digest('hex');
}

function collectFiles(root, prefix = '') {
  const entries = [];
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    const relativePath = path.join(prefix, entry.name).replaceAll(path.sep, '/');
    const fullPath = path.join(root, entry.name);
    if (entry.isDirectory()) {
      entries.push(...collectFiles(fullPath, relativePath));
    } else {
      entries.push(relativePath);
    }
  }
  return entries;
}

async function prepareSource(workdir) {
  if (sourceArg) {
    await cp(path.resolve(sourceArg), workdir, {
      recursive: true,
      filter: (sourcePath) => !sourcePath.includes(`${path.sep}.git${path.sep}`) && !sourcePath.endsWith(`${path.sep}.git`),
    });
    return;
  }

  run('git', ['clone', '--no-checkout', upstreamRepo, workdir]);
  run('git', ['checkout', upstreamCommit], { cwd: workdir });
}

const workdir = await mkdtemp(path.join(tmpdir(), 'holyclaude-cloudcli-account-'));
try {
  await prepareSource(workdir);
  const actualCommit = sourceArg ? runCapture('git', ['rev-parse', 'HEAD'], { cwd: path.resolve(sourceArg) }) : upstreamCommit;
  if (actualCommit !== upstreamCommit) {
    throw new Error(`Expected CloudCLI source commit ${upstreamCommit}, got ${actualCommit}`);
  }

  const patches = readdirSync(patchDir)
    .filter((name) => name.endsWith('.patch'))
    .sort();

  for (const patch of patches) {
    // The checked-in patch is whitespace-normalized so repo release checks stay clean.
    // The upstream commit is verified above; use zero context so CloudCLI 1.36.1's
    // whitespace-bearing blank lines do not force trailing whitespace into this repo.
    run('git', ['apply', '-C0', path.join(patchDir, patch)], { cwd: workdir });
  }

  run('npm', ['ci'], { cwd: workdir });
  run('npm', ['run', 'typecheck'], { cwd: workdir });
  run('npm', ['run', 'build'], { cwd: workdir });
  run('npm', ['run', 'lint'], { cwd: workdir });

  const packOutput = runCapture('npm', ['pack', '--pack-destination', artifactDir], { cwd: workdir });
  const generatedName = packOutput.split('\n').at(-1);
  const generatedPath = path.join(artifactDir, generatedName);
  const artifactPath = path.join(artifactDir, artifactFile);
  await rm(artifactPath, { force: true });
  await cp(generatedPath, artifactPath);
  await rm(generatedPath, { force: true });

  const unpackDir = path.join(workdir, 'pack-check');
  await mkdir(unpackDir);
  run('tar', ['-xzf', artifactPath, '-C', unpackDir]);
  const fileListHash = createHash('sha256')
    .update(collectFiles(path.join(unpackDir, 'package')).sort().join('\n'))
    .digest('hex');

  const manifest = {
    bridge: 'cloudcli-account-management',
    state: 'holyclaude-bridge-complete',
    upstream: {
      repository: upstreamRepo,
      commit: upstreamCommit,
      package: '@cloudcli-ai/cloudcli',
      version: packageVersion,
      license: 'AGPL-3.0-or-later',
    },
    build: {
      node: runCapture('node', ['--version']),
      npm: runCapture('npm', ['--version']),
      commands: ['npm ci', 'npm run typecheck', 'npm run build', 'npm run lint', 'npm pack'],
      generatedAt: '2026-07-09T00:00:00Z',
      sourceDateNote: 'Timestamp is fixed in this manifest so reproducibility checks compare stable fields.',
    },
    artifact: {
      file: artifactFile,
      sha256: sha256(artifactPath),
      size: statSync(artifactPath).size,
      packageFileListSha256: fileListHash,
    },
    patches: patches.map((patch) => ({ file: patch, sha256: sha256(path.join(patchDir, patch)) })),
    verification: {
      detector: 'scripts/verify-cloudcli-account-management-support.mjs',
      expectedState: 'holyclaude-bridge-complete',
      existingHolyClaudeRuntimePatchesRunAfterInstall: true,
    },
    upstreamRefs: [
      'https://github.com/siteboon/claudecodeui/issues/797',
      'https://github.com/siteboon/claudecodeui/pull/928',
      'https://github.com/siteboon/claudecodeui/pull/526',
    ],
    removal: 'Remove when a fixed upstream npm package verifies as upstream-complete without HolyClaude bridge markers.',
  };

  writeFileSync(
    path.join(artifactDir, 'cloudcli-account-management.manifest.json'),
    `${JSON.stringify(manifest, null, 2)}\n`,
  );

  console.log(`[cloudcli-account] wrote ${artifactPath}`);
} finally {
  if (!keepWorkdir) {
    await rm(workdir, { recursive: true, force: true });
  } else {
    console.log(`[cloudcli-account] kept ${workdir}`);
  }
}
