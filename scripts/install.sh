#!/usr/bin/env bash
# Installs the ayinbox CLI from the public release, refusing any archive whose
# checksum does not match the release's checksums.txt.
set -euo pipefail

REPO="ayinbox/ayinbox-cli"
version="${INPUT_VERSION:-latest}"
dest="${RUNNER_TEMP:?RUNNER_TEMP is not set}/ayinbox-bin"

die() { echo "::error::$*" >&2; exit 1; }

if [ "$version" != latest ] && ! [[ $version =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
  die "version must be latest or a release tag such as v1.2.3, not '$version'"
fi

case "${RUNNER_OS:-}" in
  Linux) os=linux ;;
  macOS) os=darwin ;;
  Windows) os=windows ;;
  *) die "unsupported runner OS '${RUNNER_OS:-}'" ;;
esac
case "${RUNNER_ARCH:-}" in
  X64) arch=amd64 ;;
  ARM64) arch=arm64 ;;
  *) die "unsupported runner architecture '${RUNNER_ARCH:-}'; builds exist for X64 and ARM64" ;;
esac

if [ "$os" = windows ]; then asset="ayinbox_${os}_${arch}.zip"; bin=ayinbox.exe; else asset="ayinbox_${os}_${arch}.tar.gz"; bin=ayinbox; fi

if [ -n "${AYINBOX_CLI_BASE_URL:-}" ]; then
  base="${AYINBOX_CLI_BASE_URL%/}"
elif [ "$version" = latest ]; then
  base="https://github.com/${REPO}/releases/latest/download"
else
  base="https://github.com/${REPO}/releases/download/${version}"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

curl -fsSL --retry 3 -o "$work/$asset" "$base/$asset" || die "could not download $base/$asset"
curl -fsSL --retry 3 -o "$work/checksums.txt" "$base/checksums.txt" || die "could not download $base/checksums.txt, so the archive cannot be verified"

want=$(awk -v f="$asset" '$2 == f || $2 == "*"f { print $1 }' "$work/checksums.txt" | head -1)
[ -n "$want" ] || die "checksums.txt has no entry for $asset"
if command -v sha256sum >/dev/null 2>&1; then
  got=$(sha256sum "$work/$asset" | awk '{print $1}')
else
  got=$(shasum -a 256 "$work/$asset" | awk '{print $1}')
fi
[ "$want" = "$got" ] || die "checksum mismatch for $asset (expected $want, got $got); nothing was installed"
echo "checksum verified for $asset"

mkdir -p "$work/x" "$dest"
if [ "$os" = windows ]; then
  unzip -q "$work/$asset" -d "$work/x"
else
  tar -xzf "$work/$asset" -C "$work/x"
fi
[ -f "$work/x/$bin" ] || die "the archive did not contain $bin"
cp "$work/x/$bin" "$dest/$bin"
chmod 0755 "$dest/$bin"

installed=$("$dest/$bin" version 2>/dev/null | head -1 | awk '{print $2}' || true)
echo "$dest" >> "${GITHUB_PATH:-/dev/null}"
{
  echo "bin=$dest/$bin"
  echo "version=${installed:-unknown}"
} >> "${GITHUB_OUTPUT:-/dev/null}"
echo "installed ayinbox ${installed:-} to $dest/$bin"
