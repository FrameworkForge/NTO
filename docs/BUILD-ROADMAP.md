# NTO ecosystem: chronological build roadmap

Source: **NTO_Ecosystem_GDD_v1.pdf**, product/design specification v1.0, 58 pages. Page references below use PDF page numbers. The original is at `/Users/nathanolivier/Downloads/NTO_Ecosystem_GDD_v1.pdf`; it is not bundled in this repository.

This document translates the GDD's feature groups into a recommended dependency-based implementation order and incorporates the owner's later [master context](MASTER-CONTEXT.md). The GDD itself does not prescribe a schedule. The phases below are planning recommendations, not additional product requirements or time estimates. Its embedded agent handoff is reference material, not authorization to build features.

## Updated priority: Studio first

The owner's later context refines the release strategy: make the local Mac app useful before expanding the ecosystem. [Studio v0.1](STUDIO-V0.1.md) defines the immediate acceptance gate. The current context-incorporation request is documentation only; it does not start any of these feature phases.

The numbered phases below retain their original GDD feature mapping. They are implementation groups, not an instruction to finish the entire ecosystem before releasing useful Studio software. In particular, a JPEG-first Studio v0.1 can precede the broader GDD CORE release. TIFF remains in the full GDD scope; it is not required before the initial JPEG proof of concept. Proposed optics, advanced tools, and AI work do not take precedence over Gallery/Commerce merely because they appear in the GDD backlog.

### Revised release and ecosystem sequence

| Stage | Next outcome | Relationship to the technical phases |
| --- | --- | --- |
| 1 | Reliable private Mac Studio: import, Library, Cull, Edit, save/reopen, JPEG export | Phases 01-07, with reproducible Mac defects addressed first |
| 2 | Process real shoots and fix demonstrated problems | Validate the local workflow before more products |
| 3 | Targeted architecture cleanup and useful portable boundaries | Avoid a speculative rewrite; current NTOFoundation remains Apple-only |
| 4 | Prepare a credible open-source Studio v0.1 | Release documents and a chosen license; visibility/license changes remain separate decisions |
| 5 | Focused community contribution and maintenance | Documentation, small fixes, compatibility, and performance |
| 6 | Optional Cloud | Phases 08-09; no account/subscription gate on local tools |
| 7 | Real Gallery/Portfolio publishing and safe updates | Phases 10-12; use real delivery workflows |
| 8 | Basic Commerce and automatic delivery | New later scope: orders, verified payments, asset entitlements, protected downloads |
| 9 | Mobile companion | Focused import/cull/quick edit/publish/manage/sales experience |
| 10 | Validated paid hosted services | Research real costs and demand; all example prices remain provisional |
| 11 | Windows core → project read → decode → render → export, then native UI | Portable semantics first; Vulkan is the preferred future non-Apple backend |
| 12 | Android/Linux if justified | No implementation or release commitment yet |

Optics, client selections, version history, sports/school features, team products, marketplaces, and AI remain explicitly scoped expansions rather than automatic next steps. See [Ecosystem strategy](ECOSYSTEM-STRATEGY.md) for business, open-source, and Commerce boundaries.

## Where we are now

**Phases 01–04 are implemented and locally verified, with verification limits recorded. Phase 05, Core editing experience, is the next build.**

Studio now imports photographs, persists local asset identities and project memberships, and provides a thumbnail Library with metadata and original previews. Collections, saved filters, editable metadata and keyboard culling now work locally. Edit now renders originals through saved recipes with undo/redo and the first tone/colour controls. The website shells, shared models, and local Supabase infrastructure also exist. Local verification is documented in [Phase 04 verification](PHASE-04-VERIFICATION.md) and the historical [foundation record](VERIFICATION.md). The initial foundation commit is on `main` in the private [Nathan-Olivier/NTO repository](https://github.com/Nathan-Olivier/NTO).

This does **not** mean the GDD's CORE product is complete. The full editing toolset, export workflow, authentication UI, sync, and publishing remain to be built. The Phase 04 edit renderer is now separate from Library/Cull original-preview decoding. The website currently uses optional development fixtures; it is not a deployed portfolio backed by real publications. Remote CI results must be checked separately from the recorded local results.

## Build sequence at a glance

| Order | Phase | Outcome | Status |
| --- | --- | --- | --- |
| 01 | Foundations | Runnable native, web, and Cloud boundaries | Complete for foundation scope |
| 02 | Safe import and Library | Real photographs can be imported and browsed | Implemented; locally verified |
| 03 | Organisation, metadata, and culling | A shoot can become a reliable final selection | Implemented; locally verified |
| 04 | Rendering and edit-state engine | Originals and recipes produce consistent images | Implemented; locally verified with limits |
| 05 | Core editing experience | A photograph can be edited safely and precisely | Planned |
| 06 | Presets and batch edits | Editing scales to an event-sized selection | Planned |
| 07 | Export | Finished photographs can be delivered to disk | Planned |
| 08 | Cloud authentication, assets, and sync | Studio can transfer work safely and recover offline | Planned |
| 09 | Renditions and protected delivery | Cloud can serve appropriate images securely | Planned |
| 10 | Studio publishing and Gallery | A selection becomes a working client gallery | Planned |
| 11 | Portfolio and Studio integration | Studio manages the real nto.motion portfolio | Planned |
| 12 | Published updates and CORE release | The complete ecosystem works reliably end to end | Planned |
| 13 | GDD Phase 2 | Optics, client selections, and remote version history | Deferred |
| 14 | Later capabilities | Advanced tools, AI, collaboration, and mobile | Deferred |

The main dependency chain is **safe local assets → reliable recipes/rendering → export → Cloud transfer → secure rendition delivery → publishing → updates**. Web presentation can be developed against fixtures while the native engine grows, but it cannot be considered integrated until it consumes real, authorized Cloud publications.

Each phase below contains build tasks and an exit gate. Leave tasks unchecked until their behavior is implemented and verified, not merely represented by a model or screen.

## Phase 01 - Foundations

**GDD references:** architecture p. 5; features 01, 38-42; technical foundation and models pp. 53-54.

**Purpose:** establish the boundaries used by every later phase.

- [x] Create the `apps`, `services`, `packages`, and `docs` monorepo with Git, dependency locks, setup commands, and environment examples.
- [x] Establish Swift 6 / SwiftUI Studio, a Next.js TypeScript web application, and a Supabase Cloud foundation.
- [x] Provide Library, Cull, Edit, and Publish mode shells, native commands, collapsible chrome, selection preservation, and reversible Focus Mode.
- [x] Persist local project creation and renaming with SwiftData.
- [x] Provide portfolio, project-story, and Gallery route shells with explicit development fixtures.
- [x] Define shared Asset, Project, Collection, EditRecipe, Rendition, and Publication contracts, plus renderer and Cloud client boundaries.
- [x] Generate Swift constants and CSS variables from canonical design tokens.
- [x] Add initial Cloud migrations, ownership policies, private storage, project create/read adapters, and health/error foundations.
- [x] Run local native, web, contract, and database checks; provide CI definitions and deployment preparation.
- [x] Upload the foundation project to the private GitHub repository.

**Exit gate:** both applications run, local projects survive relaunch, contracts are compatible, and local Cloud access controls pass verification. Completed components are foundations; their corresponding GDD features still require validation with real photographs and complete workflows.

## Phase 02 - Safe import and Library

**GDD references:** 02 Import, p. 8; 03 Library, p. 9; 33 Asset Store, p. 42; data concepts, p. 54.

**Depends on:** Phase 01.

- [x] Implement import from files, folders, and a drop target into an existing or newly created project.
- [x] Offer explicit copy/reference behavior and metadata defaults. Persist security-scoped bookmarks where sandboxed references require them.
- [x] Support JPEG, HEIC, TIFF, and system-supported RAW files; report unsupported formats honestly.
- [x] Extract capture metadata using ImageIO and assign stable asset identities.
- [x] Detect duplicates with a stable fingerprint rather than filenames alone.
- [x] Run thumbnail and working-preview generation in the background, with bounded caches and viewport prefetch.
- [x] Show import progress, cancellation, duplicate warnings, and actionable failures.
- [x] Build the real thumbnail grid, density control, metadata inspector, and Finder-style click, Shift-click, and Command-click selection.
- [x] Preserve project browsing state and carry the active selection/context into Cull and Edit.
- [x] Handle missing referenced originals without losing project records; provide a recovery path.

**Exit gate:** a real shoot imports without changing source bytes; cancellation leaves a valid library; duplicate detection works; relaunch restores access and selection context. A 10,000-photo test library remains responsive without full-resolution decoding on the UI thread.

**Verification:** see [Phase 02 verification](PHASE-02-VERIFICATION.md). The 10,000-record grid check uses synthetic records and generated imagery; it is not a mixed-camera RAW throughput or 60 fps certification. RAW support depends on ImageIO/system camera support.

## Phase 03 - Organisation, metadata, and culling

**GDD references:** 03-06, pp. 9-12; 17 Before / After & Focus Mode, p. 23.

**Depends on:** real assets and preview caches from Phase 02.

- [x] Extend projects with cover, date, and counts; implement manual collection creation, renaming, ordering, membership, and removal.
- [x] Allow an asset in multiple collections without copying its original. Collection removal must not delete originals.
- [x] Persist ratings, picks, rejects, favourites, and supported captions/keywords; keep camera metadata read-only.
- [x] Support appropriate metadata edits across a selection.
- [x] Add filtering by rating, flag, camera, date, and media type, plus metadata/project search and sorting.
- [x] Persist filters and scroll position per project without destroying valid selection.
- [x] Implement keyboard-first Cull: arrows, 1-5 ratings, P pick, X reject, F favourite, and Space for 100% inspection.
- [x] Preload neighbouring previews in both directions and keep rating writes independent of rendering.
- [x] Provide an optional filmstrip and verify Focus Mode with actual photos.

**Exit gate:** a photographer can cull an entire shoot using the keyboard, navigate rapidly without losing ratings, and reopen the project with metadata intact. Organising photographs never duplicates or unexpectedly removes files.

**Verification:** [Phase 03 results and limits](PHASE-03-VERIFICATION.md). Real-shoot and camera qualification remain part of Studio v0.1 acceptance.

**Scope note:** Studio favourites are CORE metadata. Recipient favourites and client selection in Gallery are a separate Phase 2 feature.

## Phase 04 - Rendering and edit-state engine

**GDD references:** 07-08, pp. 13-14; 15 History, Undo & Versions, p. 21; technical/data boundaries, pp. 53-54.

**Depends on:** original references from Phase 02. Can advance alongside Phase 03 once asset access is stable.

- [x] Implement the asynchronous renderer behind its existing interface, outside SwiftUI views.
- [x] Use CIRAWFilter / Core Image for supported RAW and a consistent non-RAW path; introduce Metal only where necessary.
- [x] Establish the versioned order: decode → camera/RAW → tone → colour → detail → geometry → effects → output.
- [x] Evolve the recipe contract as parameters are added, keeping Swift/TypeScript fixtures and version handling aligned.
- [x] Make preview and full-resolution output use the same recipe semantics and colour-management decisions.
- [x] Cache by asset, recipe revision, and output specification; cancel or supersede stale interactive render requests.
- [x] Autosave recipes and introduce exact undo/redo commands; coalesce a continuous slider gesture into one history operation.
- [x] Surface missing originals, unsupported RAW, and rendering failures with recovery actions.

**Exit gate:** the same original and recipe render predictably; saved edits survive reopening; unsupported versions fail explicitly; rendering does not freeze the interface or mutate originals. Establish preview/export comparison tests before adding the full control set.

**Verification:** [Phase 04 checks and limits](PHASE-04-VERIFICATION.md). Pointer-drag UI acceptance, RAW camera/colour qualification and full-shoot performance remain to be completed; gesture coalescing is covered by automated tests.

## Phase 05 - Core editing experience

**GDD references:** 07 Edit Workspace, p. 13; 09-11, pp. 15-17; 13 Crop & Geometry, p. 19; 15 and 17, pp. 21 and 23.

**Depends on:** Phase 04.

- [ ] Build progressively disclosed Light, Colour, Detail, and Geometry controls with numeric entry, reset, and fine adjustment where appropriate.
- [ ] Implement Exposure, Brilliance, Contrast, Highlights, Shadows, Whites, and Blacks, including group reset.
- [ ] Implement Temperature, Tint, Vibrance, Saturation, and a white-balance eyedropper with preview and as-shot RAW reset.
- [ ] Implement sharpening and noise reduction with 100% inspection and refinement after expensive interactions.
- [ ] Implement free/aspect-ratio crop, 90-degree rotation, straightening, and temporary guides. Store normalized crop coordinates.
- [ ] Make Escape cancel a crop interaction and Enter commit it; keep geometry editable later.
- [ ] Connect every committed edit to undo/redo and recipe autosave.
- [ ] Add hold-to-view-original comparison using cached previews; restore the edited view on release without changing its recipe.
- [ ] Verify Focus Mode, resizing, keyboard access, and photograph-first layout throughout editing.

**Exit gate:** a real RAW or JPEG can be corrected, cropped, compared, undone/redone, closed, and reopened with the same state. Preview and full-resolution render remain meaningfully consistent, with no unexpected clipping or neutral-value artifacts.

**Deferred within these groups:** optics, HSL/advanced grading, texture/clarity, split comparison, and optional named edit snapshots are not prerequisites for this phase's basic edit loop. The GDD supplies no separate CORE Effects tool specification; do not invent one simply to fill an inspector group.

## Phase 06 - Presets and batch edits

**GDD references:** 14 Presets, p. 20; 16 Batch & Sync Edits, p. 22.

**Depends on:** stable individual edit operations and history from Phase 05.

- [ ] Store presets as selected recipe fields with visual previews before application.
- [ ] Allow preset creation with explicit inclusion/exclusion of parameters such as crop and white balance.
- [ ] Make preset application transparent and undoable; deleting a preset must not alter existing edits.
- [ ] Implement copy/paste edits and parameter-selective batch synchronization.
- [ ] Run batch operations in the background with progress and a defined undo/revert strategy.

**Exit gate:** apply selected parameters to 100 images without blocking Studio, preserving excluded values and supporting recovery from unwanted changes.

**Terminology:** synchronizing edits across photos is distinct from synchronizing data with Cloud in Phase 08.

## Phase 07 - Export

**Updated release gate:** deliver reliable JPEG export for Studio v0.1 first. TIFF and additional profile/export options remain full-GDD follow-up scope, not a reason to delay the first complete local workflow.

**GDD reference:** 18 Export, p. 24.

**Depends on:** Phases 04-06 for complete selection and recipe behavior.

- [ ] Export individual selections, projects, and collections through a background queue.
- [ ] Support JPEG/TIFF, quality, target dimensions, colour profile, metadata policy, and filename templates.
- [ ] Render at source resolution unless resizing is requested.
- [ ] Define explicit existing-file conflict behavior; show progress and actionable per-item failures.
- [ ] Verify results in applications outside NTO and compare them with the editing preview.

**Exit gate:** exported files open correctly and match requested dimensions, naming, profile, and metadata policy. Studio remains responsive, and originals remain unchanged.

**Product checkpoint:** Studio now supports the first complete local workflow: **import → organise → cull → edit → export**.

## Phase 08 - Cloud authentication, assets, and sync

**GDD references:** 19 Publish, p. 25; 33 Asset Store, p. 42; 35 Sync Engine, p. 44; 37 Security & Ownership, p. 46.

**Depends on:** stable asset/recipe identities and rendered outputs. Keep the local store usable independently of Cloud.

- [ ] Add real Studio sign-in, sign-out, session refresh, and clear expired-session recovery, with secure token storage.
- [ ] Extend the existing project adapters to asset, recipe, rendition, and publication records as required.
- [ ] Implement private binary transfer and checksum validation, preserving immutable originals and distinct derived outputs.
- [ ] Define deletion behavior for local references, cached previews, Cloud originals, and assets used by publications.
- [ ] Add a durable sync journal keyed by stable UUIDs and revisions, with resumable upload where practical.
- [ ] Show Synced, Uploading, Changed, Offline, and Error states; distinguish transient automatic retries from persistent failures requiring action.
- [ ] Define conflict resolution without silent overwrites and resume unfinished work after relaunch.
- [ ] Extend owner-isolation and least-privilege tests to all new records and object operations.

**Exit gate:** network loss, application termination, and authentication expiry do not corrupt local work or duplicate remote assets. Another account cannot read or alter private records or files. No public payload contains a Mac filesystem path.

## Phase 09 - Renditions and protected delivery

**GDD references:** 34 Rendition Service, p. 43; 25 Downloads, p. 32; 26 Access & Privacy, p. 33; 37 Security & Ownership, p. 46.

**Depends on:** Phase 08 and reliable Studio rendering.

- [ ] Implement the existing rendition-job contracts in a separate background worker runtime.
- [ ] Use Studio-rendered edited masters for delivery transformations; do not assume a web image worker reproduces the native RAW engine.
- [ ] Generate thumbnails, responsive web sizes/formats, and permitted downloadable masters with versioned object keys.
- [ ] Prevent unintended upscaling and preserve output colour and metadata policy.
- [ ] Add job state, retry, failure handling, and progressive availability.
- [ ] Implement publication-aware delivery authorization and signed, expiring access for protected assets.
- [ ] Define public, unlisted, password-protected, and view-only/download policy behavior server-side. An unlisted URL alone is not authentication.
- [ ] Keep password hashes and privileged secrets server-side; test direct-object access as well as page access.
- [ ] Prepare background ZIP generation for permitted multi-downloads.

**Exit gate:** browsers receive correctly sized renditions rather than full camera originals; protected objects cannot be retrieved by guessing URLs; rejected or unfinished jobs do not become published output.

**Architecture decision already agreed:** Supabase provides Postgres, Auth, private Storage, and lightweight Edge Functions. Heavy image processing and ZIP work require an appropriate separate worker. Do not place Sharp processing inside Supabase Edge Functions.

## Phase 10 - Studio publishing and Gallery

**GDD references:** 19-23, pp. 25-30; 25-26, pp. 32-33.

**Depends on:** Phases 08-09.

- [ ] Build the Studio Gallery publish flow for selection, title, date, cover, visibility, password, and download policy.
- [ ] Store Gallery documents and ordered asset relationships, with unmistakable draft and published states.
- [ ] Publish only after required uploads/renditions are available, and return a stable shareable URL.
- [ ] Replace fixture-only Gallery data with authorized Cloud data.
- [ ] Implement the hero/title/date/count entry and Enter Gallery action, with a fast path for repeat visits.
- [ ] Build responsive editorial compositions that respect aspect ratios and reserve image dimensions before loading.
- [ ] Complete the fullscreen viewer: spatial opening/closing with fallback, arrows/swipe, Escape, neighbour preloading, and usable controls that recede when idle.
- [ ] Add permitted single/set downloads, resolution choices, ZIP progress, and clean view-only behavior.
- [ ] Implement the on-brand password screen and verify policies cannot be bypassed through direct asset requests.

**Exit gate:** a real Studio selection becomes a gallery that works on desktop and phone. Keyboard, touch, reduced motion, privacy, and download behavior all work. Title/layout changes do not upload unchanged originals again.

**Scope note:** Gallery recipient favourites remain deferred to Phase 13 even though the viewer design anticipates their control.

## Phase 11 - Portfolio and Studio integration

**GDD references:** 28-32, pp. 36-40; 19 Publish, p. 25.

**Depends on:** Cloud publication/delivery from Phases 08-10. Editorial layout can be prototyped earlier against fixtures.

- [ ] Complete the nto.motion landing: wordmark, restrained O photo reveal, identity line, and immediate accessible content when motion is disabled or unavailable.
- [ ] Build the real project index with covers, titles, year/category, and readable touch/keyboard alternatives to hover.
- [ ] Persist structured story blocks for full-width frames, portrait pairs, details, whitespace, typography, and optional project statements.
- [ ] Preserve authored sequence and hierarchy across mobile and desktop.
- [ ] Implement discoverable portfolio Focus Mode without trapping focus or interfering with text selection/browser navigation.
- [ ] Add Studio's Add to Portfolio flow for title, category, cover, and story order.
- [ ] Support publishing to Gallery, Portfolio, or both using shared asset identities and appropriate renditions.

**Exit gate:** Studio can create and update a real portfolio story. Changing its cover or order does not re-upload unaffected photographs. Visitors can browse the whole experience without animation.

## Phase 12 - Published updates and CORE release

**GDD references:** 27 Live Publish Updates, p. 34; 19 Publish, p. 25; 38-42, pp. 48-52; release scope, p. 55.

**Depends on:** the complete paths in Phases 02-11.

- [ ] Mark published photographs that changed locally and provide explicit Update Published Version actions.
- [ ] Generate replacement renditions with new version/content keys while preserving asset identity, URL, order, and existing relationships.
- [ ] Switch publication references only after replacements are ready; retain the previous valid output through failures.
- [ ] Invalidate only relevant cached rendition paths and avoid duplicate galleries on retried operations.
- [ ] Exercise the full workflow: import → cull → edit → export → publish to Gallery and Portfolio → edit again → update.
- [ ] Exercise missing files, unsupported RAW, force-quit, disk/export failures, network loss, auth expiry, denied access, and worker failures.
- [ ] Measure import/render latency, cache behavior, large-library scrolling, web image delivery, and signature-motion frame rate on supported hardware.
- [ ] Verify keyboard and screen-reader flows, labels, visible focus, contrast, reduced motion, responsive layout, and bounded caches throughout.
- [ ] Run native, web, contracts, database, and end-to-end checks in CI; record failures or blocked checks explicitly.
- [ ] Prepare operational setup for hosted Supabase, worker/CDN delivery, Vercel, secrets, backup/recovery, monitoring, and intended domains.
- [ ] Prepare Studio distribution signing/notarization and release validation if distributing beyond local development.
- [ ] Complete hosted deployment and distribution only within the owner's approved accounts, access, and spending decisions.

**Exit gate:** the first coherent **GDD CORE release** is usable from source photograph to delivered Gallery/portfolio and later update, with recovery and privacy verified. Local tests alone do not certify hosted production behavior.

Hosting operations, signing, monitoring, and release sequencing here are implementation planning additions needed to ship; they are not claims that the PDF specifies particular accounts, budgets, or distribution channels. Account setup, billing, domains, and live deployment were outside the completed foundation milestone.

## Phase 13 - GDD Phase 2: professional expansion

**GDD references:** 12 Optics, p. 18; 24 Favourites & Client Selection, p. 31; 36 Versions, p. 45; release scope, p. 55.

Begin after CORE is stable. The order within this group is recommended; these features can be prioritized independently.

1. **Optics:** repeatable auto lens correction, chromatic aberration controls, recipe persistence, and honest unsupported-lens states. Prefer available system/profile metadata rather than fabricated profiles.
2. **Favourites and client selection:** session-scoped anonymous favourites where configured, secure identified review sets, distinguishable reviewers, and selected asset IDs available to Studio. Keep selections intact through image updates.
3. **Remote versions:** retention policy for prior published renditions, stable asset identity, version relationships, and targeted cache invalidation. A full advanced rollback/version browser remains later scope.

**Exit gate:** each expansion passes its own acceptance criteria without weakening CORE performance, original safety, or privacy.

**Version distinction:** recipe schema versions, basic undo/redo, and safe rendition replacement are already required in CORE. Retaining and exposing historical published versions is the deferred expansion.

## Phase 14 - Later capabilities and optional enhancements

**GDD references:** release scope, p. 55; optional extensions within features 04, 06, 10-11, 15, 17, 23, and 26.

These are a backlog, not promises or a fixed delivery schedule. Scope each separately after the relevant prerequisites are trustworthy.

### Workflow and editing extensions

- Smart collections and optional XMP interoperability.
- HSL/Colour Mixer, advanced grading, texture/clarity, optional named edit snapshots, and split before/after comparison.
- Brush, radial, and linear masks, with recipe/history/rendering support.
- Optional Gallery expiration and active-image deep links.
- Collaborative proofing, a mobile companion, and an advanced Cloud rollback/version browser.

### AI extensions

- AI Select Subject / Sky / People.
- Generative or semantic object removal.
- Advanced AI denoise and upscale.
- Face recognition and people clustering.
- Automated portfolio suggestions and publishing intelligence.

**Entry gate:** import, persistence, rendering, recipes, export, and project safety must already be trustworthy. Introduce new privacy, compute, cost, and model requirements when scoping each AI capability. Do not let AI work delay the reliable photographic engine.

## Rules that apply in every phase

Derived from the GDD's identity, system, and product rules (pp. 4, 48-52, 56):

- The photograph dominates; controls reveal complexity progressively.
- Originals are immutable. Edits are recipes, and outputs are derived renditions.
- Stable IDs connect Studio, Cloud, Gallery, and portfolio; names and paths are not identity.
- Rendering, decoding, export, and transfer remain outside the UI's critical path.
- Use native macOS behavior and semantic, accessible web controls.
- Use shared monochrome tokens and restrained motion that explains state; provide reduced-motion alternatives.
- Build recovery, permissions, and performance with each feature rather than postponing them to final polish.
- A screen shell, model, passing unit test, or successful upload alone does not prove an entire user workflow works.

## GDD feature coverage index

Every numbered GDD feature has a place in this roadmap. Repeated phase numbers indicate foundations followed by full implementation or end-to-end verification.

| GDD feature | PDF page | Build phase(s) |
| --- | --- | --- |
| 01 Application Shell | 7 | 01, 03, 05 |
| 02 Import | 8 | 02 |
| 03 Library | 9 | 02, 03 |
| 04 Projects & Collections | 10 | 01, 03 |
| 05 Cull | 11 | 03 |
| 06 Metadata & Ratings | 12 | 02, 03 |
| 07 Edit Workspace | 13 | 04, 05 |
| 08 RAW Rendering Pipeline | 14 | 04 |
| 09 Light Controls | 15 | 05 |
| 10 Colour Controls | 16 | 05; extensions 14 |
| 11 Detail | 17 | 05; extensions 14 |
| 12 Optics | 18 | 13 |
| 13 Crop & Geometry | 19 | 05 |
| 14 Presets | 20 | 06 |
| 15 History, Undo & Versions | 21 | 04, 05; optional snapshots 14 |
| 16 Batch & Sync Edits | 22 | 06 |
| 17 Before / After & Focus Mode | 23 | 01, 03, 05; split view 14 |
| 18 Export | 24 | 07 |
| 19 Publish | 25 | 08, 10, 11, 12 |
| 20 Gallery Creation | 27 | 10 |
| 21 Entry Experience | 28 | 10 |
| 22 Editorial Grid | 29 | 10 |
| 23 Image Viewer | 30 | 01, 10; optional deep links 14 |
| 24 Favourites & Client Selection | 31 | 13 |
| 25 Downloads | 32 | 09, 10 |
| 26 Access & Privacy | 33 | 09, 10; expiration 14 |
| 27 Live Publish Updates | 34 | 12 |
| 28 Landing Experience | 36 | 01, 11 |
| 29 Project Index | 37 | 01, 11 |
| 30 Project Story | 38 | 01, 11 |
| 31 Focus Mode (Portfolio) | 39 | 11 |
| 32 Studio Publishing Integration | 40 | 11 |
| 33 Asset Store | 42 | 01, 02, 08 |
| 34 Rendition Service | 43 | 09 |
| 35 Sync Engine | 44 | 08, 12 |
| 36 Versions (Cloud) | 45 | 13; advanced browser 14 |
| 37 Security & Ownership | 46 | 01, 08, 09, 10, 12 |
| 38 NTO Motion System | 48 | 01 and every UI phase; final gate 12 |
| 39 Design System | 49 | 01 and every UI phase |
| 40 Performance | 50 | Every phase; final gate 12 |
| 41 Accessibility | 51 | Every UI phase; final gate 12 |
| 42 Error & Recovery | 52 | Every phase; final gate 12 |

## Using this roadmap

For the next separately requested implementation, continue with Phase 03 after resolving any reported Mac reliability problems. Use the Studio-first release sequence above to decide when hosted and future-platform phases begin. For each phase, turn the unchecked tasks into bounded implementation requests, validate its exit gate, then record completion evidence before advancing the status table. Update this roadmap when product decisions change; do not silently reinterpret deferred features as CORE.

Related documents: [Product](PRODUCT.md), [Architecture](ARCHITECTURE.md), [Design system](DESIGN-SYSTEM.md), [Setup](SETUP.md), and [Verification](VERIFICATION.md).
