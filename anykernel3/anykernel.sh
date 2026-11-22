### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## Configured for POCO F2 Pro / Redmi K30 Pro (lmi) — LineageOS 23.2 (kernel 4.19)

### AnyKernel setup
# global properties
properties() { '
kernel.string=POCO F2 Pro (lmi) USB Wi-Fi (ath9k_htc) + qcacld-3.0 Injection Kernel
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=lmi
device.name2=lmipro
device.name3=lmiin
device.name4=lmiinpro
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties

### AnyKernel install
## boot shell variables
block=/dev/block/bootdevice/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install — replaces ONLY the kernel Image, preserving existing ramdisk (including Magisk) and DTB
split_boot;
flash_boot;
## end boot install
