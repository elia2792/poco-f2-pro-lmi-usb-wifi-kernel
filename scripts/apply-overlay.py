#!/usr/bin/env python3
"""Apply the POCO F2 Pro (lmi) kernel source overlay onto a clean upstream tree."""

import argparse
import os
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OVERLAY = ROOT / "overlay"
SCMVERSION = "-g71b13e62f057"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--kernel-src",
        type=Path,
        required=True,
        help="Path to a clean checkout of LineageOS/android_kernel_xiaomi_sm8250 (commit 71b13e62f057a649b77fe4062feb73ee72ad609c)",
    )
    args = parser.parse_args()

    dest = args.kernel_src.resolve()
    if not (dest / "Makefile").is_file() or not (dest / "drivers/staging/qcacld-3.0").is_dir():
        raise SystemExit(f"Not a valid sm8250 kernel tree: {dest}")

    copied = 0
    for src in OVERLAY.rglob("*"):
        rel = src.relative_to(OVERLAY)
        if rel.name == "manifest.json" and len(rel.parts) == 1:
            continue
        target = dest / rel
        if src.is_symlink():
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists() or target.is_symlink():
                target.unlink()
            target.symlink_to(os.readlink(str(src)))
            copied += 1
        elif src.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(str(src), str(target))
            copied += 1

    # Preserve exact stock vermagic suffix so vendor modules (rmnet_perf/rmnet_shs) load cleanly
    scm = dest / ".scmversion"
    scm.write_text(SCMVERSION + "\n", encoding="utf-8")

    print(f"Applied {copied} overlay entries to {dest}")
    print(f"Wrote {scm} ({SCMVERSION})")


if __name__ == "__main__":
    main()
