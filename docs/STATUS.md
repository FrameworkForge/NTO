# Implementation status and outstanding work

Snapshot as of 14 September 2026, after Phases 01–07. This page summarises what the code does today and what remains, drawn from the phase verification records and the [build roadmap](BUILD-ROADMAP.md). Update it whenever a phase or checklist item changes; it is a summary, not a replacement for the per-phase evidence.

Status is **local verification on Apple silicon**. GitHub Actions runs on push: the web and Cloud jobs pass on hosted runners; the Studio job's timing budget is now environment-aware after failing on the slower hosted Mac. No hosted Supabase or Vercel project exists, and no distribution build is signed.

## Implemented

### Studio (macOS)

| Area | Working today | Evidence |
| --- | --- | --- |
| Shell | Library, Cull, Edit, Publish modes (Cmd-1 to Cmd-4); sidebar/inspector toggles; reversible Focus Mode (Tab); selection retained across modes; single workspace window; explicit startup failure state | [Phase 01](VERIFICATION.md) |
| Projects | Create, rename, cover, creation date, photo count, name search; persisted with SwiftData at `~/Library/Application Support/NTO/Studio`; last project restored on launch | Phase 01, [Phase 03](PHASE-03-VERIFICATION.md) |
| Import | Files, folders, and drag/drop; copy or reference storage; default caption; SHA-256 duplicate detection; one local identity shared across projects; JPEG/HEIC/TIFF and system-supported RAW; ImageIO metadata; cancellable background import with per-file report; crash recovery of partial copies | [Phase 02](PHASE-02-VERIFICATION.md) |
| Library | Lazy thumbnail grid with density control; click/Shift/Command/range selection, Cmd-A, arrows, Return to preview; bounded memory and disk preview caches; viewport prefetch; per-project selection, active photo, scroll anchor and density; 10,000-record synthetic library opens in about one second | Phase 02 |
| Originals | Read-only metadata inspector; security-scoped bookmarks for references; checksum-verified relink via Locate original; changed source bytes refused | Phase 02 |
| Organisation | Manual collections (create, rename, reorder, remove, multi-membership) without file copies; ratings 0 to 5, pick/reject/clear, favourites, captions, keywords, persisted per asset; selection-wide metadata edits with hidden-selection safety | Phase 03 |
| Search and filters | Filename/caption/keyword/camera/lens search; filters for rating, flag, favourites, camera, media type, capture-date substring; sort by import time, filename, capture date, rating; query shared by Library and Cull and saved per project | Phase 03 |
| Cull | Keyboard review (arrows, 0 to 5, P, X, U, F, Space for Fit/100%); filmstrip; previous/next; full-resolution one-pixel-per-pixel inspection up to 120 MP; neighbour preloading | Phase 03 |
| Rendering | `CoreImageRenderer` behind `PhotoRenderer`: CIRAWFilter and Core Image, fixed pipeline order, extended linear sRGB working space, 8-bit sRGB output; JPEG/PNG/TIFF encoded results; same graph for preview and full resolution; 64 MiB result cache keyed on recipe, fingerprint, output and OS; fingerprint checks; cancellation and stale-result protection | [Phase 04](PHASE-04-VERIFICATION.md), [RENDERING.md](RENDERING.md) |
| Edit | Grouped Light/Colour/Detail/Geometry controls with sliders and numeric entry for every recipe v1 field; per-group and full reset; exposure, contrast, highlights, shadows, whites, blacks; white balance as shot, Kelvin, or by eyedropper; tint, vibrance, saturation, sharpness, noise reduction; interactive crop with aspect presets, guides, Return/Escape; rotation with quarter turns; 100% inspection of the edited result (Space); numeric crop with clamping; compare with original (hold, button or `\`); autosaved per-asset edit journal; persistent undo/redo (Cmd-Z, Shift-Cmd-Z) with gesture coalescing; progress and retry states; missing-original and corrupt-recipe handling that keeps files and saved edits | Phase 04, [Phase 05](PHASE-05-VERIFICATION.md) |
| Presets and sync | Portable JSON presets (create, rename, delete, export, import) carrying a chosen parameter subset; hover preview; white balance and geometry excluded by default; copy/paste edits; background sync to the selection with progress and Stop; revert of the last sync that skips photographs edited since | [Phase 06](PHASE-06-VERIFICATION.md), [PRESETS.md](PRESETS.md) |
| Export | Shift-Cmd-E or the header button exports the selection: JPEG with quality or TIFF, original size or fit longest edge, filename templates with a live example, metadata policy (none, caption and keywords, camera data) with location opt-in, skip/keep both/replace, background queue with progress, Stop, per-file failures and Show in Finder; settings persist | [Phase 07](PHASE-07-VERIFICATION.md) |
| Verified files | Generated JPEG/HEIC/TIFF fixtures in tests; one owner Canon EOS 5D Mark IV CR2 developed at neutral settings | Phase 02, Phase 04 |

Automated coverage: 48 Swift tests (46 behavioural, 2 opt-in fixture generators), unsigned Debug build via `xcodebuild`.

### Shared contracts and tokens

- Contract v1 in `packages/shared-types/schema.json` with mirrored TypeScript interfaces, a canonical fixture containing neutral and edited recipes, and generated Swift Codable models with version guards and schema-default support for additive fields.
- Recipe v1 ranges validated identically in JSON Schema, TypeScript and Swift; local filesystem paths rejected from public payloads.
- Design tokens generated to CSS variables and SwiftUI constants; drift checks in `pnpm check` and CI.

### Web (nto.motion shells)

- Next.js 16 portfolio, project-story and gallery routes with editorial layout, skip link, visible focus, reduced-motion handling, explicit empty/error/not-found states.
- Fixture artwork opt-in via `NTO_DEMO=1`; keyboard-accessible modal viewer with arrow navigation, Escape, and focus return.
- Playwright desktop and mobile smoke tests; ESLint; production build; Vercel configuration prepared.

### Cloud (local Supabase foundation)

- Migration for projects, assets, project memberships, collections, edit recipes, renditions, publications; owner row-level security; composite owner foreign keys; immutable original identity trigger; private `originals` and `renditions` buckets with owner-prefixed keys and no client overwrite/delete.
- `health` edge function; TypeScript and Swift project create/read adapters with classified, retryable errors.
- Integration suite (local only) covering ownership isolation, forged-owner rejection, anonymous denial, private object access, signed downloads and immutable keys.

### Tooling

- pnpm workspace, `./scripts/pnpm` and Lima container wrappers, token and model generators, GitHub Actions definitions for web, Studio and Cloud jobs.

## Outstanding

### Studio v0.1 gate (from [STUDIO-V0.1.md](STUDIO-V0.1.md))

- [ ] Qualify the owner's Canon CR3 camera/files with the macOS decoder.
- [ ] Complete a real shoot's cull end to end with persistent ratings, picks, rejects, favourites and focus inspection.
- [ ] Edit RAW/JPEG with the full v0.1 tool set without changing originals. Every Phase 05 tool is implemented; live verification on real photographs remains.
- [x] Presets and parameter-selective batch edits (Phase 06); live UI verification still open.
- [x] JPEG export that opens correctly outside NTO (Phase 07; verified by ImageIO decoding, a non-Apple viewer check remains).
- [ ] Recovery from unavailable originals, interrupted operations and render/export failures across the whole workflow.
- [ ] Clean-checkout clone, build, open, edit, export by another developer following the documented prerequisites.

### Phase 05: core editing experience (implemented)

- [x] Progressively disclosed Light, Colour, Detail and Geometry groups with numeric entry and per-group reset.
- [x] Temperature (as shot, Kelvin, or eyedropper), Tint, Sharpness, Noise reduction, Rotation, quarter turns and crop controls.
- [x] Hold-to-view-original comparison, also via button and `\`.
- [x] Highlights, Shadows, Whites, Blacks and Vibrance added to recipe v1 as defaulted fields, rendered and exposed as controls; older journals decode unchanged.
- [x] Interactive crop tool with aspect presets, thirds guides, Return to commit and Escape to cancel.
- [x] 100% inspection of the edited result inside Edit.
- [ ] Brilliance (deferred by the v0.1 reconciliation); a straighten guide on the image.
- [ ] Live UI verification of the tools, Focus Mode and window sizes with real photographs; the RAW eyedropper on a real camera file; manual pointer-drag acceptance open since Phase 04.

### Phase 06: presets and batch (implemented)

- [x] Presets as selected recipe fields with hover previews; explicit inclusion/exclusion of crop and white balance.
- [x] Copy/paste edits and parameter-selective batch synchronisation in the background with progress, Stop and revert.
- [ ] Live UI verification with real photographs (hover preview timing, sheets at minimum window size, Stop during a long sync).

### Phase 07: export (implemented)

- [x] Export sheet: folder, JPEG quality or TIFF, original size or fit, filename template, metadata policy with location opt-in, conflict behaviour; per-file failures in the status report.
- [x] Background export queue for the selection with progress and Stop; exported pixels verified equal to the engine output and decodable by ImageIO.
- [ ] Manual check of exported files in a non-Apple application and live UI verification of the sheet and status bar.
- Colour-profile choices, 16-bit TIFF, export presets and watermarks are full-GDD scope after the JPEG proof.

### Qualification and verification gaps

- [ ] Camera matrix beyond one CR2: RAW colour and exposure quality, CR3, mixed-camera performance, full-shoot throughput.
- [ ] Colour-critical output, HDR and wide-gamut export are not claimed.
- [ ] A green Studio job on GitHub's macOS 26 runner after the timing-budget change (web and Cloud jobs already pass remotely).
- [ ] Intel and Release/distribution builds; signing and notarization.
- [ ] Persistent render disk cache (only an in-memory encoded cache exists).

### Later phases (not started)

| Phase | Scope | Prerequisite |
| --- | --- | --- |
| 08 Cloud auth and sync | Sign-in UI, token storage, asset/recipe/rendition/publication adapters, checksum uploads, sync journal, conflict handling | Phase 07 |
| 09 Renditions and delivery | Separate worker runtime for rendition jobs, signed expiring delivery, public/unlisted/password policies, ZIP generation | Phase 08 |
| 10 Studio publishing and Gallery | Publish flow, real Gallery data replacing fixtures, viewer completion, downloads, password screen | Phases 08 to 09 |
| 11 Portfolio integration | Real nto.motion index and story blocks, Add to Portfolio flow | Phase 10 |
| 12 Published updates and CORE release | Update Published Version, replacement renditions, full end-to-end and failure exercises, hosted operations, distribution | Phases 02 to 11 |
| 13 GDD Phase 2 | Optics, client selections, remote version history | CORE stable |
| 14 Later | Smart collections, XMP, HSL, masks, AI features, Mobile companion, Windows/Android/Linux | Case by case |

### Open-source readiness

Tracked in [OPEN-SOURCE-READINESS.md](OPEN-SOURCE-READINESS.md). Proposed to the maintainer: this repository private; Studio plus shared contracts published as a separate open-source repository. CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, TRADEMARKS, templates and the content audit are done and carry over. Still the maintainer's: repository visibility, the licence, the conduct contact, brand terms, DCO versus CLA, and the public repository's name and settings.

### Deployment (nothing hosted yet)

- [ ] Hosted Supabase project, migration push, health function deploy, auth redirect configuration.
- [ ] Vercel project with `NTO_DEMO=0`, domain, and production promotion.
- [ ] Pricing, plans and commerce remain proposals; no billing code exists.
