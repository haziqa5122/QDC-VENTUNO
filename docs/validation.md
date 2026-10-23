# Validation report

Checked on 23 October 2026 for GitHub source distribution.

## Passed locally

- Eight Node.js tests covering response parsing, malformed/error responses,
  duplicate samples, unknown class labels, partial-run rejection, statistics,
  upload ZIP layout, LF scripts, permissions, and empty image folders.
- Shell syntax checks with Git Bash for the board helpers and mock tests.
- Offline shell smoke tests for authentication argument quoting, successful
  batching, runner cleanup, output overwrite refusal, empty image folders,
  occupied HTTP ports, and failed inference requests.
- `npm audit --prefix local --omit=dev --audit-level=high`: zero vulnerabilities
  reported for the locked local dependencies after updating adm-zip to 0.6.1.
- Synthetic evaluator demonstration produces 50.0% accuracy (1/2), as expected.

The audit covers the repository's local dependency tree. It does not audit the
separate Edge Impulse CLI installed on the remote board.

## Hardware boundary

The earlier real VENTUNO Q run exercised the HTTP inference route and returned
90 responses. This repository's error handling, process cleanup and installation
changes were checked offline. This exact source revision has not yet completed
a fresh QDC session. GitHub Actions is configured but has not run until the
repository is uploaded.

The earlier QDC report showed 30 minutes used; the command ledger covered only
8.8 minutes within that session. Those figures must not be used interchangeably.
Raw private session output and account screenshots are excluded from distribution.
