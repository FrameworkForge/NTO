# NTO design system

## Direction

Black and white, editorial scale, controlled negative space, and photography supplying colour. Studio remains a functional native workspace; Gallery is immersive; nto.motion is editorial. Do not add decorative gradients, glass panels, or dashboard chrome.

## Tokens

`packages/design-tokens/tokens.json` is the canonical source. Run `pnpm tokens` after editing it. This generates web CSS variables and SwiftUI `NTOTokens`. `pnpm tokens:check` detects drift.

- Colours: black, near-black canvas, white, off-white paper, muted grey, dividing line.
- Spacing: 4, 8, 16, 24, 40, 64 points/pixels.
- Typography roles: caption 12, body 16, title 32, display 72. Native semantic text styles and fluid editorial headings adapt these roles to the platform.
- Motion: fast 120 ms, standard 240 ms, reveal 600 ms. Motion expresses state, never blocks access.

The O progress ring has an accessible text label. Reduced motion removes its rotation while preserving the progress state. Web focus outlines remain visible; icon controls have accessible names.

## Layout and fixtures

The portfolio is cinematic: a full-viewport hero, a marquee, a sticky numbered project sequence and a Studio pipeline, recorded in [WEB-SITE-DESIGN.md](WEB-SITE-DESIGN.md). Gallery uses varied compositions rather than uniform cards and an immersive viewer. Studio follows the native macOS workspace shape described in [STUDIO-NATIVE-UI.md](STUDIO-NATIVE-UI.md): a split-view sidebar, a segmented mode picker in the toolbar, an inspector, and floating glass bars over the photograph rather than control rows beneath it. The window minimum is 700 × 500.

Bundled SVG studies are deterministic abstract development artwork, labelled accordingly. They are not the user's photographs, commissioned brand assets, or published projects. Web fixtures require `NTO_DEMO=1`; Studio fixtures require an explicit toggle/launch flag.

## Focus Mode

Studio stores sidebar and inspector visibility on entry and restores it on exit. Selection and active mode are independent of chrome. Escape closes the web gallery dialog; focus returns to the opening tile. Native dialog focus containment supplies a keyboard exit without trapping the visitor.

## Owner context alignment

The [master context](MASTER-CONTEXT.md) reinforces the existing minimal, monochrome, editorial, photograph-first identity and native platform behavior. Its O motif may eventually extend to payment/delivery states, but this does not add those flows now. Studio's current priority is a usable local Mac workflow; Mobile and other desktop platforms should later adapt controls, gestures, and window conventions to their own platform.

The context's `#777777` grey is a proposed brand neutral. The existing canonical tokens (including the lighter muted text colour) remain in force. Any future palette change should preserve appropriate contrast for the actual background and text role rather than blindly replacing all greys. The master context does not by itself add visual effects, glass surfaces, motion, or tools to the app.
