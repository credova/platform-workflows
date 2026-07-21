#!/bin/bash
set -euo pipefail

# Install opengrep at a pinned version with signature verification.
#
# We deliberately do NOT use opengrep's upstream install.sh: it resolves the
# release list via an unauthenticated `curl https://api.github.com/.../releases`
# and never reads GITHUB_TOKEN, so on shared runners it hits the 60 req/hr API
# limit and fails with "Failed to fetch available versions from GitHub". Passing
# `-v` doesn't help - the installer still calls the same endpoint to validate.
#
# Instead we fetch a pinned release asset via `gh release download`, which is
# authenticated with the runner token (far above the 60 req/hr unauthenticated
# cap) and takes no dependency on the rate-limited unauthenticated path. cosign
# then verifies the binary's signature before we install it.
#
# Version is pinned here intentionally - bump it deliberately.

OPENGREP_VERSION="v1.25.0"
OPENGREP_REPO="opengrep/opengrep"

# Both tools are provided by earlier steps (gh is preinstalled on GitHub-hosted
# runners; cosign by the sigstore/cosign-installer step). Fail with an
# actionable message if either is missing - e.g. a self-hosted runner without
# gh - rather than a bare "command not found".
for tool in gh cosign; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "::error::$tool is required to install opengrep but was not found on PATH" >&2
    exit 1
  fi
done

# Map OS/arch to the release asset name (mirrors opengrep's install.sh).
OS="$(uname -s)"
ARCH="$(uname -m)"
DIST=""
case "$OS" in
  Linux)
    if ldd /bin/sh 2>&1 | grep -qi musl; then LIBC="musllinux"; else LIBC="manylinux"; fi
    case "$ARCH" in
      x86_64|amd64)   DIST="opengrep_${LIBC}_x86" ;;
      aarch64|arm64)  DIST="opengrep_${LIBC}_aarch64" ;;
    esac
    ;;
  Darwin)
    case "$ARCH" in
      x86_64|amd64)   DIST="opengrep_osx_x86" ;;
      aarch64|arm64)  DIST="opengrep_osx_arm64" ;;
    esac
    ;;
esac

if [ -z "$DIST" ]; then
  echo "Unsupported OS/arch for opengrep: ${OS}/${ARCH}" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Authenticated download of the binary plus its cosign cert/signature.
gh release download "$OPENGREP_VERSION" --repo "$OPENGREP_REPO" \
  --pattern "$DIST" --pattern "$DIST.cert" --pattern "$DIST.sig" \
  --dir "$TMP"

# Verify the signature before trusting the binary. A bad or missing signature
# fails the install (set -e) - we never fall back to an unverified binary.
cosign verify-blob \
  --cert "$TMP/$DIST.cert" \
  --signature "$TMP/$DIST.sig" \
  --certificate-identity-regexp "https://github.com/opengrep/opengrep.+" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  "$TMP/$DIST"

BIN_DIR="$HOME/.opengrep/bin"
mkdir -p "$BIN_DIR"
install -m 0755 "$TMP/$DIST" "$BIN_DIR/opengrep"
echo "$BIN_DIR" >> "$GITHUB_PATH"

echo "Installed:"
"$BIN_DIR/opengrep" --version
