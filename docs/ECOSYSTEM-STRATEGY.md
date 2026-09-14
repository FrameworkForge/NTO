# NTO ecosystem, open-source, and business direction

This is a searchable summary of the [owner's master context](MASTER-CONTEXT.md). These are product intentions and proposed sequencing, not shipped features, commercial offers, or legal advice. [Studio v0.1](STUDIO-V0.1.md) is the current priority.

## Product direction

NTO aims to connect **Shoot → Import → Cull → Edit → Publish → Sell → Deliver**. Its intended advantages are photographer ownership, native performance, open development, simpler event/sports workflows, and optional managed infrastructure. It should not depend on having more sliders than established editors or on artificially restricting local tools.

| Product | Intended responsibility | Timing |
| --- | --- | --- |
| Studio | Native desktop import, organisation, culling, editing, local export, later publishing | Current Mac priority |
| Imaging / Core | Portable photographic intent, catalog/metadata contracts, recipes, presets, renderer/decoder boundaries | Design boundaries now; extract implementations when justified |
| Cloud | Optional auth, sync, object storage, backups, renditions, publication records, delivery authorization | After reliable local workflow; existing foundation retained |
| Gallery | Fast editorial presentation, protected viewing, downloads, later client selections | After Cloud delivery; existing fixture shells retained |
| Portfolio / nto.motion | Authored project stories and direct Studio publishing | After Cloud publication boundary |
| Commerce | Photo sales, orders, verified payments, entitlements, automatic digital delivery | After usable Gallery and secure download delivery |
| Mobile | Import/cull/quick edit/review/publish, Gallery management, sales/activity | Later companion; not a miniature full desktop editor |
| Sports / schools / teams | Event/player tags, permitted contributors, storefronts, possible revenue sharing | Later, justified by real use |

## Ownership and portability

The local editor must work without an account, storage purchase, subscription, or server upload. Users should own originals, exports, catalog information, metadata, recipes, and presets. Documented interchange and preset formats are the direction; the current SwiftData database is not already a portable project format.

Apple UI remains native SwiftUI/AppKit as appropriate. Windows and Android UI decisions are deferred. Shared photographic intent should not encode UI types or specific CIFilter calls. Long-term platform targets include macOS, iPhone/iPad, Windows, Android, and potentially Linux; none is promised merely by listing it here.

## Open-source release gate

Proposal of 14 September 2026, pending the maintainer's decision: keep this repository private for the whole ecosystem and **publish NTO Studio and the shared contracts in a separate open-source repository**; the web integration, Cloud services and operations would remain private here and could be opened later on the owner's terms. If adopted, this refines the master context's list of open components (§30): the sync protocol and API surface are visible through Studio's client code regardless, but the server implementation and the gallery frontend are not committed to being open. Before creating the public Studio repository:

- Prove clone → build → open photo → edit → export with good documentation and compatibility/recovery tests.
- Review source/dependencies and settle a code license. MPL 2.0 is an unapproved candidate; no license change is made here.
- Prepare README, LICENSE (after selection), CONTRIBUTING, SECURITY, TRADEMARKS, CODE_OF_CONDUCT, and maintained docs.
- Separate code licensing from permissions for the NTO name, logo, official Cloud, and nto.motion identity. Draft brand terms require a deliberate decision; do not invent legal rights.
- Audit for secrets, private signing material, private photographs, and inappropriate sample data.
- Keep product/design direction and review standards clear while accepting targeted fixes, documentation, compatibility work, and performance improvements.

Likely open areas include Studio/Mobile, core/catalog/metadata/imaging architecture, recipe/preset formats, sync protocol, Gallery frontend, and API specifications. Self-hosting is a possible later offering, not currently supported deployment documentation.

## Business hypotheses

The intended principle is a free local editor with optional paid operation of useful infrastructure. Potential paid services include storage, device sync, Gallery/portfolio hosting, commerce/delivery, custom domains, teams, business accounts, and professional support. The free/paid boundary for optional client-selection services is not finalized; do not remove existing local features to create a paywall.

The master context illustrates Free, Cloud, Pro, and Business tiers, including example monthly prices (R0, around R99, R199-R299, and R499+), storage tiers, and hypothetical 8%/2%/0% platform fees. These are **placeholders only**. Do not put them into product pricing pages, billing code, promises of unlimited service, or commercial forecasts without validated costs and customer research. Payment-provider fees, unit costs, and applicable requirements are still to be scoped.

Prints, fulfillment, marketplaces, themes/plugins/presets, hosted AI, and school/sports products are later possibilities. They do not belong in the present Mac implementation.

## Commerce boundary for later implementation

The intended flow is: customer selection → server-defined price/order → payment provider → verified server webhook → paid order → entitlement → authorized delivery.

- The browser is not authoritative for prices or payment success.
- Verify provider callbacks and process retries idempotently. Keep credentials server-side and do not store raw card data.
- Entitlements reference stable asset identities, not filenames or expiring storage URLs. The intended corrected-version policy should allow the purchased photograph to evolve without losing entitlement.
- Download authorization derives from the order/entitlement and publication policy; use expiring signed delivery.
- Scope refunds, revocation, tax, payout, and jurisdiction-specific requirements when selecting providers and markets. No payment implementation, provider choice, or legal determination is made in this milestone.

Manual player/event tags can precede any face/jersey identification. Future automated suggestions should allow human confirmation and need their own privacy/access decisions, especially for school imagery.

## Scale through demonstrated need

Keep the initial hosted design understandable: API, managed database, object storage, CDN, authentication, and appropriate background workers. Supabase remains the agreed starting point. Add queues or separate rendition/ZIP/email/commerce workers when actual work requires them. Do not introduce a distributed system for hypothetical millions of users.

## Direction after the local Mac milestone

Real-shoot validation → targeted architecture cleanup → possible open-source Studio v0.1 → community maintenance → Cloud → Gallery/portfolio → Commerce → Mobile → validated hosted plans → Windows core/decode/render/export proof → full native UI → Android/Linux if justified.

This refines the original GDD roadmap with release/business gates. Some sequencing can change through explicit product decisions; Studio remains the first dependency.
