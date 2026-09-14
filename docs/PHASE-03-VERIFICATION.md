# Phase 03 — Organisation, metadata and culling

Implemented and locally verified on 14 September 2026. This is the local culling milestone, not Studio v0.1 or the full ecosystem CORE release.

## Working capabilities

- Projects show a cover, creation date and photo count. Search project names in the sidebar; use a project's context menu to choose the selected photograph as its cover.
- Create, rename, move earlier/later and remove manual collections through the Collections menu. Add selected photographs to multiple collections; remove memberships without deleting originals.
- Persist 0–5 ratings, pick/reject/clear flags, favourites, captions and keywords. Capture metadata remains read-only. Annotations belong to the asset and are shared when that asset belongs to multiple projects.
- Apply Library ratings and flags to the visible selection. The metadata editor explicitly offers replacement across selected photographs. Hidden selected photographs are excluded from bulk changes.
- Search filenames, captions, keywords, camera and lens. Filter minimum rating, flag, favourites, camera, media type and a capture-date substring. Capture dates currently use their original EXIF spelling, e.g. `2026:09`; this is not a date-range/calendar control. Sort by import time, filename, capture date or rating.
- Save query, collection, selection, scroll position and density per project. Library and Cull share the same query. Filtering preserves stored selection; Cull advances when an annotation removes its active photo from the current filter.
- Cull using Left/Right, 0–5, P (pick), X (reject), U (clear flag), F (favourite), and Space (Fit/100%). A hideable filmstrip and previous/next buttons provide pointer access. Tab restores the previous sidebar/inspector state.
- Preload nearby working previews in both directions. Metadata commits run independently of image decoding. Full-resolution inspection decodes one oriented original off the UI thread, outside the thumbnail cache, and displays one image pixel per display pixel. Scroll horizontally/vertically to inspect.

## Automated verification

Run `./scripts/pnpm test:studio` and `./scripts/pnpm build:studio`.

The suite contains 22 tests: 20 behavioural tests pass, with two optional fixture-generation helpers skipped by default. Native Debug build succeeds with code signing disabled.

New coverage includes persistence across reopening, global asset annotations, multiple collections, duplicate membership, ordering after removal, removal without losing photographs, rejection of cross-project membership and covers, transactional rollback, combined filters, hidden-selection safety, project query isolation, rapid culling writes, Phase 02 schema migration, and oriented full-resolution decoding without populating the preview disk cache.

The existing 10,000-record synthetic database check also saves 50 ratings and reads them back. An observed local run opened the library in approximately 1.0 second and saved those ratings in approximately 0.6 seconds. These are local smoke measurements, not a RAW throughput or frame-rate certification.

## Native UI verification

Used the existing **Import verification** project containing generated artwork. No personal photographs were used for metadata edits.

- Grid keyboard ratings, pick and favourite; selection carried into Cull.
- Cull arrow navigation, reject and rating changes; actual 100% image display.
- Found and fixed focus loss after changing image presentation. Retested arrows and ratings while in 100% inspection and Focus Mode, then restored the sidebar and inspector.
- Created a collection, added a photograph, and verified its member count and filtered filmstrip.
- Edited caption and comma-separated keywords in a sheet; typing did not trigger culling shortcuts.
- Searched the saved keyword and switched back to Library with the same query, collection and selection.
- Inspected a narrow window layout and restored its previous size.
- Final relaunch retained the selected collection, keyword filter, active photograph, rating, caption and keywords. Existing projects and photos remained available. Database reopen tests additionally cover chosen-cover persistence.

## Boundaries and remaining qualification

Original files are never rewritten by these operations. New additive SwiftData models store annotations, queries, collections, memberships and project cover references. Collection removal cascades only collection membership records.

100% inspection requires access to a decodable original at its recorded dimensions and currently accepts images up to 120 megapixels. Failure is reported; a lower-resolution preview is never labelled 100%. This uses system ImageIO decoding, not a new RAW development or edit pipeline. Canon CR3 qualification, complete real-shoot acceptance, mixed-camera performance, colour-critical rendering and distribution signing remain outstanding.

No web or Cloud implementation changed, so their suites were not rerun for this native milestone. Remote CI results are separate from these local results. The next implementation phase is the renderer and persistent edit-state engine; editing tools, undo/history, JPEG export, sync and publishing are still ahead.
