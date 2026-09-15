# Phase 07 — Export

Implemented and locally verified on 14 September 2026. With this phase the local workflow **import → organise → cull → edit → export** exists end to end in code. Phase 05's open items (eyedropper, interactive crop, in-Edit 100% inspection) and live UI verification of Phases 05 to 07 remain.

## Delivered

- **Export…** in the File menu (Shift-Cmd-E) and the workspace header acts on the selected, visible photographs in their displayed order. Each file is rendered from the photograph's saved recipe through the same engine as the Edit preview.
- **Format and quality**: JPEG with a 50–100% quality slider (default 92%), or TIFF (lossless). Output is 8-bit sRGB with the profile embedded. The renderer's JPEG quality is now part of `RenderSpecification` rather than fixed.
- **Size**: original size (render at source resolution, never upscaled) or fit the longest edge to a pixel value.
- **Filename template** with `{name}`, `{index}` (zero-padded to the export count), `{project}`, `{date}` (capture date, else import date) and `{rating}`; a live example in the sheet. Path separators and colons are replaced so a template cannot escape the folder; a blank template falls back to the original name.
- **Metadata policy**: None; Caption and keywords (XMP Dublin Core `dc:description` and `dc:subject`); or Camera data plus caption and keywords, carrying the original's capture metadata. Location (GPS) is excluded unless explicitly included. Orientation and pixel-dimension tags never carry over because the render is already upright.
- **Existing files**: Skip (default, reported), Keep both (numbered suffix), or Replace. Writes go to a hidden temporary file and are moved into place, so a failed write never leaves a partial export under the final name.
- **Background queue** with progress, the current filename, Stop, and a report listing failures per file and skipped files, plus Show in Finder. Settings persist between exports; the folder is chosen each time. Edits remain usable while an export runs.
- The writer copies the renderer's encoded bytes without re-encoding when attaching metadata, so exported pixels are identical to the engine's output.

## Checks

| Check | Result |
| --- | --- |
| Native test suite | 43 tests: 41 passed, 2 optional fixture helpers skipped |
| Naming | Tokens, zero padding, capture-date and import-date fallback, sanitisation of `../` and `:`, blank template fallback, and Skip/Keep both/Replace resolution |
| Rendered export | A 64×32 JPEG original with orientation 6, camera EXIF, GPS and an exposure +1 edit exports as an upright 32×64 sRGB JPEG whose pixels equal the renderer's direct output and whose mid grey is brightened |
| Metadata policies | Camera policy carries Make/Model and drops GPS unless requested; caption and keywords appear as XMP; descriptive policy carries no camera data; None writes no XMP |
| Size and format | Fit to 40 px produces 20×40; TIFF export decodes with the requested dimensions; original size leaves 32×64 |
| Conflicts | Second run with Skip reports 1 skipped; Keep both writes `-1`; Replace overwrites |
| Safety | Original bytes and the saved recipe are unchanged after five exports |
| Failures and cancellation | A photograph whose original has vanished is reported per file with the recovery message; Stop ends a 20-file export early with an explicit summary |
| Unsigned Xcode Debug build | Passed |

Exported files were verified by decoding them with ImageIO, which is what Preview, Finder and Quick Look use, and on 15 September 2026 with a non-Apple toolchain: Pillow 12 (libjpeg, libtiff) via `scripts/qa-export-check.py` on samples from the opt-in `testCreateOptionalExportSamples`. Every file decoded fully; dimensions matched (32×64 upright JPEGs, a 20×40 TIFF); the camera policy carried Make and dropped GPS unless requested; the None policy carried no EXIF and no XMP; captions and keywords were present in the XMP packet of the other policies.

Two findings from the external decode, both recorded here rather than changed: the JPEGs carry no embedded ICC profile and are instead tagged sRGB through the Exif ColorSpace field (value 1), which ImageIO reports as an sRGB profile name; the TIFF does embed sRGB. And the TIFF is written as RGBA with an opaque alpha channel. Both are acceptable for the JPEG proof; an explicitly embedded JPEG profile and an alpha-free TIFF are candidates for the full-GDD export options. A print-service upload remains a manual step.

## Native UI verification

Not performed for the sheet itself. Open items: the sheet at the minimum window size, persisted settings across launches, folder choice on an external drive, and Stop during a long RAW export. Opening the results outside NTO is covered by the external decode above.

## Limits

- Colour profile is sRGB only; no Display P3 or Adobe RGB output, no 16-bit TIFF, no export presets, and no watermark. These are full-GDD scope after the JPEG proof.
- Export acts on the current selection. To export a whole project or collection, filter to it and Select All.
- Metadata carries the original's EXIF/TIFF tags as ImageIO maps them; IPTC fields other than caption and keywords are not written.
- The exporter reads each recipe from the saved journal, so an in-progress slider gesture is finalised before export starts.
