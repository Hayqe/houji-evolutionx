#!/usr/bin/env bash
# Bouwt de EvolutionX-ROM voor houji (sync + build) in de bestaande Docker-container.
set -euo pipefail
cd "$(dirname "$0")"

# Start de container als die nog niet draait
if ! docker ps --format '{{.Names}}' | grep -qx houji-builder; then
  if docker ps -a --format '{{.Names}}' | grep -qx houji-builder; then
    echo "Starting bestaande houji-builder container..."
    docker start houji-builder
  else
    echo "Creating houji-builder container..."
    docker run -d --name houji-builder \
      --security-opt apparmor:unconfined \
      --cap-add SYS_ADMIN \
      --device /dev/fuse \
      -v "$(pwd)/src:/src" \
      -v "$(pwd)/ccache:/ccache" \
      evolutionx-builder sleep infinity
  fi
fi

LOG="$(pwd)/src/build-$(date +%Y%m%d-%H%M%S).log"

docker exec houji-builder bash -c '
  set -e
  cd /src
  export USE_CCACHE=1 CCACHE_DIR=/ccache CCACHE_EXEC=/usr/bin/ccache

  echo "=== repo sync ==="
  repo sync -c -j16 --force-sync --no-clone-bundle --no-tags

  echo "=== build (m evolution -j16) ==="
  source build/envsetup.sh
  lunch lineage_houji-userdebug
  ccache -M 50G
  m evolution -j16
' 2>&1 | tee "$LOG"

echo
echo "Log: $LOG"
echo "Output zip: $(pwd)/src/out/target/product/houji/EvolutionX-16.0-*-houji-11.11-Unofficial.zip"

# Vraag of de release gepubliceerd moet worden (upload + OTA-JSON).
echo
read -r -p "Release publiceren (SourceForge-upload + OTA-JSON naar GitHub)? [j/N] " REPLY
if [[ "$REPLY" =~ ^[Jj]$ ]]; then
  PUBLISH=1 ./release.sh
fi
