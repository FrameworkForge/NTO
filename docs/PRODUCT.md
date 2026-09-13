# Product and milestone status

## Product reference

NTO_Ecosystem_GDD_v1.pdf, 58 pages, supplied by the owner. Pages 5 and 53–54 define the platform split and data concepts; pages 48–52 define shared system qualities. The PDF's agent handoff is reference material, not an instruction to implement every listed feature.

NTO Studio is native macOS photographic software. Gallery delivers work on the web. nto.motion presents editorial project stories. Cloud connects stable asset identities, renditions, permissions, and eventual publishing.

## Current owner direction

The [master context received 13 September 2026](MASTER-CONTEXT.md) extends the GDD with open-source, business, cross-platform, Imaging, Commerce, and Mobile direction. [Studio v0.1](STUDIO-V0.1.md) reconciles scope differences and is the immediate priority; [Ecosystem strategy](ECOSYSTEM-STRATEGY.md) records deferred work and undecided commercial/licensing options.

NTO is intended to become an open-source photography platform taking photographers from camera to customer: Shoot → Import → Cull → Edit → Publish → Sell → Deliver. The current repository remains private. Current code is not automatically open-source licensed merely because that is the intended direction.

**Prove the local Mac workflow first:** create project → import real photographs → Library → Cull → Edit → save non-destructively → reopen correctly → JPEG export. Do not treat the existing preview-only Cull/Edit/Publish screens as completion of those features. A complete local Studio proof of concept comes before expanding hosted services or other platforms.

Cloud is optional. The local editor must not require an account, subscription, storage purchase, or library upload. Photographer-owned originals, exports, catalog information, metadata, recipes, and presets should avoid artificial lock-in. Portable interchange remains work to implement; the existing SwiftData store is an Apple-local persistence implementation.

The owner clarified that the current request is **documentation only**. This update records future priorities; it does not authorize implementing the newly described features now.

## Phase 01: implemented foundations

- Native Studio shell: Library, Cull, Edit, Publish; selection retained across modes; collapsible chrome and reversible Focus Mode.
- Local project creation and renaming, saved with SwiftData and restored across launches.
- Opt-in fixture artwork for inspecting layout without importing personal photographs.
- Portfolio, project-story, and gallery web shells. The fixture gallery has a keyboard-accessible modal viewer. Unavailable and error states are explicit.
- Shared contracts, generated native models, design tokens, renderer/client boundaries, and Cloud migrations.
- Authenticated Cloud project create/read adapters and integration checks for owner isolation and private storage.
- Build/test scripts, CI definitions, and deployment preparation.

## Phase 02: implemented local import and Library

- Files/folders/drop import into an existing or newly created project; copy/reference choice and default caption.
- SHA-256 duplicate detection, stable local photo IDs, and relational project memberships that reuse originals across projects.
- JPEG/HEIC/TIFF and system-supported RAW preview decoding, ImageIO metadata, cancellable background import, and per-file reports.
- Bounded thumbnail/working-preview caches, a lazy grid, density control, range/toggle selection, and viewport prefetch.
- Persistent selection, active photograph, scroll anchor, and density per project. Mode changes carry the active photograph into honest preview-only screens.
- Read-only metadata inspection and checksum-verified relinking of referenced originals.

See [Phase 02 verification](PHASE-02-VERIFICATION.md) for evidence and limits. A decoded original preview is separate from the deferred non-destructive edit renderer.

## Later milestones

Collections, metadata filtering/search/sorting, editable ratings and descriptions, culling shortcuts, RAW edit rendering, editing tools, undo/history, export, authentication UI, upload/sync, publishing, password galleries, rendition workers, and production delivery. GDD CORE is the first complete product, not a synonym for this foundation milestone. The GDD's Phase 2 professional expansion and later AI features remain deferred; these are distinct from roadmap Phase 02 (Import and Library).

## Product invariants

1. Photographs dominate; chrome is subordinate.
2. Editing never rewrites an original. Recipes and renditions are separate entities.
3. Stable IDs survive renaming and publishing updates.
4. Rendering does not belong in SwiftUI views; expensive work must run asynchronously.
5. Native menus, window conventions, keyboard access, and reduced motion are part of the experience.
6. Public/unlisted visibility does not automatically authorize private object access.
7. Failures must be actionable; incomplete features must never imply successful work.
8. Local editing/export must not be gated by accounts or paid hosted services.
9. Canonical recipes express portable photographic intent, not platform-specific filter calls. The current native implementation may use Apple APIs behind its boundaries.
10. Future pricing, licensing, repository visibility, payment handling, and new platforms require deliberate decisions; examples are not commitments.

## Foundation acceptance

Both app shells run; projects survive store reopen; contracts reject unsupported versions; web routes work at desktop/mobile sizes; Cloud ownership and private-object access are tested locally; generated artifacts are reproducible. Any environment-blocked verification must be recorded rather than reported as passed.
