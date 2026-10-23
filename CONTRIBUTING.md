# Contributing

Use Node.js 20 or later. Run `npm ci --prefix local`, then `npm test --prefix local`.
Check shell syntax with `for file in board/*.sh; do sh -n "$file"; done` on Linux,
macOS, or Git Bash. Keep shell scripts in LF format.
Run `sh local/test/board-smoke.sh` to exercise board control flow with mocks.

Tests use synthetic responses and a tiny generated PNG. They do not authenticate
to Studio or QDC, install board software, or spend device minutes. The packaging
test writes its archive into an isolated temporary folder.

For runner changes, also verify on a VENTUNO Q session before claiming hardware
compatibility. Record the CLI version, deployment backend, model variant,
preprocessing, scoring rule and QDC usage separately from the command ledger.

Never attach API keys, SSH keys, account screenshots, compiled private models,
or private test images to an issue or pull request.
