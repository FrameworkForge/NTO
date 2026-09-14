# Phase 06 — Presets and batch edits

Implemented and locally verified on 14 September 2026. Phase 05's open items (eyedropper, interactive crop, in-Edit 100% inspection, live UI checks) remain listed in [Phase 05 verification](PHASE-05-VERIFICATION.md).

## Delivered

- **Portable presets**: one JSON file per preset in the library's `Presets` folder, format version 1, carrying only the chosen parameters. Format documented in [PRESETS.md](PRESETS.md). Create, rename, delete, export, import and a Show Presets folder action in the Edit presets bar. Unreadable files are reported, not silently skipped; unknown format versions are refused.
- **Parameter selection** for presets and Copy edits: a sheet grouped by Light, Colour, Detail and Geometry with per-group All/None. White balance and geometry are unchecked by default and must be chosen deliberately.
- **Preview before applying**: hovering a preset renders the current photograph with the preset applied and shows it with a "Preset preview" badge; the recipe is untouched until the preset is clicked.
- **Transparent, undoable application**: applying a preset, Paste, or a sync changes only the carried parameters and records one undo step per photograph. Deleting a preset removes its file only.
- **Copy/paste** of a chosen subset between photographs within the session.
- **Sync to selection** in the background with progress, count and Stop; the open photograph is routed through the editor so its in-memory history stays authoritative. Photographs already matching get no new history entry.
- **Revert sync** with a defined strategy: undo the last sync on every photograph still at the synced revision; skip and report any photograph edited afterwards.

## Checks

| Check | Result |
| --- | --- |
| Native test suite | 40 tests: 38 passed, 2 optional fixture helpers skipped |
| Subset semantics | Default subset omits temperature, tint, crop and rotation; applying preserves excluded values; wrong value kinds refused; as-shot white balance round-trips as JSON `null`; format version 2 refused |
| Preset store | Save trims names and rejects empty names or empty subsets; sorted reload; broken file reported while others load; rename; delete leaves an applied recipe intact; export then import keeps both presets with distinct ids |
| Controller | Hover preview leaves the recipe unchanged and clears; preset apply is one undo step and preserves crop; copy/paste of the safe subset leaves a reset crop alone; out-of-range preset value refused with a message |
| Batch | 100 photographs, half with pre-existing crop and white balance: sync returns immediately, completes with 100 outcomes, preserves crops, applies an explicit as-shot white balance, gives exactly one undo step each; after editing one photograph, revert restores 99 and skips 1; syncing already-matching values creates no history |
| Library coordination | Sync with the open photograph selected edits it through the editor and the other in the background; revert covers both |
| Unsigned Xcode Debug build | Passed |

Commands: `swift test --package-path apps/studio/NTOFoundation --scratch-path <outside checkout>` and the `build:studio` command with an out-of-tree derived-data path (see [SETUP.md](SETUP.md)).

The exit gate asks for 100 images without blocking Studio: the automated batch check completes 100 journal updates in about 0.13 s on this Mac with the run yielding to the main loop every ten photographs. No render is involved in a sync, so the cost scales with journal size rather than image size.

## Native UI verification

Not performed, for the same reason as Phase 05. Open items: hover preview timing on a real RAW, sheet layout at the minimum window size, the presets bar with many presets, Stop during a long sync, and the Presets folder round trip through Finder.

## Limits

- Presets are library-local files; there is no preset browser across libraries and no thumbnail strip of preset renders (hover preview only).
- Copy edits is session memory, not the system pasteboard.
- Revert covers the most recent sync only; earlier syncs are undone per photograph.
- Brilliance is not a parameter (deferred by the v0.1 reconciliation).
