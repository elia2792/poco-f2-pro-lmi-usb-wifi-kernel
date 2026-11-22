#!/system/bin/sh
set -eu
EXPECTED="#2 SMP PREEMPT Sat Nov 14 00:20:01 CET 2026"
[ "$(uname -v)" = "$EXPECTED" ] || exit 0
MODDIR="${0%/*}/modules"
LOG=/data/local/tmp/poco-usb-wifi-loader.log
mkdir -p /data/local/tmp
echo "kernel $(uname -v)" >> "$LOG"
for name in ath ath9k_hw ath9k_common ath9k_htc; do
  if grep -q "^$name " /proc/modules; then
    echo "$name already loaded" >> "$LOG"
    continue
  fi
  insmod "$MODDIR/$name.ko" >> "$LOG" 2>&1
  echo "$name loaded" >> "$LOG"
done
