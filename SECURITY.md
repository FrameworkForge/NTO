# Security policy

## Reporting a vulnerability

Please do not open a public issue for a security problem.

Use GitHub's private vulnerability reporting on this repository: **Security → Report a vulnerability**. It reaches the maintainer privately and keeps a record. If that option is unavailable to you, open an issue that says only "security report, please contact me" and the maintainer will reach out.

You can expect an acknowledgement within a week. Fixes are prioritised by impact on photographers' originals, libraries and privacy.

## What is in scope

- **NTO Studio** (`apps/studio`): anything that could alter or delete an original photograph, corrupt a library, execute code from an imported file, write outside the chosen export folder, or leak local file paths or metadata (for example location data) where the export policy says they are excluded.
- **Shared contracts and presets** (`packages/shared-types`, preset JSON): parsing of untrusted files.
- **Cloud foundations** (`services/cloud`): row-level security, storage policies and adapters, even though no hosted deployment exists yet.
- **Web** (`apps/web`): the portfolio and gallery shells.

## What is not a vulnerability

- Reports about features that are documented as not implemented (see [STATUS.md](docs/STATUS.md)).
- Missing hardening in local development tooling that only affects the developer's own machine.

## Supported versions

There is no released version yet. Reports against `main` are welcome.

## Handling secrets

The repository must never contain production keys, service-role credentials, signing material or personal photographs. `.env.example` files hold names only. If you find a committed secret, report it privately as above.
