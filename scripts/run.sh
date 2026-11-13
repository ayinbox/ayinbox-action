#!/usr/bin/env bash
# Runs one ayinbox command. The command string is split into arguments by
# xargs quoting rules and never passed through a shell, so it cannot run code.
set -euo pipefail

die() { echo "::error::$*" >&2; exit 1; }

[ -n "${INPUT_API_KEY:-}" ] || die "api-key is empty; pass an AY Inbox API key from a secret"
[ -n "${INPUT_COMMAND//[[:space:]]/}" ] || die "command is empty"
bin="${AYINBOX_BIN:-ayinbox}"

echo "::add-mask::${INPUT_API_KEY}"
export AYINBOX_TOKEN="$INPUT_API_KEY"
export AYINBOX_NO_UPDATE_CHECK=1
if [ -n "${INPUT_API_URL:-}" ]; then export AYINBOX_API_URL="$INPUT_API_URL"; fi

args=()
while IFS= read -r -d '' arg; do
  args+=("$arg")
done < <(printf '%s' "$INPUT_COMMAND" | xargs printf '%s\0')
if [ "${#args[@]}" -gt 0 ] && [ "${args[0]}" = ayinbox ]; then
  args=("${args[@]:1}")
fi
[ "${#args[@]}" -gt 0 ] || die "command is empty, or its quotes do not match"

out=$(mktemp)
trap 'rm -f "$out"' EXIT
set +e
"$bin" "${args[@]}" > "$out"
code=$?
set -e

cat "$out"
delim="ayinbox_$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
{
  echo "stdout<<$delim"
  printf '%s\n' "$(cat "$out")"
  echo "$delim"
  echo "exit-code=$code"
} >> "${GITHUB_OUTPUT:-/dev/null}"
exit "$code"
