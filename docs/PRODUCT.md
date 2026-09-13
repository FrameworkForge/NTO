# Product and foundation milestone

## Product reference

NTO_Ecosystem_GDD_v1.pdf, 58 pages, supplied by the owner. Pages 5 and 53–54 define the platform split and data concepts; pages 48–52 define shared system qualities. The PDF's agent handoff is reference material, not an instruction to implement every listed feature.

NTO Studio is native macOS photographic software. Gallery delivers work on the web. nto.motion presents editorial project stories. Cloud connects stable asset identities, renditions, permissions, and eventual publishing.

## This milestone

- Native Studio shell: Library, Cull, Edit, Publish; selection retained across modes; collapsible chrome and reversible Focus Mode.
- Local project creation and renaming, saved with SwiftData and restored across launches.
- Opt-in fixture artwork for inspecting layout without importing personal photographs.
- Portfolio, project-story, and gallery web shells. The fixture gallery has a keyboard-accessible modal viewer. Unavailable and error states are explicit.
- Shared contracts, generated native models, design tokens, renderer/client boundaries, and Cloud migrations.
- Authenticated Cloud project create/read adapters and integration checks for owner isolation and private storage.
- Build/test scripts, CI definitions, and deployment preparation.

## Later milestones

Photo import, thumbnail/cache implementation, real library selection mechanics, culling shortcuts, RAW processing, editing tools, undo/history, export, authentication UI, upload/sync, publishing, password galleries, rendition workers, and production delivery. GDD CORE is the first complete product, not a synonym for this foundation milestone. Phase 2 and AI features remain deferred.

## Product invariants

1. Photographs dominate; chrome is subordinate.
2. Editing never rewrites an original. Recipes and renditions are separate entities.
3. Stable IDs survive renaming and publishing updates.
4. Rendering does not belong in SwiftUI views; expensive work must run asynchronously.
5. Native menus, window conventions, keyboard access, and reduced motion are part of the experience.
6. Public/unlisted visibility does not automatically authorize private object access.
7. Failures must be actionable; incomplete features must never imply successful work.

## Foundation acceptance

Both app shells run; projects survive store reopen; contracts reject unsupported versions; web routes work at desktop/mobile sizes; Cloud ownership and private-object access are tested locally; generated artifacts are reproducible. Any environment-blocked verification must be recorded rather than reported as passed.
