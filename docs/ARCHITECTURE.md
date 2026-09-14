# Architecture

## Platform boundaries

| Surface | Stack | Responsibility |
| --- | --- | --- |
| Studio | Swift 6, SwiftUI, macOS 26+, SwiftData, Core Image | Workspace, local project/photo persistence, import, organisation and culling, original previews, recipe rendering, saved edit history |
| Web | Next.js 16 App Router, React 19, TypeScript, CSS Modules | Portfolio/Gallery route shells |
| Cloud | Supabase Postgres, Auth, private Storage, TypeScript Edge Functions | Remote records, ownership, project API, health |
| Shared | JSON Schema, TypeScript interfaces, generated Swift Codable models, JSON tokens | Versioned interchange and consistent design |

`apps/studio/NTOFoundation` is a local Swift package. The Xcode application composes workspace state, repository, and views; it does not contain image processing. `PhotoRenderer` accepts a local original reference, recipe, and output specification asynchronously. Since Phase 04 its implementation is `CoreImageRenderer`, described under [Phase 04 rendering and edit history](#phase-04-rendering-and-edit-history) and in [RENDERING.md](RENDERING.md).

`ProjectStore` owns SwiftData operations on the main actor, with explicit saves and rollback after failure. Project title validation runs before mutation. Local projects need no Cloud account. No sync or automatic upload is performed.

## Interchange

`packages/shared-types/schema.json` is the canonical contract v1 schema. TypeScript interfaces mirror it. `pnpm models` generates native Codable types and copies the canonical fixture into Swift test resources; `models:check` detects drift. A property with a schema `default` that is left out of `required` is additive: the generator decodes it with `decodeIfPresent` and the default, the TypeScript interface marks it optional, and validators treat absence as the default. That is how the Phase 05 tonal fields were added without a version bump; changing the meaning of an existing field still requires one. UUIDs identify entities; timestamps are ISO 8601 strings. Both recipe and envelope versions are checked during native decoding, and JSON Schema rejects unsupported versions.

Asset is the original identity; EditRecipe is versioned edit state; Rendition is replaceable derived output; Publication records destination and order. Collections hold references rather than file copies. Local URLs exist only in native renderer inputs, never public DTOs. Database rows use snake_case; project adapters explicitly map to camelCase DTOs.

Rendition jobs define source object key, recipe revision, target format/dimensions, and success/error result. Workers are not implemented. Studio now has a Core Image original/recipe renderer for previews and full-resolution encoded output; future image workers will resize those outputs in a separate runtime. Supabase Edge Functions are unsuitable for heavy rendering or Sharp: https://supabase.com/docs/guides/functions/limits.

## Cloud persistence and access

Auth users own all records. Row-level policies require `auth.uid() = owner_id`; composite foreign keys prevent relationships crossing owners. Anonymous roles have no table grants. Public website shells use fixtures only; even a database publication marked public is not exposed until a publication delivery API is implemented.

Original and rendition buckets are private. Authenticated object reads/inserts require an owner UUID prefix. No client overwrite/delete policy is installed. An original's established object key, asset ID, and owner cannot change. Derived replacements must use new object keys. Local collection removal cascades membership records, never files.

Supabase's project REST API supplies create/read operations through matching Swift and TypeScript adapters. Clients receive a publishable key and user access token. Service-role credentials belong only to backend administration or isolated local integration tests. The foundation does not store user tokens or implement sign-in UI.

The health function returns service name, status, and contract version, with no credentials or configuration. It is a liveness check, not a claim that storage/database dependencies are healthy.

## Failure and future work

Swift store errors reach an actionable alert. Cloud adapters classify failed requests; network/server failures can be retried. Web route errors offer retry and navigation. Future sync must journal work, handle conflicts explicitly, and publish replacements only after successful rendition creation. None of those deferred operations is simulated as completed here.

## Phase 02 local photographic Library

`LocalPhoto`, `LocalPhotoMembership`, and `LocalBrowsingState` extend the SwiftData schema without changing existing projects. Project membership is relational and indexed by project UUID; identical content has one local photo identity and can belong to multiple projects. The local models contain filesystem/bookmark state and are deliberately separate from public Codable contracts.

`PhotoImportWorker` performs discovery, streaming SHA-256 hashing, metadata reads, and copy preparation on an actor. Each managed original lives in its own UUID directory. A partial file is flushed and atomically renamed before its database record is committed. Failed/cancelled items remove their uncommitted copy; committed photographs remain. Before the next import after a crash, recovery removes only unreferenced UUID directories in this library's managed Originals directory. It never cleans source folders or committed originals. Symbolic links and packages inside imported folders are not followed; unreadable folders and unsupported regular files are reported.

`LibraryController` serializes main-actor persistence and publishes import state. It commits per photograph and refreshes the grid in batches. References use read-only security-scoped bookmarks, with source access held during import. Relinking requires the same SHA-256 fingerprint and retains the photo ID and metadata. Existing content added to another project retains its original storage choice and caption. There is no automatic conversion from reference to copy.

`PhotoPreviews` uses ImageIO downsampling with orientation transforms. The grid requests 512-pixel thumbnails; selected-image screens request up to 2,000-pixel original previews. The decoded cache has a 64 MiB cost limit and 300-entry limit; derived JPEG disk cache is capped at 256 MiB. Visible tiles release their local image state on disappearance, and a small viewport neighbourhood is prefetched. Cached previews can remain visible with an original offline; the inspector checks source availability. New previews from references verify their content fingerprint and refuse changed source bytes. These are original previews, not edited renders or full-resolution focus inspection.

Browsing state saves after a 250 ms debounce and flushes on project changes, backgrounding, and ordinary termination. The latest small browsing change can be lost on an immediate force-quit; committed import records do not depend on that debounce. Studio currently uses one workspace window so import coordination and store ownership remain unambiguous. The last project preference is restored if the project still exists.

Platform references: [Apple ImageIO thumbnail creation](https://developer.apple.com/documentation/imageio/cgimagesourcecreatethumbnailatindex(_:_:_:)) and [read-only security-scoped bookmarks](https://developer.apple.com/documentation/foundation/nsurl/bookmarkdata(options:includingresourcevaluesforkeys:relativeto:)).

## Updated long-term architecture direction

The [owner's master context](MASTER-CONTEXT.md) establishes a portability goal while retaining the current Apple-native implementation. This section records design constraints for future work; no package extraction, renderer rewrite, shader backend, or new platform was implemented for the context update.

### Current implementation versus intended shared core

`NTOFoundation` currently includes SwiftData, ImageIO, SwiftUI/AppKit views and native services. It is **Apple-only**, not a portable NTO Core package. As boundaries become useful, candidates for extraction include Core, Catalog, Metadata, EditRecipe, Presets, Sync, and Cloud clients. Shared packages should avoid SwiftUI, AppKit, UIKit, Core Image, or Metal dependencies unless explicitly platform-specific. A portable project/interchange format is separate from the native database and security-scoped filesystem access.

### Imaging and renderer/decoder boundaries

The canonical recipe describes photographic intent (for example exposure in EV, white balance, tone, detail, and normalized crop), not a serialized chain of CIFilter identifiers. Rendering stays asynchronous and outside views. A future RAW decoder boundary should permit Apple-native decoding now and another implementation later.

The long-term GPU preference is **Metal on Apple** and **Vulkan on Windows/Android/Linux**. The current Core Image/ImageIO approach remains appropriate for the Mac proof of concept; this preference does not require replacing it now or implementing Vulkan. DirectX is not the default plan and would require an explicit architecture reconsideration.

A future platform-neutral render graph should define algorithms, parameter meanings, colour handling, and stage ordering separately from backend shader code. The master context's graph is conceptual; it does not silently replace the GDD's existing versioned pipeline order. Settle precise semantics as the edit engine is implemented. Cross-backend equivalence must be measured with agreed image/colour tolerances, reference renders, and performance checks, not assumed from using the same parameter names.

Canon CR3 is a compatibility target requiring real file/camera qualification. Successful CR2 preview import does not certify CR3 decoding or RAW edit/export parity.

### Optional hosted ecosystem

Supabase remains the agreed initial Cloud foundation. Keep local work independent of sessions or service availability. Add publication, rendition, sync, and secure delivery capabilities after the local workflow is reliable; no new hosting stack is selected here. Keep heavy image/ZIP processing in suitable worker runtimes.

Later Commerce builds on stable Asset IDs and publication/delivery policies. Server-verified, idempotent payment callbacks drive paid orders and asset entitlements; neither browser prices nor a success page authorize delivery. Signed URLs are delivery mechanisms, not purchase identity. Provider choice, refunds/revocation, payouts, taxes, and access policy details remain to be designed for the intended markets.

Mobile is a companion focused on cull, quick edits, publish/review, Gallery management, and activity/sales rather than a reduced-size desktop UI. Windows starts with portable core/project/decoder/render/export validation before a full native UI. Android/Linux come only when justified. Scale the initial API/database/storage/CDN/worker design according to actual demand rather than hypothetical mass adoption.

## Phase 03 local organisation

`LocalPhotoAnnotation` stores asset-wide ratings, flags, favourites, keywords and an optional caption override without rewriting `LocalPhoto` originals. `LocalCollection` and its relational `LocalCollectionItem` records contain project-scoped membership, validated against the project's assets. Their removal never deletes photographs. `LocalProjectPresentation` references a chosen cover. `LocalLibraryQuery` stores a Codable filter/sort/collection query separately from existing browsing state. All are additive schema changes, tested against the Phase 02 store.

`LibraryController` owns the visible result and selection. It rebuilds the result when photos, query or collections change; annotation commits update in-memory records without refetching the full catalog on every key. Hidden selected IDs survive filtering but are excluded from bulk writes. Cull changes only the active visible photograph and advances when it leaves the filter.

`PhotoPreviews.fullResolution` provides uncached, oriented original decoding for pixel inspection, with a 120-megapixel input limit and exact dimension checks. It does not implement photographic edit rendering. Working previews are prefetched near the active photograph. A window-scoped AppKit event monitor handles Cull shortcuts across fit/pixel-view replacement; SwiftUI owns state, and sheets/text editors retain their normal keys. The monitor is removed when its view leaves the workspace.

## Phase 04 rendering and edit history

`CoreImageRenderer` implements `PhotoRenderer` on an actor with an explicit colour-managed v1 graph and bounded encoded-result cache. `OriginalReference` may carry a local security bookmark and expected fingerprint; these remain private native inputs. `RecipeSemantics` validates the canonical v1 values, also checked by the generated Swift decoder and the TypeScript validator/schema.

`LocalEditState` adds a Codable per-asset journal without changing existing original records. `EditHistory` stores exact parameter snapshots and coalesces gestures; revision numbers increase through undo/redo. `EditController` coordinates persistence and supersedable render tasks. SwiftUI reads its preview and status; controls do not own Core Image objects or database operations. Text editors retain native undo, while the photograph has persisted edit undo/redo in Edit mode.

See [rendering semantics](RENDERING.md) and [Phase 04 verification](PHASE-04-VERIFICATION.md) for precise pipeline order, colour/geometry decisions and remaining limits.

## Phase 05 editing controls

`EditGroup` names the Light, Colour, Detail and Geometry inspector groups; `EditRecipe.reset(_:)` and `isNeutral(_:)` give each group a one-operation reset. `EditController.apply(_:)` is the single mutation path: it copies the current recipe, applies the change, validates through `EditHistory.set`, autosaves and requests a preview. Typed helpers (`setTemperature`, `setCrop`, `setRotation`, `rotate(by:)`, `reset(_:)`) normalise input before applying: Kelvin clamps to the recipe range, rotation wraps into (−180, 180], and crops clamp to a positive rectangle inside the unit square, so user entry never produces an invalid recipe or a rejected save. `isComparing` is view state on the controller and never touches the recipe; the original shown while comparing is the Library's cached working preview. `EditWorkspace` binds sliders and numeric fields to these helpers and reuses Cull's window-scoped key monitor for the backslash shortcut, Escape, Return and Space.

`CropGeometry` is pure arithmetic in normalized image coordinates: fitted image rectangle, handle hit-testing, resizing with an optional height-per-width factor that keeps a pixel aspect around the anchored side, largest-fit for a preset, and the inverse mapping from a point on the cropped-then-rotated render back to the original. A `CropSession` on the controller holds the pending rectangle; `previewRecipe` renders uncropped and unrotated while it exists, and only `commitCrop` touches history. `WhiteBalanceSampler` solves the raster eyedropper by minimising chroma through the same `CITemperatureAndTint` stage the renderer applies (coarse grid, then shrinking coordinate search), and defers to `CIRAWFilter.neutralLocation` for RAW. 100% inspection is a second render request at full size that follows recipe changes; it is cleared when inspection ends.

## Phase 06 presets and batch edits

`EditParameter` names every adjustable field and maps it to its group; `RecipeAdjustments` is a dictionary from parameter to a portable `ParameterValue` (number, `null` for as-shot white balance, or a crop object). `EditRecipe.adjustments(for:)` extracts a subset and `apply(_:)` writes one back, touching nothing else. `EditPreset` wraps a named subset with a format version and is stored by `PresetStore` as one JSON file per preset under the library's `Presets` folder; the format is specified in [PRESETS.md](PRESETS.md). Presets never reference assets, so deleting one cannot affect a recipe.

`EditController.apply(_ adjustments:)` is the single application path for presets, Paste and the open photograph during a sync; it records one undo step. `previewAdjustments` renders a candidate recipe for hover without touching history. `BatchEditController` applies a subset to other photographs' saved journals on the main actor in yielding batches of ten, records each resulting revision, and `revertLast` undoes only photographs still at that revision. `LibraryController.syncEdits` splits a selection between the editor (for the open photograph, whose in-memory history must stay authoritative) and the batch controller, and `revertLastSync` recombines them.

## Phase 07 export

`ExportSpecification` (format, quality, sizing, filename template, metadata policy, location opt-in, conflict policy) is Codable so the sheet can persist it. `ExportNaming` is pure: token substitution, date fallback, sanitisation that cannot escape the folder, and Skip/Keep both/Replace resolution against an injectable existence check. `ExportController` runs one item at a time: read the saved recipe, render through `PhotoRenderer` at the export size (the renderer's `RenderSpecification` now carries JPEG quality), then `ExportWriter` attaches metadata with `CGImageDestinationCopyImageSource`, which copies the encoded bytes without re-encoding, into a hidden temporary file that is moved into place. Camera metadata comes from the original's own tags with orientation and pixel-dimension tags removed and GPS excluded unless requested; caption and keywords are written as XMP Dublin Core. Failures are recorded per item and never stop the queue; cancellation stops between items. `LibraryController.export` finalises any slider gesture, takes the selected visible photographs in display order, and hands them to the exporter; the workspace shows `ExportStatus` beneath the header.
