# Architecture

## Platform boundaries

| Surface | Stack | Responsibility |
| --- | --- | --- |
| Studio | Swift 6, SwiftUI, macOS 26+, SwiftData | Workspace and local project persistence |
| Web | Next.js 16 App Router, React 19, TypeScript, CSS Modules | Portfolio/Gallery route shells |
| Cloud | Supabase Postgres, Auth, private Storage, TypeScript Edge Functions | Remote records, ownership, project API, health |
| Shared | JSON Schema, TypeScript interfaces, generated Swift Codable models, JSON tokens | Versioned interchange and consistent design |

`apps/studio/NTOFoundation` is a local Swift package. The Xcode application composes workspace state, repository, and views; it does not contain image processing. `PhotoRenderer` accepts a local original reference, recipe, and output specification asynchronously. Its foundation implementation explicitly reports unavailable rendering.

`ProjectStore` owns SwiftData operations on the main actor, with explicit saves and rollback after failure. Project title validation runs before mutation. Local projects need no Cloud account. No sync or automatic upload is performed.

## Interchange

`packages/shared-types/schema.json` is the canonical contract v1 schema. TypeScript interfaces mirror it. `pnpm models` generates native Codable types and copies the canonical fixture into Swift test resources; `models:check` detects drift. UUIDs identify entities; timestamps are ISO 8601 strings. Both recipe and envelope versions are checked during native decoding, and JSON Schema rejects unsupported versions.

Asset is the original identity; EditRecipe is versioned edit state; Rendition is replaceable derived output; Publication records destination and order. Collections hold references rather than file copies. Local URLs exist only in native renderer inputs, never public DTOs. Database rows use snake_case; project adapters explicitly map to camelCase DTOs.

Rendition jobs define source object key, recipe revision, target format/dimensions, and success/error result. Workers are not implemented. Studio will render edited masters with Core Image; future image workers will resize those outputs in a separate runtime. Supabase Edge Functions are unsuitable for heavy rendering or Sharp: https://supabase.com/docs/guides/functions/limits.

## Cloud persistence and access

Auth users own all records. Row-level policies require `auth.uid() = owner_id`; composite foreign keys prevent relationships crossing owners. Anonymous roles have no table grants. Public website shells use fixtures only; even a database publication marked public is not exposed until a publication delivery API is implemented.

Original and rendition buckets are private. Authenticated object reads/inserts require an owner UUID prefix. No client overwrite/delete policy is installed. An original's established object key, asset ID, and owner cannot change. Derived replacements must use new object keys. Local collection removal cascades membership records, never files.

Supabase's project REST API supplies create/read operations through matching Swift and TypeScript adapters. Clients receive a publishable key and user access token. Service-role credentials belong only to backend administration or isolated local integration tests. The foundation does not store user tokens or implement sign-in UI.

The health function returns service name, status, and contract version, with no credentials or configuration. It is a liveness check, not a claim that storage/database dependencies are healthy.

## Failure and future work

Swift store errors reach an actionable alert. Cloud adapters classify failed requests; network/server failures can be retried. Web route errors offer retry and navigation. Future sync must journal work, handle conflicts explicitly, and publish replacements only after successful rendition creation. None of those deferred operations is simulated as completed here.
