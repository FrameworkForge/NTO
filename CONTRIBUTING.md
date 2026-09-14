# Contributing to NTO

Thank you for your interest. NTO is pre-release software with a clear product direction: a local-first, native photography workflow that never gates editing or export behind an account. Contributions that strengthen that are welcome; contributions that change the direction need a conversation first.

## What we accept

Most welcome, in this order:

1. **Bug fixes** with a reproduction and, where practical, a test.
2. **Compatibility and recovery**: camera and file-format qualification, import edge cases, migration safety for existing libraries.
3. **Performance** improvements with measurements.
4. **Documentation** corrections and clarifications.
5. **Accessibility and keyboard** improvements.

Please open an issue before starting on: new editing tools, changes to the recipe or preset formats, anything touching Cloud, publishing, commerce, or a new platform. Those are sequenced by [the build roadmap](docs/BUILD-ROADMAP.md) and product decisions are held by the maintainer. A pull request that arrives without that conversation may be closed, however good the code.

## Ground rules that every change must respect

These come from [the product invariants](docs/PRODUCT.md) and are checked in review:

- Originals are never rewritten. Edits are recipes; outputs are derived files.
- Local import, editing and export must work with no account, subscription, network or Cloud.
- Rendering, decoding, export and file transfer stay off the SwiftUI view layer and off the main actor's critical path.
- Existing libraries must keep opening. SwiftData schema changes are additive; recipe and preset format changes are additive with defaults, or come with an explicit version and migration.
- Failures are actionable and specific. An unfinished feature never presents as working.
- No personal photographs, secrets or hosted credentials in the repository. Tests generate their own fixtures.
- Keyboard access and reduced motion are part of every UI change. The design system is monochrome and editorial; see [DESIGN-SYSTEM.md](docs/DESIGN-SYSTEM.md).

## Setting up

Requirements and commands are in [SETUP.md](docs/SETUP.md) and the [README](README.md). In short: macOS 26 with Xcode 26 for Studio; Node 24, pnpm 10 and Python 3 for the web, contracts and generators; a Docker-compatible engine only if you work on Cloud.

```sh
./scripts/pnpm install --frozen-lockfile
./scripts/pnpm check          # typecheck, lint, contract tests, generated-file drift, web build
./scripts/pnpm test:studio    # Swift package tests
./scripts/pnpm build:studio   # unsigned Studio build
```

If the checkout lives in an iCloud-synced folder, build with an out-of-tree scratch path; SETUP.md explains why.

## Making a change

- Branch from `main`. Keep pull requests focused on one thing.
- Regenerate rather than hand-edit generated files: `pnpm tokens` after changing `tokens.json`, `pnpm models` after changing `schema.json`. CI fails on drift.
- Add or extend tests in the same pull request. Swift tests live in `apps/studio/NTOFoundation/Tests`; contract tests in `packages/shared-types/tests`; Cloud tests in `services/cloud/tests`.
- Update the documentation that describes the behaviour you changed, including [STATUS.md](docs/STATUS.md) and the relevant phase verification record. Record what you verified and what you could not; never claim a check that did not run.
- Run the checks above before opening the pull request. Say in the description which ones ran locally and on what hardware.

## Pull request description

Use the template. State the problem, the change, how it was verified, and any effect on saved libraries, recipes, presets or exports. Link the issue.

## Sign-off

Every commit must carry a Developer Certificate of Origin sign-off (`git commit -s`), certifying that you wrote the change or have the right to submit it under the project's licence. See <https://developercertificate.org>.

## Review

The maintainer reviews for the ground rules above, test coverage, documentation and fit with the roadmap. Review comments are about the code, not the person. Expect requests for a test or a doc update; expect a no when a change moves the product somewhere it has not decided to go.

## Licence

Contributions are accepted under the project's code licence once one is adopted; see [LICENSING status](docs/OPEN-SOURCE-READINESS.md). The NTO name, logo and hosted services are not covered by the code licence; see [TRADEMARKS.md](TRADEMARKS.md).
