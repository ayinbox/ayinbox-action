#!/usr/bin/env bash
# Offline tests for the action's scripts: a verified install from a local
# mirror, a refused tampered archive, and argument parsing with no shell.
set -euo pipefail

cd "$(dirname "$0")/.."
root=$(pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "ok   $*"; }
sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

case "$(uname -s)" in
  Linux) export RUNNER_OS=Linux os=linux ;;
  Darwin) export RUNNER_OS=macOS os=darwin ;;
  *) echo "skipping: tests run on Linux and macOS"; exit 0 ;;
esac
case "$(uname -m)" in
  x86_64|amd64) export RUNNER_ARCH=X64 arch=amd64 ;;
  arm64|aarch64) export RUNNER_ARCH=ARM64 arch=arm64 ;;
esac
asset="ayinbox_${os}_${arch}.tar.gz"

# A stub CLI that prints its arguments one per line, and fails on "boom".
mkdir -p "$work/stage" "$work/mirror" "$work/bad"
cat > "$work/stage/ayinbox" <<'STUB'
#!/bin/sh
[ "${1:-}" = version ] && { echo "ayinbox v9.9.9 (test)"; exit 0; }
[ "${1:-}" = boom ] && exit 3
[ "${AYINBOX_TOKEN:-}" = aybox_test ] || { echo "no token" >&2; exit 4; }
for a in "$@"; do printf '[%s]\n' "$a"; done
STUB
chmod +x "$work/stage/ayinbox"
tar -czf "$work/mirror/$asset" -C "$work/stage" .
(cd "$work/mirror" && sha "$asset" > checksums.txt)
cp "$work/mirror/$asset" "$work/bad/"
sed 's/^[0-9a-f]\{64\}/0000000000000000000000000000000000000000000000000000000000000000/' "$work/mirror/checksums.txt" > "$work/bad/checksums.txt"

export RUNNER_TEMP="$work/runner" GITHUB_OUTPUT="$work/output" GITHUB_PATH="$work/path"
mkdir -p "$RUNNER_TEMP"; : > "$GITHUB_OUTPUT"; : > "$GITHUB_PATH"

if AYINBOX_CLI_BASE_URL="file://$work/bad" INPUT_VERSION=latest bash scripts/install.sh >/dev/null 2>&1; then
  fail "a checksum mismatch installed"
fi
[ ! -e "$RUNNER_TEMP/ayinbox-bin/ayinbox" ] || fail "a checksum mismatch left a binary behind"
pass "refuses a tampered archive"

if INPUT_VERSION='v1; rm -rf /' bash scripts/install.sh >/dev/null 2>&1; then fail "accepted a malformed version"; fi
pass "rejects a malformed version"

AYINBOX_CLI_BASE_URL="file://$work/mirror" INPUT_VERSION=latest bash scripts/install.sh >/dev/null
grep -q "^version=v9.9.9$" "$GITHUB_OUTPUT" || fail "install did not report the version"
grep -q "ayinbox-bin" "$GITHUB_PATH" || fail "install did not add the binary to PATH"
bin=$(sed -n 's/^bin=//p' "$GITHUB_OUTPUT")
pass "installs from a mirror after verifying the checksum"

: > "$GITHUB_OUTPUT"
AYINBOX_BIN="$bin" INPUT_API_KEY=aybox_test INPUT_COMMAND="ayinbox campaign create --name \"Q3 outbound\" '\$(touch $work/pwned)'" \
  bash scripts/run.sh >/dev/null
[ ! -e "$work/pwned" ] || fail "the command string was evaluated by a shell"
expected=$(printf '%s\n' '[campaign]' '[create]' '[--name]' '[Q3 outbound]' "[\$(touch $work/pwned)]")
actual=$(awk '/^stdout<</{d=substr($0,9); f=1; next} f && $0==d {f=0; next} f' "$GITHUB_OUTPUT")
[ "$actual" = "$expected" ] || fail "arguments were not split as expected:
$actual"
grep -q '^exit-code=0$' "$GITHUB_OUTPUT" || fail "exit-code output missing"
pass "splits quoted arguments without a shell and sets outputs"

: > "$GITHUB_OUTPUT"
if AYINBOX_BIN="$bin" INPUT_API_KEY=aybox_test INPUT_COMMAND=boom bash scripts/run.sh >/dev/null 2>&1; then
  fail "a failing command passed"
fi
grep -q '^exit-code=3$' "$GITHUB_OUTPUT" || fail "exit-code was not passed through"
pass "passes a failing exit code through"

if AYINBOX_BIN="$bin" INPUT_API_KEY='' INPUT_COMMAND='campaign list' bash scripts/run.sh >/dev/null 2>&1; then
  fail "ran without an api key"
fi
pass "refuses an empty api key"

echo "all action tests passed"
