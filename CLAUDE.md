# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

NTO is a local-first photography ecosystem (Shoot → Import → Cull → Edit → Publish → Sell → Deliver). The **current priority is NTO Studio, the native Mac app**: a photographer must be able to create a project, import, cull, edit non-destructively, reopen with edits intact, and export JPEGs with no account, subscription, or Cloud. Web and Cloud are foundations/shells, not the focus. See `docs/STATUS.md` for what is implemented and what is outstanding, `docs/STUDIO-V0.1.md` for the ordered priority list and exit checklist, and `docs/PRODUCT.md` for the product invariants. Update `docs/STATUS.md` and the relevant phase verification doc when behaviour changes.

The long `docs/MASTER-CONTEXT.md` and `docs/BUILD-ROADMAP.md` describe *intended direction*, not implemented capability, and do not authorise building the features they describe. Documentation must never imply that an unfinished feature works; verification docs record environment-blocked checks rather than reporting them as passed.

## Toolchain and commands

Node 24.21.0, pnpm 10.32.1, Python 3, macOS 26+ with Xcode 26+. `./scripts/pnpm` is a transparent wrapper around `pnpm`: it prepends an isolated Node toolchain if `NTO_NODE_DIR` (or its default location) exists and points `DOCKER_HOST` at the Lima VM when present; otherwise plain `pnpm` behaves identically. With the wrong Node on PATH pnpm prints an "Unsupported engine" warning; install Node 24 before trusting `check` results. All commands run from the repo root.

```sh
./scripts/pnpm install --frozen-lockfile
./scripts/pnpm check            # typecheck + lint + test + build (what CI runs)
./scripts/pnpm typecheck        # tsc across web, shared-types, cloud
./scripts/pnpm lint             # eslint, web only
./scripts/pnpm test             # tokens:check + models:check + node:test contract suites
./scripts/pnpm build            # tokens:check + next build
```

Web (Next.js, port 3000):

```sh
./scripts/pnpm dev
NTO_DEMO=1 ./scripts/pnpm dev   # opt-in fixture artwork at /, /projects/studies-in-light, /galleries/studies-in-light
./scripts/pnpm --filter @nto/web exec playwright install chromium   # once
./scripts/pnpm test:web         # Playwright; starts its own NTO_DEMO=1 server on port 3100. Stop any running `next dev` first.
./scripts/pnpm --filter @nto/web exec playwright test tests/smoke.spec.ts --project=desktop -g "keyboard"   # single test
```

Studio (Swift):

```sh
./scripts/pnpm test:studio      # swift test --package-path apps/studio/NTOFoundation
swift test --package-path apps/studio/NTOFoundation --filter RenderingTests            # one test class
swift test --package-path apps/studio/NTOFoundation --filter PhotoLibraryTests/testName # one test
./scripts/pnpm build:studio     # unsigned xcodebuild Debug build into apps/studio/DerivedData
```

If `swift test` fails with a SwiftData macro error, only Command Line Tools are selected: point `DEVELOPER_DIR` at a full Xcode. If ad-hoc codesign fails with a "detritus" error, the checkout is in a File Provider-synced folder: pass `--scratch-path` / `-derivedDataPath` outside it (see `docs/SETUP.md`). Machine-specific notes belong in `CLAUDE.local.md`, which is git-ignored.

Or open `apps/studio/NTOStudio.xcodeproj`, scheme **NTOStudio**, and Run. Launch with `--fixtures` (or the sidebar toggle) for development artwork. Set `NTO_STUDIO_LIBRARY_PATH` to an empty directory to run against an isolated library instead of `~/Library/Application Support/NTO/Studio`. Swift tests generate their own JPEG/HEIC/TIFF fixtures; never commit or import personal photographs.

Cloud (local Supabase, needs a container engine):

```sh
./scripts/container-start       # starts the prepared Lima VM; ./scripts/container-stop releases it
./scripts/pnpm cloud:start
./scripts/pnpm cloud:reset      # resets the LOCAL dev database and reapplies migrations
./scripts/pnpm test:cloud       # integration suite; refuses non-localhost URLs
./scripts/pnpm --filter @nto/cloud stop
```

Single Node contract test file: `node --import tsx --test packages/shared-types/tests/contracts.test.ts`.

Generated code (never hand-edit, regenerate then commit; `check` fails on drift):

```sh
./scripts/pnpm tokens   # tokens.json -> packages/design-tokens/generated/tokens.css + NTOFoundation/.../DesignTokens.swift
./scripts/pnpm models   # shared-types/schema.json -> NTOFoundation/.../Models.swift + Swift test fixture ecosystem.json
```

Formatting: `.editorconfig` sets 2-space indent everywhere except Swift (4-space).

## Repository layout

pnpm workspace: `apps/web`, `packages/*`, `services/cloud`. Studio is not an npm package; root scripts shell out to `swift`/`xcodebuild`.

| Path | Role |
| --- | --- |
| `packages/shared-types` | Canonical contract v1: `schema.json` (JSON Schema, source of truth), mirrored TS interfaces in `src/index.ts`, `fixtures/ecosystem.json`, and `validateRecipe` range semantics. |
| `packages/design-tokens` | `tokens.json` is canonical; `generated/tokens.css` is output. |
| `apps/studio/NTOFoundation` | Local Swift 6 package holding nearly all Studio logic: SwiftData models, import, previews, organisation, renderer, edit history, and SwiftUI views. |
| `apps/studio/Studio` | Thin Xcode app target: `NTOStudioApp` (menus/commands) and `WorkspaceView` composition. No image processing here. |
| `apps/web` | Next.js 16 App Router + React 19, CSS Modules. Portfolio/project-story/gallery shells only. |
| `services/cloud` | Supabase migrations, `health` Deno edge function, and a TS `projectClient` REST adapter with local integration tests. |
| `scripts/` | The pnpm/container wrappers and the two generators. |
| `docs/` | Architecture, rendering semantics, per-phase verification records, and owner context. |

`apps/web/CLAUDE.md` imports `AGENTS.md`, a block that `next dev` re-adds automatically. This Next.js version differs from training data; read `apps/web/node_modules/next/dist/docs/` before writing web code.

## Architecture that spans files

**Contract v1 and the two generators.** `schema.json` is the single source of truth for interchange. TS interfaces mirror it by hand; Swift `Models.swift` is generated (with version guards that throw `ContractError.unsupportedVersion` and a call to `EditRecipe.validate()` on decode). Changing a contract means: edit `schema.json`, mirror in `src/index.ts`, update `fixtures/ecosystem.json`, run `pnpm models`, then fix Swift/TS callers. To add a field without breaking saved journals, give it a schema `default`, leave it out of `required`, and mark it optional in TypeScript: the generator then emits `decodeIfPresent ?? default` (this is how the Phase 05 tonal fields were added). Also extend `EditRecipe.neutral`, `validate`, `reset(_:)` in `RecipeSemantics.swift` and the range table in `validateRecipe`. Recipe ranges are enforced three times and must agree: `validateRecipe` (TS), `schema.json`, and `RecipeSemantics.swift`. Tests in both languages assert this.

**Entity semantics.** Asset = original identity (immutable once established). EditRecipe = versioned edit intent with a monotonically increasing `revision`. Rendition = replaceable derived output. Publication = destination and order. Collections hold references, never file copies. DB rows are snake_case; adapters map explicitly to camelCase DTOs. **Local filesystem paths, bookmarks, and managed paths never appear in public DTOs**; they live only in SwiftData `Local*` models and `OriginalReference` (renderer input). The schema and migration both reject them.

**Studio persistence.** `ProjectStore` (main actor, `@Observable`) owns the single `ModelContext` with autosave off; every mutation does explicit `save()` and `rollback()` on failure. The SwiftData schema (`LocalProject`, `LocalPhoto`, `LocalPhotoMembership`, `LocalBrowsingState`, `LocalPhotoAnnotation`, `LocalLibraryQuery`, `LocalCollection`, `LocalCollectionItem`, `LocalProjectPresentation`, `LocalEditState`) has only ever been extended additively so existing libraries keep opening. Store extensions live in `PhotoStore.swift`, `OrganisationStore.swift`, `EditPersistence.swift`. One `LocalPhoto` per SHA-256 fingerprint, shared across projects via memberships; annotations and edits are asset-wide, not per project.

**Native workspace.** The app's `WorkspaceView` is a `NavigationSplitView` with an `.inspector`; Edit controls live in `EditInspector`, not on the canvas. Never let SwiftUI compress AppKit-backed pop-up Pickers or Menus (for example an overflowing HStack under the split view): it raises an AppKit constraint-loop exception at launch. Give them explicit widths or host the row in a horizontal ScrollView. QA affordances: `NTO_STUDIO_MODE`, the demo-library generator and the export-sample generator (see `docs/SETUP.md`). `docs/STUDIO-NATIVE-UI.md` records the mockup mapping and the deliberate deviations (keep them). Floating bars use `glassEffect`, which needs the macOS 26 SDK.

**Studio control flow.** `WorkspaceState` holds mode/selection/chrome. `LibraryController` (main actor) owns the visible photo list, query, selection, import progress, and the `EditController`; it drives `PhotoImportWorker` (actor: discovery, hashing, atomic copy) and `PhotoPreviews` (ImageIO downsampling with bounded memory/disk caches). Views read controllers and call their methods; they never touch `ModelContext` or Core Image.

**Rendering.** `PhotoRenderer` is the async boundary; `CoreImageRenderer` (actor, engine `nto-ci-v1`) implements it with a fixed pipeline decode → RAW → tone → colour → detail → geometry → effects → output, a 64 MiB encoded-result cache keyed on recipe+fingerprint+output+OS, and fingerprint checks before use. Recipes express photographic intent (EV, Kelvin, normalized crop), not CIFilter chains; field meanings are frozen in `docs/RENDERING.md` and changing them requires a version decision. `EditHistory` is a Codable journal (current + ≤100 undo + redo + gesture baseline) autosaved per adjustment into `LocalEditState`.

**Crop, eyedropper, inspection.** `CropTool.swift` is pure geometry (test it without views). The controller's `cropSession` keeps the pending crop out of history until `commitCrop`; `previewRecipe` is what the preview renders (uncropped while cropping). `WhiteBalanceSampler.neutral` is a numerical solve against `CITemperatureAndTint`, so it stays correct only while the renderer's raster white-balance stage uses that filter with the same target neutral; the RAW path is unverified on real files.

**Presets and sync.** `EditParameter` plus `RecipeAdjustments` (in `EditPresets.swift`) are the one representation for a parameter subset used by presets, Copy/Paste and Sync. `EditParameter.safeDefaults` excludes white balance and geometry on purpose. `PresetStore` is file-based (one JSON per preset, format in `docs/PRESETS.md`). `BatchEditController` edits other photographs' journals on the main actor in yielding batches; `LibraryController.syncEdits` must route the open photograph through `EditController` so its in-memory history is not overwritten on disk.

**Export.** `Export.swift` holds the specification, naming and the metadata-attaching writer; `ExportController` renders each saved recipe through `PhotoRenderer` and writes via `CGImageDestinationCopyImageSource` (lossless copy). When no metadata is attached ImageIO requires the exclude-XMP/GPS options to be true, or the copy fails. `ExportNaming.resolve` takes an injectable existence check so conflict tests need no filesystem.

**Cloud access model.** Every table has `owner_id`, RLS `auth.uid() = owner_id`, composite FKs `(id, owner_id)` so relations cannot cross owners, and no anon grants. Buckets `originals`/`renditions` are private with owner-UUID-prefixed keys and no client update/delete policy. Clients get only the publishable key plus a user token; the service-role key is used solely by `tests/integration.test.ts`, which also guards against non-local URLs. Public web routes serve fixtures only; nothing reads the database yet.

**Web layout.** The landing, story and gallery follow `docs/WEB-SITE-DESIGN.md`; its deliberate deviations (one real project, no custom cursor, no fabricated metadata or downloads) are product decisions, keep them. `lib/content.ts` is the data model (`projects()`, `pipeline`); styles live in `components/experience.module.css` and use token variables only.

**Web demo gating.** Fixture content renders only when `NTO_DEMO=1` at both build and run time (the landing page is prerendered). Routes call `notFound()` otherwise. Demo data comes from `@nto/shared-types/fixtures`; artwork is the three abstract SVGs under `public/fixtures`, always labelled as development studies.

## Working rules specific to this repo

- Editing never rewrites an original; derived replacements use new keys. Failures must be actionable and specific (see `RenderFailure`, `CloudRequestError`); never present partial work as success or add placeholder screens that look functional.
- Rendering and other expensive work runs asynchronously outside SwiftUI views; keep Core Image, SwiftData, and networking out of view bodies.
- Local editing/export must not be gated on accounts, Cloud, or network. Do not add sync, upload, auth UI, commerce, pricing, licensing, or new platforms unless the task explicitly asks; the docs list them as deferred.
- Design system is monochrome and editorial: no gradients, glass, or dashboard chrome. Change colours/spacing/type only through `tokens.json`. Keyboard access and reduced motion are required for new UI.
- Keep `docs/` truthful when behaviour changes: update the relevant phase verification and `ARCHITECTURE.md`/`RENDERING.md` rather than claiming capabilities.
