# Setup and deployment

## Toolchain

- macOS 26+ with Xcode 26+ for Studio. Review and accept Apple's license in Xcode or `sudo xcodebuild -license`; the scaffold does not accept agreements automatically.
- Node 24.21.0, pnpm 10.32.1, and Python 3. `./scripts/pnpm` finds the isolated Node installation on this Mac; other machines can use their existing PATH.
- A Docker-compatible container engine for local Supabase. Container tools prepared for this workspace live outside the repository under `~/.local/share/nto/toolchains/containers`.

Install dependencies with `./scripts/pnpm install --frozen-lockfile`. Never copy production service-role credentials into the frontend or native app. Examples contain names and placeholders only.

## Local Cloud

The Supabase CLI is locked as a workspace dependency. Start Docker Desktop or the prepared NTO runtime with `./scripts/container-start`. From the repository root:

```sh
./scripts/pnpm cloud:start
./scripts/pnpm cloud:reset
./scripts/pnpm test:cloud
./scripts/pnpm --filter @nto/cloud serve
```

The API is http://127.0.0.1:54321; Studio is http://127.0.0.1:54323. The function is `/functions/v1/health`. `serve` stays running until interrupted. `pnpm --filter @nto/cloud stop` stops the stack while retaining local data. `cloud:reset` recreates only the local development database and reapplies migrations. Integration tests restrict their target to localhost, create two isolated users, test access boundaries, and clean up.

If using the prepared Lima runtime, start it with the documented `scripts/container-start` command, then use the project launcher. The launcher sets DOCKER_HOST only when no external value was supplied and the NTO socket exists. The prepared VM mounts only this workspace as writable. Run `./scripts/container-stop` to release the VM’s resources when finished.

## Web preview

Default: `./scripts/pnpm dev`. Opt-in fixtures: `NTO_DEMO=1 ./scripts/pnpm dev`. For a fixture production preview, set `NTO_DEMO=1` during both build and start because the landing page is prerendered. Use fixtures only in designated development/preview environments. Stop an existing `next dev` process before `pnpm test:web`; the test runner starts its own fixture server on port 3100.

## Supabase hosted preparation

No hosted project is created in this milestone. When deploying later:

1. Create a Supabase development project in the chosen region; store credentials in the provider's secret settings.
2. Log in with the Supabase CLI and link the project from `services/cloud` using `pnpm exec supabase link --project-ref <reference>`.
3. Review `pnpm exec supabase db diff --linked` and the migration before applying `pnpm exec supabase db push`.
4. Deploy the liveness function with `pnpm exec supabase functions deploy health --no-verify-jwt`.
5. Configure Auth redirect URLs for the actual web/native login flows when implemented. Local auto-confirmed email settings are development-only.
6. Verify owner isolation and storage privacy in an isolated hosted test project before connecting real users. The local integration test intentionally refuses hosted URLs.

Do not enable public buckets to make previews work. Gallery/password delivery, sign-in UI, worker deployment, and real publishing need their own feature implementation.

## Vercel preparation

Create one Vercel project from this repository, set Root Directory to `apps/web`, and allow source files outside that directory. The checked-in `vercel.json` installs the root pnpm workspace and builds the web app with generated token verification. Use Node 24 and the committed lockfile. Keep `NTO_DEMO=0` for a real public environment; set it to `1` only for deliberate fixture previews.

Only the Supabase URL and publishable key may use public frontend variables. Server service-role credentials must never use `NEXT_PUBLIC_` or be embedded in Studio. DNS, paid plans, production promotion, code signing, and notarization remain separate deployment work.

## CI

GitHub Actions definitions check web types/lint/build, contracts, generated files, browser routes, native package tests and unsigned app build, and a clean local Supabase migration/access run. No deployment occurs in CI. Configure an Xcode 26+ macOS runner before relying on the native job; it fails clearly if that SDK is unavailable.

## Local library storage

Studio stores its library at `~/Library/Application Support/NTO/Studio/Library.store`, with SQLite companion files managed by SwiftData. This is independent of Supabase. Rebuilding the application does not remove local projects.
