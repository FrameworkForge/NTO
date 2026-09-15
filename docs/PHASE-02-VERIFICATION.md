# Phase 02: import and Library verification

Implemented and verified locally on 13 September 2026 on Apple silicon, macOS 26.6.2, Xcode 26.6. This record covers the local import/Library milestone, not the GDD CORE release.

## Automated verification

Final ordinary run: **14 behavior tests passed, 2 optional fixture generators skipped, 0 failures**.

- Native Swift package behavior checks cover source-byte preservation, copy/reference storage, content duplicates, shared identity across projects, metadata/orientation, and database reopen.
- JPEG, HEIC, and TIFF fixtures import successfully; malformed/unsupported files are reported without invalidating successful items.
- A cancelled large copy removes its staging directory and leaves the source intact. Cancelling a subsequent import preserves already committed photos.
- Referenced originals report missing files; relinking rejects different contents and accepts identical contents under another filename without changing identity.
- Changed reference contents cannot produce a new preview under the old identity. Derived disk cache stays within its configured byte budget.
- Crash recovery preserves committed managed directories and unrelated folders. Managed paths cannot traverse outside the Originals directory.
- Selection range/toggle semantics, project-specific state, and foundation-to-Library schema migration are verified.
- A 10,000-record file-backed database is opened and selected without loading image pixels. The measured record-load time was approximately 0.94-0.98 seconds in Debug on this Mac; the regression threshold is 5 seconds locally and 20 seconds on hosted CI runners, which measured about 6.3 seconds on GitHub's macOS runner. This measures records, not RAW decoding throughput.
- The unsigned native application builds successfully. Optional manual fixture/stress generators are separate test helpers and are skipped during ordinary test runs.

Commands: `./scripts/pnpm test:studio` and `./scripts/pnpm build:studio`. The existing native CI job runs the expanded package suite; this document does not claim a new hosted CI pass.

## Live interface verification

- The pre-existing local projects opened after migration. Owner-imported photos, including a Canon CR2, were present in the existing project; those photos were not added to source control or Cloud.
- A separate `Import verification` project was created through the import sheet. Selecting a generated-image folder imported 14 images, retained the default caption, and reported its unsupported text file separately.
- The grid displayed image thumbnails and metadata. Shift-arrow selection, Cmd-A, Return to preview, mode changes, and consecutive Tab Focus Mode toggles were checked.
- An ordinary application relaunch restored the verification project, its active photograph, selection, and scroll anchor. Switching back to the owner's project restored its own selection and density.
- A separate temporary library containing 10,000 synthetic records was opened in Studio. Jumping to the final grid rows, range selection near photograph 10,000, preview opening, and return to Library worked.
- The stress window was resized using native window controls. The inspector hid at compact width; the grid stayed usable without overlapping controls. Restoring width restored the inspector and retained selection.
- The normal local library and owner's project were restored after the isolated stress run.

## Limits and deferred work

The stress dataset reuses one generated source image behind unique synthetic records; it tests lazy-grid behavior, selection, and cache requests, not the memory/throughput characteristics of 10,000 distinct RAW originals. No 60 fps certification or broad camera compatibility matrix is claimed. Supported RAW formats depend on the installed macOS/ImageIO decoder. Tests use generated image files, not personal photographs.

The build is unsigned development software. Read-only security-scoped bookmark creation/resolution is exercised locally; sandboxed signed distribution and reconnecting real removable volumes across system restarts need distribution-specific qualification. A stale/missing reference has an explicit Locate original recovery path. A missing managed copy must be restored from backup; it is not silently replaced. Both paths, plus a corrupt edit journal, are exercised end to end in `RecoveryTests` (added 15 September 2026), which also confirms that a same-volume move of a referenced original is followed by its security-scoped bookmark without user action.

Import reports are session state; committed photographs and browsing state are persisted. A force-quit can lose the last debounced browsing update. Orphaned partial copies are recovered before the next import. Drag/drop is implemented using SwiftUI URL transfer; the live import check above used the native folder picker.

Collections, ratings/flags, filtering/search/sorting, 100% culling inspection, edit recipes/rendering, export, Cloud upload/sync, and publishing remain subsequent phases. The other modes currently show original previews and explicitly indicate unavailable tools.
