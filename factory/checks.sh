#!/usr/bin/env bash
# factory/checks.sh: this repo's checks. The gate runs this file from the main
# checkout, inside a job's worktree, before any reviewer reads the code and
# again before the PR merges. Exit 0 only if everything passes.
#
# It is the only repo-specific script in the factory. The install (see
# INSTALL.md) replaces the placeholder below with the project's real test,
# lint, typecheck and build commands, then checks that `factory/bin/gate
# --main` passes on the base branch. /factory run won't start until it's done.
#
# Rules:
#   - Run from the worktree root (the gate sets the working directory).
#   - Non-interactive, and no network beyond installing dependencies.
#   - $FACTORY_PORT is set when a job has a port; use it for any server.
#   - Keep it fast; reviewers wait on it. config.json checks_timeout_sec caps it.
#
# Examples:
#   npm ci && npm run lint && npm run typecheck && npm test && npm run build
#   python -m pip install -e '.[dev]' -q && ruff check . && mypy . && pytest -q
#   go vet ./... && go test ./...
#   cargo clippy -- -D warnings && cargo test
set -euo pipefail

# FACTORY-CHECKS-NOT-CONFIGURED: delete this block once real checks are below.
echo "factory/checks.sh has no checks yet. See INSTALL.md, step 3." >&2
exit 1
