#!/usr/bin/env python3
"""Decode Studio exports with a non-Apple toolchain (Pillow: libjpeg, libtiff) and report what they contain.

Usage: NTO_QA_EXPORT_DIR=/path swift test --filter ExportTests/testCreateOptionalExportSamples
       python3 scripts/qa-export-check.py /path
"""
import sys, pathlib
from PIL import Image, ExifTags
folder = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")
files = sorted(p for p in folder.iterdir() if p.suffix.lower() in {".jpg", ".jpeg", ".tif", ".tiff"})
if not files:
    sys.exit(f"no exports found in {folder}")
failures = 0
for path in files:
    try:
        with Image.open(path) as image:
            image.load()  # forces a full decode through libjpeg / libtiff
            exif = image.getexif()
            make = exif.get(ExifTags.Base.Make)
            orientation = exif.get(ExifTags.Base.Orientation)
            gps = bool(exif.get_ifd(ExifTags.IFD.GPSInfo))
            try:
                xmp = image.getxmp()
            except Exception:
                xmp = {}
            description = str(xmp).find("Morning light") >= 0
            profile = "sRGB" if (image.info.get("icc_profile") and b"sRGB" in image.info["icc_profile"]) else ("none" if not image.info.get("icc_profile") else "other")
            print(f"{path.name:28} {image.format:5} {image.size[0]}x{image.size[1]} mode={image.mode} profile={profile} make={make!r} gps={gps} orientation={orientation} caption={description}")
    except Exception as error:
        failures += 1
        print(f"{path.name:28} FAILED to decode: {error}")
sys.exit(1 if failures else 0)
