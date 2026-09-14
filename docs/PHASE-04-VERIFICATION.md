# Phase 04 — Rendering and saved edit state

Implemented and locally verified on 14 September 2026. The next phase is the full editing experience, not Cloud publishing.

## Delivered

- Asynchronous original-to-image renderer using CIRAWFilter/Core Image, outside SwiftUI.
- Defined v1 decode/camera/tone/colour/detail/geometry/effects/output semantics, bounded parameters and explicit sRGB output. Existing fields retain version 1; shared fixtures now contain neutral and edited recipes.
- One photographic graph for preview and full-resolution JPEG/PNG/TIFF results, with resizing only at output.
- Bounded render caching, original fingerprint verification, cancellation and protection against stale completions.
- Additive local edit journals, immediate autosave, persistent undo/redo, and gesture coalescing.
- Exposure, contrast and saturation controls in Edit, with saved revision, reset, progress and retry states. These prove the engine; the full Light/Colour/Detail/Geometry control set belongs to Phase 05.
- Missing-original and unsupported/corrupt recipe handling that retains original files and saved edits.
- Small adjacent fix: Cull's U shortcut explicitly supplies `PhotoFlag.none`, resolving Swift's ambiguity with an optional nil flag.

## Checks

| Check | Result |
| --- | --- |
| Native test suite | 28 behavioural tests passed; 2 optional fixture helpers skipped |
| Xcode Debug build, signing disabled | Passed |
| Shared model/token generation checks and TypeScript/Cloud contract tests | Passed (6 tests) |
| Type checking across TypeScript workspaces | Passed |
| Existing project/photo/collection migration | Automated Phase 03 schema upgrade passed; existing app library opened |
| Edited preview versus downsampled full output | Passed; mean comparison error below 2/255 in 8-bit sRGB on generated imagery |
| Deterministic repeated renders and cache identity | Passed; same recipe produces the same encoded result; changed parameters at the same revision do not reuse it |
| Geometry, colour profile and original-byte integrity | Passed on generated imagery |
| Missing original → saved adjustment → restore original → retry | Passed; recipe retained and rendering recovered |
| Unsupported saved recipe | Rejected without overwriting its stored bytes |
| History and coalesced gesture recovery across reopening | Passed |
| Superseded completion from a cancellation-insensitive renderer | Passed; older result cannot replace current preview |

Commands: `./scripts/pnpm test:studio`, `./scripts/pnpm build:studio`, `./scripts/pnpm test`, `./scripts/pnpm typecheck`.

## Native UI verification

Opened the existing Canon EOS 5D Mark IV CR2 in Edit with neutral adjustments and visually confirmed an actual developed image. Personal photograph adjustments were left unchanged. This qualifies that file on this Mac, not all Canon RAW or CR3 files.

Used generated Study-03 artwork for editing: exposure changed to +1 EV and visibly updated; Command-Z restored zero; Shift-Command-Z restored +1. Focus Mode preserved the edited view and restored controls. In a metadata sheet, Command-Z restored text without undoing the photograph. After quitting and reopening, Edit restored +1 EV and its saved revision; Command-Z still restored the previous zero-EV state, proving persisted undo in the running app.

The automated history tests cover continuous gesture coalescing. The native coordinate-drag automation did not reliably exercise the slider, so manual pointer-drag acceptance remains unverified. Accessible slider increments and native undo/redo were verified.

## Limits and follow-up

See [rendering semantics and limits](RENDERING.md). Native RAW development was checked at neutral settings on one existing CR2; RAW colour/exposure quality, additional cameras including CR3, full-shoot performance, and colour-critical output need further qualification. Image comparison tests use generated non-RAW fixtures, not a camera reference corpus.

The renderer can produce full-resolution encoded results, but there is no export destination/filename/quality dialog yet. Library/Cull continue to show original previews; Edit shows the recipe result. Advanced controls, crop UI, before/after, presets, batch edits and user export remain later phases.

Web production/browser tests and local database integration tests were not rerun: this milestone changes native rendering plus shared recipe validation, not web behavior or database migrations. Existing GitHub Actions run the expanded native suite and shared checks on push; remote CI status is separate from these local results.
