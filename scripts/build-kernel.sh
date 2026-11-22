#!/usr/bin/env bash
# Reproducible build script for POCO F2 Pro (lmi) USB Wi-Fi + qcacld-3.0 overlay kernel.
# Requires:
#   - Case-sensitive filesystem (Linux ext4/btrfs/etc., or APFS Case-Sensitive sparseimage on macOS)
#   - Official Android Clang/LLD 21.0.0 r563880c in PATH (or set CLANG_BIN)
#   - ath9k_htc/htc_9271-1.4.0.fw placed in $FIRMWARE_DIR/ath9k_htc/htc_9271-1.4.0.fw
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_SRC="${KERNEL_SRC:?Set KERNEL_SRC to your prepared sm8250 kernel source tree}"
KERNEL_OUT="${KERNEL_OUT:-$REPO_ROOT/out}"
FIRMWARE_DIR="${FIRMWARE_DIR:-$KERNEL_OUT/firmware}"
CLANG_BIN="${CLANG_BIN:-}"
JOBS="${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu)}"

if [[ -n "$CLANG_BIN" ]]; then
    export PATH="$CLANG_BIN:$PATH"
fi

if [[ ! -r "$FIRMWARE_DIR/ath9k_htc/htc_9271-1.4.0.fw" ]]; then
    echo "ERROR: Missing firmware file: $FIRMWARE_DIR/ath9k_htc/htc_9271-1.4.0.fw" >&2
    echo "Fetch htc_9271-1.4.0.fw from linux-firmware and place it there before building." >&2
    exit 1
fi

mkdir -p "$KERNEL_OUT"
cp "$REPO_ROOT/configs/usb-wifi-v1.config" "$KERNEL_OUT/.config"

# Point CONFIG_EXTRA_FIRMWARE_DIR to the local firmware directory
python3 - "$KERNEL_OUT/.config" "$FIRMWARE_DIR" <<'PY'
import sys
from pathlib import Path
cfg = Path(sys.argv[1])
fw_dir = sys.argv[2]
lines = cfg.read_text(encoding="utf-8").splitlines()
out = []
for line in lines:
    if line.startswith("CONFIG_EXTRA_FIRMWARE_DIR="):
        out.append(f'CONFIG_EXTRA_FIRMWARE_DIR="{fw_dir}"')
    else:
        out.append(line)
cfg.write_text("\n".join(out) + "\n", encoding="utf-8")
PY

MAKE_ARGS=(
    -C "$KERNEL_SRC"
    O="$KERNEL_OUT"
    ARCH=arm64
    LLVM=1
    LLVM_IAS=1
    CC="clang --target=aarch64-linux-gnu"
    LD="ld.lld --threads=1"
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    -j"$JOBS"
)

make "${MAKE_ARGS[@]}" olddefconfig
make "${MAKE_ARGS[@]}" Image modules

echo "Build complete:"
echo "  Image:   $KERNEL_OUT/arch/arm64/boot/Image"
echo "  Modules: $KERNEL_OUT/drivers/net/wireless/ath/{ath.ko,ath9k/ath9k_hw.ko,ath9k/ath9k_common.ko,ath9k/ath9k_htc.ko}"
