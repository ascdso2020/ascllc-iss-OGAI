import { existsSync, readFileSync, writeFileSync } from 'fs';

const DEFAULT_CLOUDCLI_ROOT = '/usr/local/lib/node_modules/@cloudcli-ai/cloudcli';
const CLOUDCLI_ROOT = process.argv[2] || DEFAULT_CLOUDCLI_ROOT;
const ERROR_MESSAGE = '[patch] ERROR: CloudCLI self-update anchors not found';
const CLI_MARKER = 'const HOLYCLAUDE_CLOUDCLI_SELF_UPDATE_DISABLED = true;';
const INDEX_MARKER = 'const HOLYCLAUDE_UPDATE_DISABLED_RESPONSE = {';
const CLI_CHECK_ANCHOR = 'async function checkForUpdates(silent = false)';
const CLI_UPDATE_ANCHOR = 'async function updatePackage()';
const CLI_OLD_PROMPT = "Run ${c.bright('cloudcli update')} to update";
const CLI_OLD_NPM_UPDATE = "execSync('npm update -g @cloudcli-ai/cloudcli', { stdio: 'inherit' });";
const CLI_OLD_GLOBAL_INSTALL_HINT = "console.log(`\\n${c.dim('  Or install globally:')} npm install -g @cloudcli-ai/cloudcli\\n`);";
const CLI_DOCKER_UPDATE_HINT = "console.log(`\\n${c.dim('  HolyClaude updates:')} ${HOLYCLAUDE_DOCKER_UPDATE_COMMAND}\\n`);";
const INDEX_ROUTE_COMMENT = '// System update endpoint';
const INDEX_ROUTE_ANCHOR = "app.post('/api/system/update', authenticateToken, async (req, res) => {";
const INDEX_NEXT_ROUTE = "\napp.get('/api/browse-filesystem'";
const INDEX_OLD_NPM_UPDATE = "npm install -g @cloudcli-ai/cloudcli@latest";

const targets = [
  {
    label: 'source',
    cliPath: `${CLOUDCLI_ROOT}/server/cli.js`,
    indexPath: `${CLOUDCLI_ROOT}/server/index.js`
  },
  {
    label: 'runtime',
    cliPath: `${CLOUDCLI_ROOT}/dist-server/server/cli.js`,
    indexPath: `${CLOUDCLI_ROOT}/dist-server/server/index.js`
  }
].filter((target) => existsSync(target.cliPath) && existsSync(target.indexPath));

if (targets.length === 0) {
  console.error(ERROR_MESSAGE);
  process.exit(1);
}

function readSource(path) {
  try {
    return readFileSync(path, 'utf8');
  } catch {
    console.error(ERROR_MESSAGE);
    process.exit(1);
  }
}

function writeSource(path, source) {
  try {
    writeFileSync(path, source);
  } catch {
    console.error(ERROR_MESSAGE);
    process.exit(1);
  }
}

function findFunctionEnd(source, functionAnchor) {
  const functionIndex = source.indexOf(functionAnchor);
  if (functionIndex === -1) {
    return -1;
  }

  const bodyStartIndex = source.indexOf('{', functionIndex);
  if (bodyStartIndex === -1) {
    return -1;
  }

  let braceDepth = 0;
  for (let sourceIndex = bodyStartIndex; sourceIndex < source.length; sourceIndex += 1) {
    const character = source[sourceIndex];
    if (character === '{') {
      braceDepth += 1;
    } else if (character === '}') {
      braceDepth -= 1;
      if (braceDepth === 0) {
        return sourceIndex + 1;
      }
    }
  }

  return -1;
}

function patchCli(path) {
  let source = readSource(path);
  const alreadyPatched = source.includes(CLI_MARKER);

  if (!alreadyPatched) {
    const checkIndex = source.indexOf(CLI_CHECK_ANCHOR);
    const updateIndex = source.indexOf(CLI_UPDATE_ANCHOR);
    const updateEndIndex = findFunctionEnd(source, CLI_UPDATE_ANCHOR);
    const checkCommentIndex = source.lastIndexOf('// Check for updates', checkIndex);

    const requiredAnchorsPresent = checkIndex !== -1
      && updateIndex !== -1
      && updateEndIndex !== -1
      && checkCommentIndex !== -1
      && source.includes(CLI_OLD_PROMPT)
      && source.includes(CLI_OLD_NPM_UPDATE);

    if (!requiredAnchorsPresent || checkCommentIndex > checkIndex || checkIndex > updateIndex) {
      console.error(ERROR_MESSAGE);
      process.exit(1);
    }

    const replacement = [
      '// HolyClaude ships patched CloudCLI files. npm self-updates can replace them.',
      'const HOLYCLAUDE_CLOUDCLI_SELF_UPDATE_DISABLED = true;',
      "const HOLYCLAUDE_DOCKER_UPDATE_COMMAND = 'docker compose pull && docker compose up -d';",
      '',
      'async function checkForUpdates(silent = false) {',
      '    if (!silent) {',
      "        console.log(`${c.warn('[UPDATE]')} CloudCLI self-update is disabled in HolyClaude.`);",
      '        console.log(`         Use ${c.bright(HOLYCLAUDE_DOCKER_UPDATE_COMMAND)} to update the image.\\n`);',
      '    }',
      '    return { hasUpdate: false, currentVersion: packageJson.version, disabled: true };',
      '}',
      '',
      'async function updatePackage() {',
      "    console.log(`${c.warn('[UPDATE]')} CloudCLI self-update is disabled in HolyClaude.`);",
      '    console.log(`         Use ${c.bright(HOLYCLAUDE_DOCKER_UPDATE_COMMAND)} to update the image.`);',
      "    console.log('         If this container already ran an npm update, recreate it from the HolyClaude image.');",
      '}'
    ].join('\n');

    source = `${source.slice(0, checkCommentIndex)}${replacement}${source.slice(updateEndIndex)}`;
  }

  if (source.includes(CLI_OLD_GLOBAL_INSTALL_HINT)) {
    source = source.replace(CLI_OLD_GLOBAL_INSTALL_HINT, CLI_DOCKER_UPDATE_HINT);
  }

  if (
    !source.includes(CLI_MARKER)
    || source.includes(CLI_OLD_NPM_UPDATE)
    || source.includes(CLI_OLD_PROMPT)
    || source.includes(CLI_OLD_GLOBAL_INSTALL_HINT)
  ) {
    console.error(ERROR_MESSAGE);
    process.exit(1);
  }

  writeSource(path, source);
  return alreadyPatched;
}

function patchIndex(path) {
  let source = readSource(path);
  const alreadyPatched = source.includes(INDEX_MARKER);

  if (!alreadyPatched) {
    const routeCommentIndex = source.indexOf(INDEX_ROUTE_COMMENT);
    const routeIndex = source.indexOf(INDEX_ROUTE_ANCHOR);
    const nextRouteIndex = source.indexOf(INDEX_NEXT_ROUTE, routeIndex);

    const requiredAnchorsPresent = routeCommentIndex !== -1
      && routeIndex !== -1
      && nextRouteIndex !== -1
      && routeCommentIndex < routeIndex
      && source.includes(INDEX_OLD_NPM_UPDATE);

    if (!requiredAnchorsPresent) {
      console.error(ERROR_MESSAGE);
      process.exit(1);
    }

    const replacement = `// System update endpoint
const HOLYCLAUDE_UPDATE_DISABLED_RESPONSE = {
    success: false,
    error: 'CloudCLI self-update is disabled in HolyClaude',
    message: 'Update HolyClaude with docker compose pull && docker compose up -d. This image includes patched CloudCLI files; npm self-updates can replace them.'
};

app.post('/api/system/update', authenticateToken, async (req, res) => {
    res.status(409).json(HOLYCLAUDE_UPDATE_DISABLED_RESPONSE);
});
`;

    source = `${source.slice(0, routeCommentIndex)}${replacement}${source.slice(nextRouteIndex)}`;
  }

  if (!source.includes(INDEX_MARKER) || source.includes(INDEX_OLD_NPM_UPDATE)) {
    console.error(ERROR_MESSAGE);
    process.exit(1);
  }

  writeSource(path, source);
  return alreadyPatched;
}

for (const target of targets) {
  const cliAlreadyPatched = patchCli(target.cliPath);
  const indexAlreadyPatched = patchIndex(target.indexPath);
  const status = cliAlreadyPatched && indexAlreadyPatched ? 'already disabled' : 'disabled';
  console.log(`[patch] CloudCLI self-update ${status} (${target.label})`);
}
