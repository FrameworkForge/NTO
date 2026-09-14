# Foundation verification

This is the historical Phase 01 record. See [Phase 02 verification](PHASE-02-VERIFICATION.md) for import/Library checks and [Phase 03 verification](PHASE-03-VERIFICATION.md) for organisation/culling, plus [Phase 04 verification](PHASE-04-VERIFICATION.md) for current rendering and edit state.

Verified locally on 13 September 2026, on Apple silicon running macOS 26.6.2 with Xcode 26.6.

## Automated checks

| Check | Result |
| --- | --- |
| TypeScript checks across web, contracts, and Cloud | Passed |
| Web ESLint | Passed |
| Generated design-token and Swift-model drift checks | Passed |
| Shared contract and Cloud handler tests | 5 passed |
| Next.js 16.3.5 production build | Passed |
| Playwright desktop/mobile smoke tests | 4 passed |
| Native Swift package tests | 4 passed |
| Unsigned NTOStudio Debug build | Passed |
| Clean local Supabase migration/reset | Passed |
| Local Auth/API/storage integration suite | Passed |
| Live `/functions/v1/health` | HTTP 200, contract version 1 |

The integration suite creates two isolated local Auth users. It verifies project create/read, refusal of forged ownership, cross-account read/update denial, anonymous table denial, private object access, authorised signed downloads, immutable original keys, and rejection of relationships crossing owners. Test users and storage objects are removed afterwards.

Swift tests check project create/rename persistence across reopening a file-backed store, empty-title rejection, selection preservation and Focus Mode state restoration, shared JSON round-trip including explicit nulls, and rejection of unsupported contract/recipe versions.

## Live UI checks

- Studio: Cmd-N project creation, renaming, and persistence across application relaunch.
- Studio: all four modes reachable; selected fixture survives mode changes.
- Studio: consecutive Tab presses enter and leave Focus Mode, including toolbar focus; sheets retain normal Tab navigation.
- Studio: compact native window layout hides the inspector without overlaps; restoring the original width brings it back.
- Web: portfolio → project story → gallery → viewer flow; arrow navigation, Escape dismissal, and return of focus to the originating tile.
- Web: desktop/mobile layouts inspected visually; reduced motion and missing-route handling checked in browser tests.

The native UI verification project is named `Foundation verified`. Existing local projects are preserved. Fixture artwork is opt-in; no personal photographs were imported.

## Resolved setup issues

Node 24.21.0 and pnpm 10.32.1 are available through `scripts/pnpm`. Lima 2.2.0 and Docker CLI 29.8.0 were installed outside the repository for an isolated local engine. Its writable host mount is limited to the NTO workspace. Xcode's initial license blocker was resolved before the successful build/test runs.

During verification, the tooling sandbox initially lacked access to Xcode caches, browser localhost sockets, and the local Docker socket. After access was granted those checks ran successfully; no foundation verification remained blocked.

## Limits

This verifies the foundation milestone, not the complete GDD CORE release. Rendering, import, production authentication flows, real publishing/sync, and image workers are deferred. GitHub Actions definitions are included but have not run on a remote repository. No hosted Supabase/Vercel project, domain, distribution signature, or deployment was created.

Native validation was performed on Apple silicon in Debug configuration; Intel and distribution builds are not certified by these checks. The health endpoint reports service liveness, not complete dependency readiness.
