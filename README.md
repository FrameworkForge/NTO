# NTO

Photography. Software. Motion.

A foundation for **NTO Studio** (native macOS), **nto.motion + Gallery** (web), and **NTO Cloud** (Supabase). Foundations and local photo import/Library are implemented. This is not the GDD's complete CORE release.

## Start here

- [Product and milestone boundaries](docs/PRODUCT.md)
- [Chronological ecosystem build roadmap](docs/BUILD-ROADMAP.md)
- [Architecture and data flow](docs/ARCHITECTURE.md)
- [Design system](docs/DESIGN-SYSTEM.md)
- [Local setup and deployment](docs/SETUP.md)
- [Verification results](docs/VERIFICATION.md)

## Web

Node 24.21.0, pnpm 10.32.1, and Python 3 are required. The local launcher also finds the isolated Node installation prepared on this Mac; it does not modify your shell profile.

```sh
./scripts/pnpm install --frozen-lockfile
./scripts/pnpm dev
```

Open http://localhost:3000. The default has an honest empty portfolio. To explore bundled abstract fixture artwork:

```sh
NTO_DEMO=1 ./scripts/pnpm dev
```

Then visit `/`, `/projects/studies-in-light`, and `/galleries/studies-in-light`.

## Studio

Open `apps/studio/NTOStudio.xcodeproj`, select **NTOStudio**, and Run. Requires macOS 26+ and Xcode 26+. Accept Apple's Xcode license when prompted. The app saves projects locally using SwiftData. Enable **Development fixtures** in the sidebar (or launch with `--fixtures`) to inspect the photo canvas. Cmd-1 through Cmd-4 switch modes; Tab toggles Focus Mode.

```sh
./scripts/pnpm build:studio
./scripts/pnpm test:studio
```

Use **Import…** or **Shift-Cmd-I** to choose files/folders, a destination project, copy/reference storage, and an optional default caption. You can also drop files/folders onto the canvas. The Library supports click, Shift/Command selection, arrow navigation, Cmd-A, and Return to preview. The inspector shows capture metadata and can reconnect a referenced original by content identity. Editing, ratings, export, and publishing controls remain later milestones.

Copies and previews are stored under `~/Library/Application Support/NTO/Studio`; referenced originals stay where you chose them. Back up this library directory, including its database and Originals folder. PreviewCache is derived and rebuildable. See [Phase 02 verification and limits](docs/PHASE-02-VERIFICATION.md).

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

Cloud requires a running Docker-compatible engine. On this Mac, `./scripts/container-start` starts the prepared engine and `./scripts/container-stop` stops it. Stop an existing web dev server before running `test:web`. `cloud:reset` resets this **local development** database. It does not target a hosted project. Integration tests create isolated local test users and remove them afterwards.

No personal photographs, hosted resources, or production secrets are included.
