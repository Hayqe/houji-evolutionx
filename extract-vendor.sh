#!/usr/bin/env bash
# Extraheert de vendor blobs voor houji uit een stock HyperOS-ROM.
#
# Ondersteunt:
#   - fastboot-ROM  (.tgz)  → images/*.img (soms in een submap)
#   - recovery-zip  (.zip)  → payload.bin → payload-dumper-go
#
# Handelt ook super.img af (simg2img + lpunpack), hernoemt _a-partities naar
# slot-loze namen, en draait daarna extract-files.py voor beide device trees.
#
# Gebruik: ./extract-vendor.sh <rom.zip|rom.tgz>
set -euo pipefail
cd "$(dirname "$0")"

ROM="${1:-}"
if [ -z "$ROM" ] || [ ! -f "$ROM" ]; then
  echo "Gebruik: $0 <pad/naar/rom.zip|rom.tgz>" >&2
  echo "  fastboot : $0 ~/Downloads/houji_*_fastboot_*.tgz" >&2
  echo "  recovery : $0 ~/Downloads/miui_HOUJI_*.zip" >&2
  exit 1
fi

# Host-tools uit een (al gebouwde) garnet-tree; pas aan met GARN_BIN indien nodig.
GARN_BIN="${GARN_BIN:-/home/hayke/dev/garnet/src/out/host/linux-x86/bin}"

DUMP="$(pwd)/src/vendor-dump"
WORK="$DUMP/work"

# Schone start
rm -rf "$DUMP"
mkdir -p "$WORK" "$DUMP/dump"

echo "== ROM uitpakken =="
case "$ROM" in
  *.tgz|*.tar.gz)
    echo "Fastboot-ROM — uitpakken..."
    tar -xzf "$ROM" -C "$WORK"
    ;;
  *.zip)
    echo "Recovery-zip — payload.bin extraheren..."
    if ! command -v payload-dumper-go >/dev/null 2>&1; then
      echo "ERROR: payload-dumper-go ontbreekt." >&2
      echo "  go install github.com/ssut/payload-dumper-go@latest" >&2
      exit 1
    fi
    unzip -o "$ROM" payload.bin -d "$WORK"
    payload-dumper-go -o "$WORK" "$WORK/payload.bin"
    rm -f "$WORK/payload.bin"
    ;;
  *)
    echo "ERROR: onbekend formaat '$ROM' (verwacht .zip of .tgz)" >&2
    exit 1
    ;;
esac

echo "== images verzamelen =="
find "$WORK" -name '*.img' -exec mv -f {} "$DUMP/dump/" \;

# super.img uitpakken als die er is (dynamische partitie → losse images)
if [ -f "$DUMP/dump/super.img" ]; then
  echo "super.img gevonden — uitpakken met simg2img + lpunpack..."
  if [ ! -x "$GARN_BIN/simg2img" ] || [ ! -x "$GARN_BIN/lpunpack" ]; then
    echo "ERROR: simg2img/lpunpack niet gevonden in $GARN_BIN" >&2
    echo "       (garnet-build nodig, of zet GARN_BIN naar de juiste out/host/linux-x86/bin)" >&2
    exit 1
  fi
  export LD_LIBRARY_PATH="$(dirname "$GARN_BIN")/../lib64:${LD_LIBRARY_PATH:-}"
  "$GARN_BIN/simg2img" "$DUMP/dump/super.img" "$WORK/super_raw.img"
  mkdir -p "$WORK/unpacked"
  "$GARN_BIN/lpunpack" "$WORK/super_raw.img" "$WORK/unpacked"
  for img in "$WORK/unpacked/"*_a.img; do
    [ -e "$img" ] || continue
    mv -f "$img" "$DUMP/dump/$(basename "$img" _a.img).img"
  done
  rm -f "$DUMP/dump/super.img"
fi

echo
echo "== images in $DUMP/dump/ =="
ls -1 "$DUMP/dump/"*.img 2>/dev/null | sed 's#.*/##' | sort

echo
echo "== blobs extraheren (in de container) =="
docker exec houji-builder bash -c '
  cd /src/device/xiaomi/houji && ./extract-files.py /src/vendor-dump/dump
  cd /src/device/xiaomi/sm8650-common && ./extract-files.py /src/vendor-dump/dump
'

echo
echo "Klaar. Blobs staan in src/vendor/xiaomi/houji en src/vendor/xiaomi/sm8650-common."
echo "Commit ze naar een eigen repo en voeg die toe aan local_manifests/houji.xml."
