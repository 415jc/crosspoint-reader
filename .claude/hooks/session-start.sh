#!/bin/bash
# SessionStart hook for Claude Code on the web.
#
# Installs the host toolchain needed to run this repo's two reproducible CI
# gates: the clang-format linter and the googletest unit suite. The ESP32
# firmware build (`pio run`) and `pio check` are intentionally left out: they
# pull a multi-GB Espressif toolchain from GitHub release archives and are not
# needed to iterate on host-side tests or formatting.
set -euo pipefail

# Only run in the remote (web) environment; local checkouts manage their own tools.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# The harness sets CLAUDE_PROJECT_DIR for hooks; fall back to the repo root
# derived from this script's location so the hook is safe to run standalone.
CLAUDE_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

echo "[session-start] Preparing test and lint toolchain..."

# --- Format linter: clang-format 21 -----------------------------------------
# bin/clang-format-fix requires clang-format >= 21 (the repo .clang-format uses
# v21 options). The PyPI 'clang-format' wheel ships a self-contained v21 binary,
# so we avoid the apt.llvm.org install the CI uses.
if ! command -v clang-format-21 >/dev/null 2>&1; then
  echo "[session-start] Installing clang-format 21 from PyPI..."
  python3 -m pip install --quiet --disable-pip-version-check "clang-format==21.*"
  # Expose the wrapper's preferred binary name regardless of PATH ordering
  # (a system clang-format may otherwise shadow it).
  cf_bin="$(python3 -c 'import clang_format; print(clang_format.get_executable("clang-format"))')"
  ln -sf "$cf_bin" /usr/local/bin/clang-format-21
fi
echo "[session-start] clang-format: $(clang-format-21 --version)"

# --- Unit tests: cmake + ninja + googletest ---------------------------------
# Configuring pre-fetches googletest (cloned from GitHub) into build/test so the
# first `ctest` run needs no network. build/ is gitignored.
echo "[session-start] Configuring unit tests (fetches googletest)..."
cmake -S "$CLAUDE_PROJECT_DIR/test" -B "$CLAUDE_PROJECT_DIR/build/test" \
  -G Ninja -DCMAKE_BUILD_TYPE=Release

echo "[session-start] Toolchain ready."
echo "  Lint : ./bin/clang-format-fix -g"
echo "  Tests: cmake --build build/test && ctest --test-dir build/test --output-on-failure -j"
