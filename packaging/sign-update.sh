#!/usr/bin/env bash
# Writes dist/update-manifest.txt and signs it: dist/update-manifest.txt.sig. The app checks that signature with
# the public key built into it before it installs an update (see wrapper/update/updatecontroller.h).
#
# Usage:  ./packaging/sign-update.sh 2.4
# Needs:  UPDATE_SIGNING_KEY_BASE64   the key file, in base64
#         UPDATE_SIGNING_KEY_PASSWORD its password
# The release workflow runs this with its two secrets. A key that does not match the public key in the app
# stops here: every copy of the app would refuse that update.
set -euo pipefail

VERSION="${1:?usage: $0 <version>   for example: $0 2.4}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

key="$(mktemp)"
public="$(mktemp)"
trap 'rm -f "$key" "$public"' EXIT
printf '%s' "$UPDATE_SIGNING_KEY_BASE64" | base64 -d > "$key"
openssl pkey -in "$key" -passin env:UPDATE_SIGNING_KEY_PASSWORD -pubout -out "$public"

expected="$(sed -n 's/^#define UPDATE_PUBLIC_KEY "\(.*\)"$/\1/p' "$ROOT/wrapper/update/updatecontroller.cpp")"
actual="$(openssl pkey -pubin -in "$public" -outform DER | tail -c 32 | od -An -tx1 | tr -d ' \n')"
if [ -z "$expected" ] || [ "$actual" != "$expected" ]; then
  echo "The signing key does not match the public key in updatecontroller.cpp. Nothing was signed." >&2
  exit 1
fi

cd "$ROOT/dist"

TARBALL="ChaoticNotepad-$VERSION-linux-x86_64.tar.xz"
APPIMAGE="ChaoticNotepad-$VERSION-x86_64.AppImage"

sha() { sha256sum -- "$1" | cut -d' ' -f1; }
{
  echo "ChaoticNotepad update manifest 1"
  echo "version $VERSION"
  echo "tarball $TARBALL $(sha "$TARBALL")"
  echo "appimage $APPIMAGE $(sha "$APPIMAGE")"
} > update-manifest.txt

openssl pkeyutl -sign -inkey "$key" -passin env:UPDATE_SIGNING_KEY_PASSWORD \
  -rawin -in update-manifest.txt -out update-manifest.txt.sig
openssl pkeyutl -verify -pubin -inkey "$public" -rawin -in update-manifest.txt -sigfile update-manifest.txt.sig > /dev/null

echo "Signed the update for version $VERSION."
