# CloudCLI account-management bridge

HolyClaude carries this source overlay until CloudCLI publishes local-account logout and password-change support upstream.

Upstream source: https://github.com/siteboon/claudecodeui
Pinned source commit: `5884573a6975f53381759a28280afd9c8bb332c4`
Package version: `@cloudcli-ai/cloudcli@1.36.1`
Related upstream work:

- https://github.com/siteboon/claudecodeui/issues/797
- https://github.com/siteboon/claudecodeui/pull/928
- https://github.com/siteboon/claudecodeui/pull/526

Rules:

1. Build from pinned source plus this patch.
2. Do not hand-edit hashed `dist/assets/*.js` files.
3. Keep the manifest next to the generated tarball.
4. Remove this bridge after a fixed upstream npm package verifies as `upstream-complete`.
