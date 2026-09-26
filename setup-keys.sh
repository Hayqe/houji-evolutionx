#!/usr/bin/env bash
# Kopieert de release-signing keys naar de build-tree (src/vendor/evolution-priv/keys/)
# en schrijft keys.mk. EvolutionX pikt dit automatisch op via
# `-include vendor/evolution-priv/keys/keys.mk` → de build wordt met release-keys
# getekend. Bevat ook de AVB-key (ruwe RSA-4096 PEM), gebruikt door de device-tree fork.
#
# Gebruik: ./setup-keys.sh
set -euo pipefail
cd "$(dirname "$0")"

CERTS="${ANDROID_CERTS:-$HOME/.android-certs-houji}"
DEST="src/vendor/evolution-priv/keys"

if [ ! -d "$CERTS" ]; then
  echo "Fout: geen keys gevonden in $CERTS." >&2
  echo "Genereer ze eerst (development/tools/make_key), of zet ANDROID_CERTS." >&2
  exit 1
fi

mkdir -p "$DEST"

# APK/OTA-signing keys (.pk8 + .x509.pem).
n=0
for f in "$CERTS"/*.pk8 "$CERTS"/*.x509.pem; do
  [ -e "$f" ] || continue
  cp -f "$f" "$DEST/" && n=$((n+1))
done

# AVB-key: apart formaat (ruwe RSA-4096 PEM, PKCS#1).
if [ ! -f "$CERTS/avb.pem" ]; then
  echo "Genereren AVB-key ($CERTS/avb.pem)..."
  openssl genrsa -out "$CERTS/avb.pem" 4096 2>/dev/null
  openssl rsa -in "$CERTS/avb.pem" -traditional -out "$CERTS/avb.pem.tmp" 2>/dev/null
  mv "$CERTS/avb.pem.tmp" "$CERTS/avb.pem"
  chmod 600 "$CERTS/avb.pem"
fi
cp -f "$CERTS/avb.pem" "$DEST/avb.pem" && n=$((n+1))

cat > "$DEST/keys.mk" <<'EOF'
# Release signing keys (EvolutionX).
PRODUCT_DEFAULT_DEV_CERTIFICATE := vendor/evolution-priv/keys/releasekey
PRODUCT_EXTRA_RECOVERY_KEYS := vendor/evolution-priv/keys/releasekey
EOF

echo "OK: $n keys gekopieerd naar $DEST/ + keys.mk geschreven."
echo "De volgende build wordt automatisch met release-keys getekend (incl. AVB)."
