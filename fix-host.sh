#!/usr/bin/env bash
# Herstelt de host-voorwaarden voor een AOSP/ROM-build:
#   1. extra 32 GB swap (/swapfile2), persistent in /etc/fstab
#   2. systemd-oomd uit (service + socket gestopt en gemaskerd)
#
# Idempotent: veilig om meerdere keren te draaien.
# Gebruik: sudo ./fix-host.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Dit script moet als root draaien. Gebruik: sudo $0" >&2
  exit 1
fi

SWAP="/swapfile2"
SWAP_SIZE="32G"

# --- 1. Extra swap ---------------------------------------------------------
if [ -f "$SWAP" ]; then
  echo "✓ $SWAP bestaat al — aanmaken overgeslagen."
else
  echo "Aanmaken $SWAP ($SWAP_SIZE)..."
  fallocate -l "$SWAP_SIZE" "$SWAP"
  chmod 600 "$SWAP"
  mkswap "$SWAP"
fi

if swapon --show | grep -qF "$SWAP"; then
  echo "✓ $SWAP is al actief."
else
  echo "Activeren swap $SWAP..."
  swapon "$SWAP"
fi

if grep -qF "$SWAP" /etc/fstab; then
  echo "✓ $SWAP staat al in /etc/fstab."
else
  echo "Toevoegen aan /etc/fstab (persistent)..."
  echo "$SWAP none swap sw 0 0" >> /etc/fstab
fi

# --- 2. systemd-oomd uit ---------------------------------------------------
echo "Stoppen + masken van systemd-oomd (service + socket)..."
systemctl stop systemd-oomd.service systemd-oomd.socket 2>/dev/null || true
systemctl mask systemd-oomd.service systemd-oomd.socket

echo
echo "=== Resultaat ==="
echo "--- swap ---"
swapon --show
echo "--- systemd-oomd ---"
echo "service: $(systemctl is-active systemd-oomd.service 2>&1) / $(systemctl is-enabled systemd-oomd.service 2>&1)"
echo "socket:  $(systemctl is-active systemd-oomd.socket 2>&1)"
echo
echo "Klaar. Je kunt nu ./build.sh draaien."
