# Architecture

## Platform boundaries

| Surface | Stack | Responsibility |
| --- | --- | --- |
| Studio | Swift 6, SwiftUI, macOS 26+, SwiftData | Workspace, local project/photo persistence, import, original previews |
| Web | Next.js 16 App Router, React 19, TypeScript, CSS Modules | Portfolio/Gallery route shells |
| Cloud | Supabase Postgres, Auth, private Storage, TypeScript Edge Functions | Remote records, ownership, project API, health |
| Shared | JSON Schema, TypeScript interfaces, generated Swift Codable models, JSON tokens | Versioned interchange and consistent design |

`apps/studio/NTOFoundation` is a local Swift package. The Xcode application composes workspace state, repository, and views; it does not contain image processing. `PhotoRenderer` accepts a local original reference, recipe, and output specification asynchronously. Its foundation implementation explicitly reports unavailable rendering.

`ProjectStore` owns SwiftData operations on the main actor, with explicit saves and rollback after failure. Project title validation runs before mutation. Local projects need no Cloud account. No sync or automatic upload is performed.

## Interchange

`packages/shared-types/schema.json` is the canonical contract v1 schema. TypeScript interfaces mirror it. `pnpm models` generates native Codable types and copies the canonical fixture into Swift test resources; `models:check` detects drift. UUIDs identify entities; timestamps are ISO 8601 strings. Both recipe and envelope versions are checked during native decoding, and JSON Schema rejects unsupported versions.

Asset is the original identity; EditRecipe is versioned edit state; Rendition is replaceable derived output; Publication records destination and order. Collections hold references rather than file copies. Local URLs exist only in native renderer inputs, never public DTOs. Database rows use snake_case; project adapters explicitly map to camelCase DTOs.

Rendition jobs define source object key, recipe revision, target format/dimensions, and success/error result. Workers are not implemented. Studio will render edited masters with Core Image; future image workers will resize those outputs in a separate runtime. Supabase Edge Functions are unsuitable for heavy rendering or Sharp: https://supabase.com/docs/guides/functions/limits.

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
