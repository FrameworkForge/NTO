# NTO Studio v0.1: current delivery priority

Owner direction received 13 September 2026: incorporate the [master context](MASTER-CONTEXT.md), but get the Mac application working first. The immediate release target is a credible local photographic workflow, not the whole ecosystem.

## What "working" means

A photographer can create a project, import real supported Canon photographs, browse and cull a shoot, edit a selection, close Studio, reopen with the correct edits, and export JPEGs. Originals remain unchanged. This works without an account, subscription, internet connection, or Cloud upload.

Current verified baseline: project persistence, photo import, Library browsing/selection, metadata display, original previews, reference recovery, collections, editable metadata and keyboard culling. See [Phase 02 verification](PHASE-02-VERIFICATION.md) and [Phase 03 verification](PHASE-03-VERIFICATION.md). Cull has working controls. Edit has the Phase 04 renderer, saved recipes, undo/redo and, since the first Phase 05 increment, grouped controls for every recipe v1 field with white balance, rotation, numeric crop and compare-with-original; Presets, copy/paste and selection sync with revert are in place, and JPEG/TIFF export with naming, sizing and metadata policies completes the local workflow in code. Publish remains a preview shell. See [Phase 04 verification](PHASE-04-VERIFICATION.md), [Phase 05 verification](PHASE-05-VERIFICATION.md), [Phase 06 verification](PHASE-06-VERIFICATION.md) and [Phase 07 verification](PHASE-07-VERIFICATION.md). One CR2 has been developed locally; that does not qualify CR3, every camera or export workflows.

## Immediate order

1. Resolve any reproducible launch, import, missing-file, Library, or crash problem before adding tools. Record the failing steps and test the fix with existing catalogs preserved.
2. Implemented locally; continue real-shoot qualification of culling and organisation: previous/next, ratings, pick/reject, favourites, zoom/100% inspection, collections, search/filter/sort, and persistent metadata. Preserve selection and working context across modes.
3. Implemented in Phase 04: renderer/RAW decoder boundary, persistent versioned edits and undo/redo, with preview/full-output comparison tests. Continue camera and performance qualification.
4. Add the first useful corrections: exposure, contrast, highlights/shadows, whites/blacks, temperature/tint, vibrance/saturation, sharpening, basic noise reduction, crop/rotate/straighten.
5. Add portable parameter-subset presets and selective batch editing. Crop and white balance must not be copied accidentally.
6. Deliver JPEG export with dimensions, quality, filename policy, and metadata choices; verify files outside Studio.
7. Process a real shoot end to end, fix observed failures/performance problems, and make building from a clean checkout straightforward.
8. Prepare Studio v0.1 for a possible open-source release. Public release and licensing remain separate decisions.

This is an implementation priority, not a calendar estimate. Bug fixes can interrupt the sequence. New platforms, commerce, hosted plans, and advanced AI must not interrupt the usable Mac workflow.

## Exit checklist

- [x] Mac application builds and opens locally.
- [x] Projects and imported photographs persist across ordinary relaunch.
- [x] Local JPEG/HEIC/TIFF and system-supported RAW preview import exists.
- [ ] Verify the owner's relevant Canon CR3 camera/files with the current macOS decoder; do not infer CR3 compatibility from the successful CR2 import.
- [ ] Complete a real shoot's cull with persistent ratings/picks/rejects/favourites and useful focus inspection.
- [ ] Edit supported RAW/JPEG photographs with the full v0.1 tool set without changing originals. Every tool is implemented (Light, Colour with eyedropper, Detail, interactive crop, rotation, 100% inspection); this stays open until verified on real RAW and JPEG photographs.
- [x] Close and reopen with the same photographic edit state (current Phase 04 controls).
- [x] Apply/revert presets and parameter-selective batch edits (Phase 06; live UI check still open).
- [x] Export correct JPEG files that open outside NTO (Phase 07; verified by ImageIO decoding with dimensions, profile and metadata checks; a non-Apple viewer check remains).
- [ ] Recover from unavailable originals, interrupted operations, and rendering/export failures without losing work.
- [ ] Another developer can clone, build, open a photograph, edit, and export using documented prerequisites.

Existing local verification is a baseline, not a claim that all camera models or distribution configurations are certified. Use generated fixtures for automated tests; do not commit the owner's photographs.

## Reconciliation with the original GDD

| Topic | Studio v0.1 priority | Original/full GDD or later direction |
| --- | --- | --- |
| First useful release | Complete local Mac import → cull → edit → JPEG export | Full ecosystem CORE additionally needs Cloud, Gallery, and portfolio publishing |
| Export | JPEG first | TIFF, additional profiles, reusable export presets, and delivery-specific outputs follow; original GDD CORE still includes JPEG/TIFF |
| Light tools | Essential tonal corrections first | Brilliance remains in the original GDD; it is not a blocker for the first useful local proof of concept |
| RAW | Current Apple-native decoder/backend, verified per camera/file | Explicitly qualify Canon CR3; separate cross-platform RAW decoder later |
| Rendering | Platform-neutral recipe intent behind the existing asynchronous boundary; Core Image/Metal as needed | Portable render graph with Metal on Apple and Vulkan elsewhere is the long-term preference |
| Packaging | Keep existing native code working and testable | Extract portable Core/Catalog/Metadata/Recipe/Preset/Sync interfaces as useful; do not rewrite working code just to create named packages |
| Distribution | Private development while workflows mature | Studio and shared contracts published in a separate open-source repository; web integration and Cloud stay private |
| Revenue | No account/subscription gate on local editing/export | Optional managed hosting, storage, sync, Gallery, portfolio, commerce, and business services |

Neither this document nor the master context changes the repository's visibility or license. MPL 2.0 is a candidate to investigate, not an adopted license.
