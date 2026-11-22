# POCO F2 Pro (`lmi`) — Kali NetHunter Kernel (USB Wi-Fi `ath9k_htc` + `qcacld-3.0`)

Open-source **Kali NetHunter** kernel overlay, build configuration, Magisk guarded autoloader, and AnyKernel3 packaging for **POCO F2 Pro / Redmi K30 Pro (`lmi`, SM8250)** running **LineageOS 23.2** (Android 16, Linux `4.19.325-cip131-st15-perf-g71b13e62f057`).

> **WARNING — DEVICE CHECK:** This kernel is strictly for **POCO F2 Pro / Redmi K30 Pro (`lmi`)**. **Do NOT flash** on POCO F3 (`alioth`), Mi 10T (`apollo`), or other SM8250 devices. Always back up your stock `boot` partition before flashing.

---

## What Was Done (Engineering Summary / Cosa è stato fatto)

This project started from the stock LineageOS 23.2 kernel for `lmi` (`LineageOS/android_kernel_xiaomi_sm8250`, commit `71b13e62f057a649b77fe4062feb73ee72ad609c`) and solved several real-world porting, toolchain, and driver issues step by step:

1. **Reproducible Bootable Baseline (Toolchain & Filesystem Fixes)**
   - Building the exact stock kernel source with Debian Clang 21.1.8 produced an ARM64 `Image` with identical size and headers that hung on a black screen during `fastboot boot`.
   - Switching to the official **Android Clang/LLD `21.0.0 r563880c`** (matching LineageOS's build toolchain) with `LLVM=1 LLVM_IAS=1`, `CC="clang --target=aarch64-linux-gnu"` (required so Kconfig enables `CONFIG_RELR=y`), and serial LLD (`LD="ld.lld --threads=1"` to avoid ThinLTO crashes) produced a verified bootable baseline with strict CFI preserved and matching `vermagic` (`-g71b13e62f057`) so vendor modules (`rmnet_perf`, `rmnet_shs`) load cleanly.
   - Identified and resolved macOS case-insensitive APFS collisions across 13 kernel filename pairs (e.g., `net/netfilter/xt_DSCP.c` vs `xt_dscp.c`) by building exclusively on a case-sensitive volume.

2. **Internal `qcacld-3.0` Frame-Injection Overlay (`overlay/`, 58 paths)**
   - Ported the `FEATURE_FRAME_INJECTION_SUPPORT` HDD/WMA overlay with a hardened TX buffer ownership state machine (`wma_injection_tx_state.h`, tested with ASan/UBSan across 2,000 concurrent interleavings).
   - Fixed routing (descriptor `0` remains normal `MGMT_TXRX`; only `0x2xxx` is injection), enforced `require_monitor_mode=1` by default, fixed rate-limit timing to QDF milliseconds, deferred cleanup safely after `hif_disable`, and fixed duplicate HDD/WMA TX counters (`frames_submitted=1 / frames_transmitted=1`, firmware `COMPLETE_OK`).

3. **External USB Wi-Fi OTG Support (`ath9k_htc` / AR9271)**
   - Enabled `CONFIG_MAC80211=y` (Minstrel HT rate control) and modular Atheros USB drivers (`CONFIG_ATH_COMMON=m`, `CONFIG_ATH9K_HW=m`, `CONFIG_ATH9K_COMMON=m`, `CONFIG_ATH9K_HTC=m`).
   - Embedded `ath9k_htc/htc_9271-1.4.0.fw` (51,008 bytes) into the kernel image via `CONFIG_EXTRA_FIRMWARE` so firmware loads reliably without Android userspace firmware-path issues.
   - **Why modular (`=m`) instead of built-in (`=y`)?** Compiling `ath9k_htc` directly into `vmlinux` fails at LTO link due to duplicate symbol collisions (`htc_start`, `htc_stop`, `htc_connect_service`) with Qualcomm's built-in `qcacld-3.0` HTC layer. Building the `ath9k` stack as loadable modules cleanly avoids this conflict.

4. **Guarded Magisk Autoload Module (`magisk-module/`)**
   - Created `poco_lmi_usb_wifi`, a reversible Magisk module whose `service.sh` checks the exact `uname -v` string before loading `ath.ko`, `ath9k_hw.ko`, `ath9k_common.ko`, and `ath9k_htc.ko` in dependency order. If you reboot back to the stock kernel, the module safely skips loading.

5. **Hardware Verification on POCO F2 Pro (`lmi`)**
   - Verified with a **TP-Link TL-WN722N v1.10** (Atheros AR9271, USB ID `0cf3:9271`) over USB OTG:
     - DWC3 host mode + xHCI enumeration, firmware 1.4 transfer (33 HTC credits), `wlan1` interface creation (`wlan0` remains internal Qualcomm Wi-Fi).
     - Live `iw dev wlan1 set type monitor` <-> `managed` transitions.
     - Passive 802.11 beacon capture and authorized directed Probe Request / Probe Response TX/RX exchange on channel 1.
   - Post-install stability & subsystem checks: 5+ days continuous uptime observed, internal Wi-Fi, camera, Bluetooth, NFC, 57 hardware sensors, and USB ADB confirmed working.

---

## Panoramica in Italiano

Questo repository pubblica il porting completo del kernel **Linux 4.19** per **POCO F2 Pro (`lmi`)** su **LineageOS 23.2** con:
- supporto **USB Wi-Fi OTG** (`mac80211` + moduli `ath9k_htc` + firmware `htc_9271-1.4.0.fw` integrato) verificato su **TP-Link TL-WN722N v1.10** (monitor mode, cattura passiva e TX/RX);
- overlay `qcacld-3.0` con gestione sicura della concorrenza/ownership dei buffer TX;
- modulo Magisk `poco_lmi_usb_wifi` con controllo esatto su `uname -v` per caricare automaticamente i 4 moduli `.ko` in ordine di dipendenza;
- pacchetto **AnyKernel3** generico (nella sezione **Releases**) che sostituisce solo `Image` preservando il tuo ramdisk, Magisk e DTB.

---

## Repository Layout

```text
.
├── README.md                  # Documentation (overview, install, build, dev notes)
├── LICENSE                    # GNU General Public License v2.0
├── configs/
│   ├── usb-wifi-v1.config     # Exact verified .config used for build #2
│   └── usb-wifi-v1.diff       # Minimal Kconfig diff vs stock LineageOS 23.2 config
├── overlay/                   # 58 modified/added kernel files + manifest.json
├── magisk-module/             # Guarded Magisk autoloader sources (module.prop, service.sh)
├── anykernel3/
│   └── anykernel.sh           # AnyKernel3 config for POCO F2 Pro (lmi)
└── scripts/
    ├── apply-overlay.py       # Applies overlay/ + .scmversion onto upstream sm8250 source
    └── build-kernel.sh        # Reproducible Image + modules build script
```

---

## Installing the Prebuilt Release

Download from **GitHub Releases** and verify `SHA256SUMS.txt`:
1. `AnyKernel3-poco-f2-pro-lmi-usb-wifi-v1.zip` — flashes only the compiled `Image`, preserving your existing ramdisk (including Magisk) and DTB.
2. `poco_lmi_usb_wifi_v1.zip` — Magisk module containing `ath.ko`, `ath9k_hw.ko`, `ath9k_common.ko`, and `ath9k_htc.ko` built against the exact release kernel.

### Steps
1. **Back up your stock `boot` partition first** (via `dd` with root or recovery).
2. Flash `AnyKernel3-poco-f2-pro-lmi-usb-wifi-v1.zip` in a compatible custom recovery (e.g., TWRP/OrangeFox) or via a kernel flasher app (Franco Kernel Manager / Kernel Flasher).
3. Install `poco_lmi_usb_wifi_v1.zip` in **Magisk Manager** -> *Modules* -> *Install from storage*.
4. Reboot. Plug in your TL-WN722N v1.10 over OTG: it will appear as `wlan1`.

### Rollback
To return to stock, flash your backed-up `boot.img` in fastboot:
```bash
fastboot flash boot working-boot.img
fastboot reboot
```
Because `poco_lmi_usb_wifi` checks `uname -v`, it automatically does nothing on the stock kernel.

---

## Building & Modifying from Source

### Prerequisites
- **Case-sensitive filesystem** (Linux `ext4`/`btrfs`, or an APFS Case-Sensitive sparseimage on macOS).
- **Android Clang/LLD `21.0.0 r563880c`** (from AOSP `prebuilts/clang`).
- **Firmware**: `htc_9271-1.4.0.fw` from `linux-firmware`.

### Build Steps
```bash
# 1. Clone pinned upstream LineageOS sm8250 kernel
git clone https://github.com/LineageOS/android_kernel_xiaomi_sm8250.git kernel-src
git -C kernel-src checkout 71b13e62f057a649b77fe4062feb73ee72ad609c

# 2. Apply the overlay and .scmversion
python3 scripts/apply-overlay.py --kernel-src ./kernel-src

# 3. Place the AR9271 firmware where CONFIG_EXTRA_FIRMWARE_DIR expects it
mkdir -p ./out/firmware/ath9k_htc
cp /path/to/htc_9271-1.4.0.fw ./out/firmware/ath9k_htc/

# 4. Build Image + loadable modules
CLANG_BIN=/path/to/clang-r563880c/bin \
KERNEL_SRC=./kernel-src \
KERNEL_OUT=./out \
bash scripts/build-kernel.sh
```

### Extending / Adding More USB Wi-Fi Adapters
- Run `make ... menuconfig` on `out/.config` to enable additional `mac80211` USB drivers (e.g., `CONFIG_RT2800USB=m`, `CONFIG_MT7601U=m`, `CONFIG_RTL8XXXU=m`, or out-of-tree `rtl88xxau`) as **modules (`=m`)**.
- Whenever you rebuild the kernel, `uname -v` changes: update the `EXPECTED="..."` line in [`magisk-module/service.sh`](magisk-module/service.sh) and bundle the newly compiled `.ko` files under `modules/` inside your Magisk ZIP.

---

## License & Disclaimer

- Licensed under the **GNU General Public License v2.0** ([LICENSE](LICENSE)), consistent with the Linux kernel.
- Intended strictly for educational use, personal hardware experimentation, and **authorized** security testing on networks you own or have explicit written permission to test.
