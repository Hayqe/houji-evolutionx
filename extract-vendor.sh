#!/usr/bin/env bash
# Extraheert de vendor blobs voor houji uit een stock HyperOS-ROM.
#
# Ondersteunt twee ROM-formaten:
#   - fastboot-ROM  (.tgz)  → bevat images/*.img (direct bruikbaar)
#   - recovery-zip  (.zip)  → bevat payload.bin → payload-dumper-go
#
# Gebruik: ./extract-vendor.sh <pad/naar/rom.zip|rom.tgz>
set -euo pipefail
cd "$(dirname "$0")"

ROM="${1:-}"
if [ -z "$ROM" ] || [ ! -f "$ROM" ]; then
  echo "Gebruik: $0 <pad/naar/rom.zip|rom.tgz>" >&2
  echo "  recovery-zip : $0 ~/Downloads/miui_HOUJI_..._eea.zip" >&2
  echo "  fastboot     : $0 ~/Downloads/houji_..._fastboot_....tgz" >&2
  exit 1
fi

# Dump staat in src/ zodat de container hem ziet op /src/vendor-dump
DUMP="$(pwd)/src/vendor-dump"
mkdir -p "$DUMP"

echo "== ROM-formaat bepalen =="
case "$ROM" in
  *.tgz|*.tar.gz)
    echo "Fastboot-ROM gedetecteerd — images/*.img uitpakken..."
    tar -xzf "$ROM" -C "$DUMP" --strip-components=1 images/ 2>/dev/null || true
    # valt terug: sommige fastboot-ROM's hebben de images in de root
    [ -n "$(find "$DUMP" -maxdepth 2 -name '*.img' -print -quit 2>/dev/null)" ] || tar -xzf "$ROM" -C "$DUMP"
    ;;
  *.zip)
    echo "Recovery-zip gedetecteerd — payload.bin extraheren..."
    if ! command -v payload-dumper-go >/dev/null 2>&1; then
      echo "ERROR: payload-dumper-go ontbreekt." >&2
      echo "  Installeer: go install github.com/ssut/payload-dumper-go@latest" >&2
      echo "  (of download de binary van https://github.com/ssut/payload-dumper-go/releases)" >&2
      exit 1
    fi
    unzip -o "$ROM" payload.bin -d "$DUMP"
    echo "payload.bin uitpakken (duurt even)..."
    payload-dumper-go -o "$DUMP" "$DUMP/payload.bin"
    rm -f "$DUMP/payload.bin"
    ;;
  *)
    echo "ERROR: onbekend formaat '$ROM' (verwacht .zip of .tgz)" >&2
    exit 1
    ;;
esac

echo
echo "== Aanwezige images in $DUMP/ =="
find "$DUMP" -maxdepth 2 -name '*.img' -printf '  %f\n' 2>/dev/null | sort | head -40

echo
echo "== Blobs extraheren (in de container) =="
echo "De device trees staan in de container op /src. Draai:"
echo
echo "  docker exec houji-builder bash -c '"
echo "    cd /src/device/xiaomi/houji && ./extract-files.py --dump /src/vendor-dump"
echo "    cd /src/device/xiaomi/sm8650-common && ./extract-files.py --dump /src/vendor-dump"
echo "  '"
echo
echo "Na extractie staan de blobs in vendor/xiaomi/houji en vendor/xiaomi/sm8650-common"
echo "(commit ze naar een eigen repo en voeg die toe aan local_manifests/houji.xml)."
