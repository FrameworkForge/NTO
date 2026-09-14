# NTO

Photography. Software. Motion.

NTO is a photography ecosystem intended to become open source, built around **Shoot → Import → Cull → Edit → Publish → Sell → Deliver**. The goal is a native, local-first workflow where photographers own their originals, catalog information, edits, presets, and exports.

**Current priority: get NTO Studio working as a complete local Mac photography application.** Foundations, local photo import/Library, organisation, metadata and keyboard culling are implemented. The rendering engine, saved edit history, the Light/Colour/Detail/Geometry controls, presets with selection sync, and JPEG/TIFF export now work, so the local workflow exists in code. Live verification with real shoots is still ahead. This is not yet a released Studio v0.1 or the GDD's complete CORE release.

Local import, organisation, editing, and export must remain usable without an account, subscription, or Cloud upload. Optional hosted Cloud, Gallery, Portfolio/nto.motion, Commerce, Mobile, and future platforms are the longer-term direction. Their existence in the docs does not mean they are implemented.

This repository holds the whole ecosystem: Studio, the web shells, the Cloud foundations and the strategy documents. **Proposed to the maintainer** (see [open-source readiness](docs/OPEN-SOURCE-READINESS.md)): keep this repository private and publish **NTO Studio and the shared contracts as a separate open-source repository** once the local workflow is validated, with the web integration, Cloud services and operations staying here. Until the maintainer decides, treat the repository as pre-release. No licence has been adopted yet; MPL 2.0 is the candidate under review. Pricing and plan examples in the strategy documents are proposals, not offers.

## Start here

- [Implementation status and outstanding work](docs/STATUS.md)
- [Open-source readiness and owner decisions](docs/OPEN-SOURCE-READINESS.md)
- [Current Studio v0.1 priority and acceptance criteria](docs/STUDIO-V0.1.md)
- [Owner's full master context](docs/MASTER-CONTEXT.md)
- [Ecosystem, open-source, and business direction](docs/ECOSYSTEM-STRATEGY.md)
- [Product and milestone boundaries](docs/PRODUCT.md)
- [Chronological ecosystem build roadmap](docs/BUILD-ROADMAP.md)
- [Architecture and data flow](docs/ARCHITECTURE.md)
- [Design system](docs/DESIGN-SYSTEM.md)
- [Local setup and deployment](docs/SETUP.md)
- [Verification results](docs/VERIFICATION.md)

## Web

Node 24.21.0 (see `.node-version`), pnpm 10.32.1, and Python 3 are required. `./scripts/pnpm` prefers an isolated Node 24 toolchain at `~/.local/share/nto/toolchains/node-v24.21.0-darwin-arm64` when one exists and otherwise uses the `node` on your PATH, so install Node 24 with your usual version manager first. The wrapper does not modify your shell profile.

```sh
./scripts/pnpm install --frozen-lockfile
./scripts/pnpm dev
```

Open http://localhost:3000. The site is the cinematic nto.motion layout: a full-viewport hero, a sticky project sequence, the Studio pipeline with what exists today, and an immersive gallery viewer (see [the design record](docs/WEB-SITE-DESIGN.md)). The default has an honest empty portfolio. To explore bundled abstract fixture artwork:

```sh
NTO_DEMO=1 ./scripts/pnpm dev
```

Then visit `/`, `/projects/studies-in-light`, and `/galleries/studies-in-light`.

## Studio

Open `apps/studio/NTOStudio.xcodeproj`, select **NTOStudio**, and Run. Requires macOS 26+ and Xcode 26+. Accept Apple's Xcode license when prompted. The app saves projects locally using SwiftData. Enable **Development fixtures** in the sidebar (or launch with `--fixtures`) to inspect the photo canvas. The window is a native split view: projects and collections in the sidebar, a segmented Library/Cull/Edit/Publish picker in the toolbar (Cmd-1 through Cmd-4), and an inspector on the right; Tab toggles Focus Mode, which hides both side panels.

```sh
./scripts/pnpm build:studio
./scripts/pnpm test:studio
```

Use **Import…** or **Shift-Cmd-I** to choose files/folders, a destination project, copy/reference storage, and an optional default caption. You can also drop files/folders onto the canvas. The Library supports click, Shift/Command selection, arrow navigation, Cmd-A, and Return to preview. The inspector shows capture metadata and can reconnect a referenced original by content identity. Library and Cull now share saved search/filter/sort and collections. Use 0–5 to rate, P to pick, X to reject, U to clear a flag, F for favourite, and Space in Cull for Fit/100% inspection. Edit captions and keywords in the inspector; collection operations are in the Collections menu. In Edit, the photograph fills the canvas with a floating bar for Original, 100%, Crop, the eyedropper and Undo/Redo, and the inspector's Light, Colour, Detail and Geometry groups expose exposure, contrast, highlights, shadows, whites, blacks, white balance (as shot, Kelvin, or the eyedropper: click a neutral area), tint, vibrance, saturation, sharpness, noise reduction, rotation with quarter turns, and crop; each has a slider and a numeric field, and each group can be reset. **Crop** opens a draggable rectangle with aspect presets over the uncropped photograph; Return applies it, Escape cancels. **100%** (or Space) inspects the edited result pixel for pixel. Press and hold the photograph or press `\` to compare with the original. Changes autosave, Cmd-Z undoes and Shift-Cmd-Z redoes, including after reopening. Save a preset from the current edit choosing which parameters it carries (white balance and geometry are off unless you include them), hover a preset to preview it, click to apply; Copy edits, Paste edits and Sync to the selected photographs share the same parameter choice, and Revert sync undoes the last sync on photographs not edited since. Presets are JSON files in the library's Presets folder; see [the preset format](docs/PRESETS.md). **Export…** (Shift-Cmd-E) renders the selected photographs with their edits to a folder as JPEG (with quality) or TIFF, at original size or fitted to a longest edge, with a filename template, a metadata policy (none, caption and keywords, or camera data with optional location) and a choice of skip, keep both or replace for existing files; progress, Stop and per-file failures show under the header. Publishing remains a later milestone.

Copies and previews are stored under `~/Library/Application Support/NTO/Studio`; referenced originals stay where you chose them. Back up this library directory, including its database and Originals folder. PreviewCache is derived and rebuildable. See [Phase 02 import verification](docs/PHASE-02-VERIFICATION.md), [Phase 03 culling verification](docs/PHASE-03-VERIFICATION.md), [Phase 04 rendering verification and limits](docs/PHASE-04-VERIFICATION.md), [Phase 05 editing controls](docs/PHASE-05-VERIFICATION.md), [Phase 06 presets and batch edits](docs/PHASE-06-VERIFICATION.md), and [Phase 07 export](docs/PHASE-07-VERIFICATION.md).

Unsigned local builds are supported by the command above. Distribution signing and notarization are outside this milestone.

## Cloud and checks

```sh
./scripts/pnpm cloud:start
./scripts/pnpm cloud:reset
./scripts/pnpm test:cloud
./scripts/pnpm check
./scripts/pnpm --filter @nto/web exec playwright install chromium
./scripts/pnpm test:web
```

Cloud requires a running Docker-compatible engine: Docker Desktop, or a Lima VM. If `limactl` is installed, `./scripts/container-start` creates or starts a VM named `nto` and `./scripts/container-stop` stops it; `./scripts/pnpm` then points `DOCKER_HOST` at that VM's socket unless you set your own. Stop an existing web dev server before running `test:web`. `cloud:reset` resets this **local development** database. It does not target a hosted project. Integration tests create isolated local test users and remove them afterwards.

No personal photographs, hosted resources, or production secrets are included in the repository.

## Requirements at a glance

| Part | Needs |
| --- | --- |
| Studio | macOS 26 or later, Xcode 26 or later (Command Line Tools alone cannot build SwiftData macros) |
| Web, contracts, generators | Node 24.21.0, pnpm 10.32.1, Python 3 |
| Cloud (optional) | A Docker-compatible engine for local Supabase |

## Contributing, security, names

[CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and [TRADEMARKS.md](TRADEMARKS.md) are drafts for the maintainer's approval, written for the future public Studio repository. Until a LICENSE file exists, all rights are reserved by the owner.
