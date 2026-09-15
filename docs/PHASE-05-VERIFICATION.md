# Phase 05 — Core editing experience (in progress)

Three increments implemented and locally verified on 14 September 2026. The first added controls for every existing recipe v1 field; the second added the tonal-range and vibrance fields to the contract and renderer; the third added the interactive crop tool, the white-balance eyedropper and in-Edit 100% inspection. With the third, every Phase 05 build task is implemented; live UI verification remains open.

## Third increment: crop tool, eyedropper, 100% inspection

- **Crop tool** (Crop button or Crop tool in Geometry): the preview switches to the uncropped, unrotated edited photograph with a draggable rectangle; corners and edges resize, the interior moves, thirds guides appear while dragging, and the outside is dimmed. Aspect presets (Free, Original, 1:1, 3:2, 4:3, 16:9, 5:4) with a Portrait toggle fit the largest rectangle of that ratio inside the pending one and keep it during corner drags. The numeric fields edit the pending rectangle while the tool is open. **Return** (or Apply crop) commits one undo step; **Escape** (or Cancel crop) leaves the previous crop untouched; an unchanged crop adds no history. Rotation stays a slider and is applied after the committed crop, as recipe v1 defines.
- **Eyedropper** (toolbar toggle or the Eyedropper button next to As shot): click a point that should be neutral. For raster images the sampler averages a 5×5 patch of the oriented original at that point and solves temperature and tint against the same Core Image white-balance stage the renderer uses, so applying the result makes that patch neutral. For RAW it asks the decoder for the neutral at that location (`CIRAWFilter.neutralLocation`). Points on a cropped or rotated preview are mapped back to the original. The result is one undo step; Escape disarms the tool.
- **100% inspection** (100% button or Space, Escape or Space to leave): renders the full edited result and shows it one image pixel per display pixel in a scrollable view, following every recipe change. Cull's 100% shows the original; Edit's shows the edit.

Checks for this increment: native suite 48 tests (46 passed, 2 skipped). Geometry: fitted rectangle, handle hit-testing, free and aspect-locked resizing that keeps the pixel ratio, move and edge clamping, largest-fit for a preset, and mapping displayed points back through crop and 0°/90°/37° rotation. Session: previews uncropped and unrotated, recipe untouched until commit, cancel restores, commit is one clamped undo step, unchanged commit adds nothing. Eyedropper: three casts solved to chroma below 3% through the renderer's stage, a neutral sample stays near 6500 K; on a warm test image the sampled area renders within 6/255 of neutral while a genuinely red patch stays red, as one undo step. Inspection: full image dimensions follow crop and rotation changes; leaving frees the image; starting a crop leaves inspection.

Not verified: the RAW eyedropper path on a real camera file (no RAW fixture; the decoder's location convention needs a check on the owner's CR2), pointer dragging of the overlay, and the tool badges at the minimum window size. The Edit inspector and canvas were captured live against the synthetic library on 15 September 2026 (see [STUDIO-NATIVE-UI.md](STUDIO-NATIVE-UI.md)).

## Second increment: tonal range and vibrance

- Recipe v1 gains `highlights`, `shadows`, `whites`, `blacks` and `vibrance` (−1…1, default 0) as an additive contract change: schema properties with a `default` and outside `required`, optional TypeScript fields, and a generator rule that decodes absent values with their default. Existing edit journals decode unchanged and render identically; encoders always write the fields.
- Renderer: one five-point tone curve after contrast, pinned at the midtone, with whites/blacks moving the end points and shadows/highlights moving the quarter tones; vibrance before saturation. Semantics and amplitudes are recorded in [RENDERING.md](RENDERING.md).
- Light group now has Exposure, Contrast, Highlights, Shadows, Whites, Blacks; Colour group has Temperature, Tint, Vibrance, Saturation. Group reset and undo cover the new fields.
- Brilliance is not added, per the [Studio v0.1](STUDIO-V0.1.md) reconciliation.

Checks for this increment: shared-types tests (7 passed, including a legacy recipe without the fields validating and an out-of-range vibrance rejected by both schema and validator), `models:check` and `tokens:check` clean, TypeScript typecheck clean, native suite 35 tests (33 passed, 2 skipped). The tonal test renders six sRGB bands and confirms: shadows +1 lifts 0.25 by more than 15/255 with 0.5 and 0.95 unchanged; highlights −1 lowers 0.75 with 0.25 and 0.5 unchanged; whites +1 clips 0.95 to white; blacks −1 clips 0.05 to black and +1 lifts it; vibrance +1 increases a muted red's chroma and 0 is a no-op. A legacy JSON recipe without the fields decodes with zeros, re-encodes completely and keeps its group states.

One implementation finding: wrapping the tone curve in linear-to-sRGB conversion double-encoded the values in this engine's working space, so the curve is applied directly and its control points are defined and tested in sRGB-encoded tone.

## Delivered in the first increment

- Edit inspector reorganised into progressively disclosed **Light**, **Colour**, **Detail** and **Geometry** groups. Light is expanded by default; group state is view-local.
- Every group has a **Reset** that restores only its own fields as one undo operation. **Reset all** remains.
- Every parameter has a slider plus a numeric field that commits on Return or focus loss, clamped to the recipe range: Exposure (EV), Contrast, Tint, Saturation, Sharpness, Noise reduction, Rotation (degrees). Slider gestures still coalesce into one undo operation.
- **White balance**: Temperature shows *As shot* when the recipe value is null, with **Adjust** to set an explicit Kelvin value and **Use as shot** to return to null. 6500 K with zero tint leaves a non-RAW image unchanged; lower Kelvin declares a warmer scene neutral and therefore cools the result, matching the renderer semantics in [RENDERING.md](RENDERING.md).
- **Geometry**: rotation slider and numeric entry, **Rotate left/right** quarter turns that wrap within −180…180, and numeric Left/Top/Width/Height crop fields in normalized fractions. Out-of-range crop entries are clamped to a valid rectangle rather than rejected.
- **Compare with original**: press and hold the photograph, click **Show original / Show edit**, or press `\`. The original is the cached working preview; the recipe is never changed. The shortcut uses the same window-scoped key monitor as Cull, so it does not fire inside text fields or sheets.
- Edit mode copy in the workspace no longer describes editing as a later milestone.

All changes flow through one controller entry point that validates, records history, autosaves and re-renders, so undo/redo and persistence cover the new controls without special cases.

## Checks

| Check | Result |
| --- | --- |
| Native test suite | 33 tests: 31 behavioural passed, 2 optional fixture helpers skipped |
| New `EditingTests` | Group reset leaves other groups untouched and is one undo step; temperature clamps to 2,000–50,000 K and returns to null; three quarter turns give −90°; non-finite rotation becomes 0; crop clamps to a valid rectangle; comparing leaves the recipe unchanged; reopened journal matches |
| Renderer white balance and geometry | 6500 K/zero tint leaves a raster image within 1/255 of neutral; 3200 K cools, 12000 K warms; tint alone changes a raster image; ±90° swaps output dimensions, 180° preserves them |
| Unsigned Xcode Debug build | Passed with Xcode 27 beta on macOS 27 |

Commands used: `swift test --package-path apps/studio/NTOFoundation --scratch-path <outside checkout>` and the `build:studio` command with a derived-data path outside the checkout. See the toolchain notes in [SETUP.md](SETUP.md) for why the paths matter on an iCloud-synced checkout.

Web, TypeScript contract and Cloud suites were not rerun: no shared schema, web or database code changed.

## Native UI verification

Not performed for this increment. The development machine had no Xcode selected by default and the owner's library must not be used for automated checks, so the live checks below remain open:

- Slider, numeric entry and Return commit behaviour with a pointer and keyboard.
- Disclosure groups, group reset enablement and Focus Mode with the taller inspector.
- Press-and-hold and `\` comparison on a real RAW file.
- Layout at the 700 × 500 minimum window and with the inspector hidden.

## Not yet delivered (remaining Phase 05)

- **Light**: Brilliance (deferred by the v0.1 reconciliation; would be another additive field).
- **Detail**: refinement after expensive interactions (interactive previews render at 2,000 px; 100% inspection re-renders the full image on every change, which is slow on large RAW files).
- **Geometry**: a draggable straighten interaction on the image (rotation is a slider with numeric entry; a level grid now overlays the canvas while the slider is dragged, added 15 September 2026).
- Keyboard, resize and Focus Mode verification with real photographs, and the RAW eyedropper on a real camera file.

The Light and Colour field set is settled for v0.1, and Phase 06 presets and Phase 07 export are built against it.
