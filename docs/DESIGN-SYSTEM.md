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

The portfolio uses a large editorial introduction, dominant artwork, and a numbered project sequence. Gallery uses varied compositions rather than uniform cards. Native sidebars recede; the inspector hides automatically below 1000 points while preserving the user's visibility preference. The window minimum is 700 × 500.

Bundled SVG studies are deterministic abstract development artwork, labelled accordingly. They are not the user's photographs, commissioned brand assets, or published projects. Web fixtures require `NTO_DEMO=1`; Studio fixtures require an explicit toggle/launch flag.

## Focus Mode

Studio stores sidebar and inspector visibility on entry and restores it on exit. Selection and active mode are independent of chrome. Escape closes the web gallery dialog; focus returns to the opening tile. Native dialog focus containment supplies a keyboard exit without trapping the visitor.
