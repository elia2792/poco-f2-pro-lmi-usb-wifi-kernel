#!/system/bin/sh
set -u
EXPECTED="#2 SMP PREEMPT Sat Nov 14 00:20:01 CET 2026"
[ "$(uname -v)" = "$EXPECTED" ] || exit 0

MODDIR="${0%/*}/modules"
LOG=/data/local/tmp/poco-usb-wifi-loader.log
mkdir -p /data/local/tmp
echo "=== $(date) | kernel $(uname -v) ===" >> "$LOG"

# Load modules in strict dependency order; skip if already loaded.
MODULES="
eeprom_93cx6
ath
ath9k_hw
ath9k_common
ath9k_htc
carl9170
mt76
mt76-usb
mt76x2-common
mt76x2u
mt76x0
mt7601u
rt2x00lib
rt2x00usb
rt2800lib
rt2800usb
rtl8187
rtl8xxxu
btbcm
btintel
btrtl
btusb
ch341
pl2303
"

for name in $MODULES; do
  proc_name=$(printf '%s' "$name" | tr '-' '_')
  if grep -q "^${proc_name} " /proc/modules; then
    echo "$name already loaded" >> "$LOG"
    continue
  fi
  if [ -f "$MODDIR/$name.ko" ]; then
    if insmod "$MODDIR/$name.ko" >> "$LOG" 2>&1; then
      echo "$name loaded" >> "$LOG"
    else
      echo "WARN: failed to load $name" >> "$LOG"
    fi
  fi
done
