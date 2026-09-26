#!/usr/bin/env bash
# Publiceert een nieuwe houji-build als OTA-update:
#   1. upload de gebouwde zip naar SourceForge (via SSH/rsync)
#   2. genereert ota/houji.json met de metadata die de EvolutionX-Updater verwacht
#   3. commit + push de JSON (optioneel, zet PUBLISH=1)
#
# Gebruik:  ./release.sh
set -euo pipefail
cd "$(dirname "$0")"

# --- Configuratie -----------------------------------------------------------
DEVICE="houji"
VERSION="11.11"          # = ro.modversion (EVO_VERSION)
MAINTAINER="Hayqe"

# SourceForge (upload via SSH/rsync)
SF_USER="${SF_USER:-hayqe}"
SF_PROJECT="${SF_PROJECT:-houji-evolutionx}"
SF_DIR="${SF_DIR:-}"                  # leeg = projectroot; een submap moet je eerst in de SF-webui aanmaken

# OTA-JSON in deze repo (gehost op raw.githubusercontent.com/.../ota/{device}.json)
OTA_JSON="ota/${DEVICE}.json"
GIT_BRANCH="${GIT_BRANCH:-main}"

# --- Zoek de gebouwde zip ---------------------------------------------------
ZIP="$(ls -t "src/out/target/product/${DEVICE}/EvolutionX-16.0-"*"-${DEVICE}-"*.zip 2>/dev/null | head -n1)"
if [ -z "$ZIP" ]; then
  echo "Fout: geen gebouwde zip gevonden in src/out/target/product/${DEVICE}/" >&2
  exit 1
fi
FILENAME="$(basename "$ZIP")"
echo "Build: $FILENAME"

# --- Metadata ---------------------------------------------------------------
MD5="$(md5sum "$ZIP" | awk '{print $1}')"
SIZE="$(stat -c '%s' "$ZIP")"
TIMESTAMP="$(date +%s)"   # > ro.build.date.utc van de vorige build → update wordt geaccepteerd

# --- Upload naar SourceForge ------------------------------------------------
if [ -n "$SF_DIR" ]; then
  REMOTE_DIR="/home/frs/project/${SF_PROJECT}/${SF_DIR}"
  URL_PREFIX="https://downloads.sourceforge.net/project/${SF_PROJECT}/${SF_DIR}/"
else
  REMOTE_DIR="/home/frs/project/${SF_PROJECT}"
  URL_PREFIX="https://downloads.sourceforge.net/project/${SF_PROJECT}/"
fi

if [ -n "$SF_USER" ] && [ -n "$SF_PROJECT" ]; then
  echo "Uploaden naar SourceForge (${SF_PROJECT}/${SF_DIR:-root})..."
  rsync -avP -e ssh "$ZIP" "${SF_USER}@frs.sourceforge.net:${REMOTE_DIR}/"
  DOWNLOAD_URL="${URL_PREFIX}${FILENAME}"
else
  echo "Waarschuwing: SF_USER/SF_PROJECT niet ingesteld; 'download' blijft leeg." >&2
  DOWNLOAD_URL=""
fi

# --- Genereer OTA-JSON ------------------------------------------------------
mkdir -p "$(dirname "$OTA_JSON")"
cat > "$OTA_JSON" <<EOF
{
  "response": [
    {
      "timestamp": ${TIMESTAMP},
      "filename": "${FILENAME}",
      "md5": "${MD5}",
      "size": ${SIZE},
      "download": "${DOWNLOAD_URL}",
      "version": "${VERSION}",
      "maintainer": "${MAINTAINER}",
      "forum": "",
      "firmware": "",
      "paypal": ""
    }
  ]
}
EOF
echo "OTA-JSON geschreven: $OTA_JSON"

# --- Publiceer de JSON naar GitHub -----------------------------------------
if [ -n "${PUBLISH:-}" ]; then
  git add "$OTA_JSON"
  git commit -m "OTA: ${VERSION} — ${FILENAME}" || true
  git push origin "$GIT_BRANCH"
  echo "OTA-JSON gepusht naar GitHub."
else
  echo "Zet PUBLISH=1 om de JSON automatisch te committen en pushen."
fi
