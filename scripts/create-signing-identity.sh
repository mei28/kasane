#!/bin/bash
# Creates the self-signed code signing identity that `just install` signs kasaned with.
# macOS ties the Input Monitoring grant to the signature. A stable identity keeps the grant
# across rebuilds; an ad-hoc signature changes with every build.
#   scripts/create-signing-identity.sh "kasane code signing"
set -euo pipefail

name="${1:?usage: create-signing-identity.sh <common name>}"
keychain="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$name" "$keychain" >/dev/null 2>&1; then
  echo "error: the login keychain already has a certificate named \"$name\"" >&2
  exit 1
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# /usr/bin/openssl is LibreSSL, whose PKCS#12 defaults `security import` accepts.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -subj "/CN=$name" \
  -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -keyout "$workdir/key.pem" -out "$workdir/cert.pem"
/usr/bin/openssl pkcs12 -export -inkey "$workdir/key.pem" -in "$workdir/cert.pem" \
  -out "$workdir/identity.p12" -passout pass:transfer

# -T lets codesign use the key without asking each time.
security import "$workdir/identity.p12" -k "$keychain" -P transfer -T /usr/bin/codesign
