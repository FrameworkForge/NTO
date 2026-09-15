# nto.motion site (design import)

Implemented 14 September 2026 from the Claude Design mockup **nto.motion — Site** (project `768d55f0…`, file `nto.motion - Site.dc.html`). The mockup was applied to the existing Next.js routes and components; behaviour the smoke tests already guaranteed (keyboard navigation, focus return, reduced motion, honest empty and missing states, fixture gating) is unchanged.

## What the site looks like now

| Route | Implementation |
| --- | --- |
| Header (all pages) | Fixed over the page and inverted against the photograph with `mix-blend-mode: difference`; wordmark, Selected work, Studio, identity line. The skip link is unchanged. |
| `/` hero | Full-viewport section: fixture study with a slow Ken Burns drift under a gradient, eyebrow, "The space between." unmasked line by line, intro and an "Explore selected work" cue. Without `NTO_DEMO` the hero is typography only. |
| `/` marquee | A looping strip of "Photography · Software · Motion · Shoot → … → Deliver", decorative and hidden from assistive tech. |
| `/` Selected work | Header with a dynamic count (the fixture yields "001 project"; without fixtures the empty state remains), then one sticky full-viewport section per project: cover with a scroll-linked drift, kicker and year, index, title (links to the story), description, photograph count and "Enter gallery ↗" (links to the gallery). |
| `/` Studio | "One photograph. One ecosystem." beside a seven-step pipeline whose states are truthful: Shoot Yours, Import/Cull/Edit Studio, Publish Coming, Sell/Deliver Later. |
| `/` Closing | Fixture study behind a radial fade and "A place for the work to speak." with a link back to the work. |
| `/projects/[slug]` | Full-bleed story hero (cover, kicker and year, title, description, Enter gallery), then the studies with alternating widths and captions. |
| `/galleries/[slug]` | The editorial grid, then an immersive viewer: index rail (horizontal row on phones), title, live position, previous/next/close, click zones on either side of the image, caption, a progress bar, arrows and Escape. Horizontal swipe or drag on the photograph navigates; the neighbouring studies are preloaded so navigation never waits; the controls recede after 2.5 s without pointer, key or focus activity and return on any of them. Focus returns to the opening tile. |

Motion uses the token durations and CSS scroll-driven animations (`animation-timeline: view()`), which are progressive enhancement; `prefers-reduced-motion` disables all animation and smooth scrolling as before.

## Deliberate differences from the mockup

- **One project, not three.** The mockup invents North Stair and Harbour Studies. Only the fixture project exists, so the sequence and the count are driven by data and say "001 project". Real projects arrive with publishing.
- **No custom cursor.** The mockup hides the system cursor behind a blended dot with hover labels. That removes the native cursor for everyone, including people who rely on it; the native cursor stays and hover states carry the affordance.
- **No fabricated camera metadata or download.** The viewer's "11 SEP 2026 · CANON EOS R5 …" line and "Download web file" button describe things the fixtures and the site do not have. The viewer shows "Development artwork · no camera data" and the gallery page keeps its note that downloads are not available.
- **"Commission or collaborate" replaced.** There is no contact route yet, so the closing link goes back to the work rather than implying a channel that does not exist.
- **"Enter gallery" navigates** to the gallery route instead of opening a viewer on the landing page, so the gallery has a shareable address and the viewer keeps its dialog semantics.

## Verification

- `pnpm check` (typecheck, lint, contract tests, generated-file drift, production build) passes.
- Playwright smoke tests pass on desktop and mobile; assertions cover the pipeline list, the viewer's index rail, neighbour preloading, drag navigation, and the controls receding and returning.
- Screenshots of the landing (hero, project, Studio), story, viewer, and the phone layouts were taken from a fixture server for a visual check.
