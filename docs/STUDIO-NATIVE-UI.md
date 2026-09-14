# Studio native workspace (design import)

Implemented 14 September 2026 from the Claude Design mockup **NTO Studio — Native** (project `768d55f0…`, file `NTO Studio - Native.dc.html`, with `swiftui/WorkspaceView.swift` as its reference implementation). The mockup was applied as a restyle over the existing controllers and views so that no working behaviour was lost; where the mockup and the app disagreed, the app's behaviour won and the difference is listed below.

## What the workspace looks like now

| Region | Implementation |
| --- | --- |
| Window | `NavigationSplitView` sidebar → content → `.inspector`. The sidebar column follows `WorkspaceState.sidebarVisible`, the inspector `inspectorVisible`; Focus Mode (Tab) hides both. Title is the project, subtitle the photograph count. |
| Toolbar | Segmented mode picker (Library, Cull, Edit, Publish; Cmd-1 to Cmd-4), Import…, Export…, inspector toggle, Focus Mode. |
| Sidebar | Projects section with folder or cover icon, title and count badge (context menu: rename, use selected photograph as cover). Collections section with count badges; clicking a collection filters the Library and Cull (context menu: add or remove the selection, rename, move, remove). New Collection and New Project at the bottom, with the development-fixtures toggle. |
| Library | One row of pop-ups: **Show** (All, Picks, Rejects, Favourites, Rated 4 or Higher, Unrated), **Sort by**, a search field, a **Filters** menu (camera, media type, minimum rating, clear) and an **Organise** menu (favourite, add or remove from collections); count and size slider. Square tiles with a flag dot and stars; selection stroke; double-click or Return opens Cull. Range and toggle selection, arrow navigation, Cmd-A, scroll anchor and density persistence are unchanged. |
| Cull | Black canvas with the photograph, filename top-left, position top-right, a floating Liquid Glass bar (previous, stars, Pick/None/Reject, favourite, Fit/100%, next), filmstrip below. Keyboard shortcuts unchanged. |
| Edit | Canvas only, with a floating bar (Original, 100%/Fit, Crop or Apply/Cancel, eyedropper, Undo, Redo) and state badges top-left. All adjustments moved to the inspector as `EditInspector`: a Presets section (preset menu with save, manage, import, export; copy/paste; sync with progress and revert), then collapsible Light, Colour, Detail and Geometry sections with sliders, numeric fields, white balance controls, quarter turns, crop fields and the crop tool. |
| Inspector (Library, Cull) | Grouped form: filename and size, stars, Pick/None/Reject and favourite, read-only capture rows, caption and keywords with the editor, original availability and Locate Original. |
| Publish | Grouped form against the `Publication` contract: destination, visibility, downloads, link preview, a cover grid from the selection, and Preview/Publish buttons that are **disabled** with a footer saying publishing arrives with Cloud. Choosing a cover is real and sets the project cover. |

## Deliberate differences from the mockup

- **Search and metadata filters kept.** The mockup shows only Show and Sort; the app keeps search, camera, media type and rating filters behind a Filters menu, because Phase 03 verified them and culling a real shoot needs them.
- **Import and Export sheets unchanged.** The mockup sketches a generic pop-up sheet; the existing sheets carry more (storage choice, filename templates, metadata policy) and stay.
- **Preset hover preview replaced by a menu.** A menu cannot preview on hover; presets apply as one undo step and undo restores. The controller's hover-preview path remains for a future chip strip.
- **Publish does nothing yet.** The mockup's Publish button toggles a "published" state; the app's is disabled and says why. Product rule: an unfinished feature never presents as working.
- **Fixture toggle kept** in the sidebar footer so layouts can be inspected without personal photographs.
- **Glass bars** use `glassEffect` (macOS 26). The deployment target is already macOS 26.

## Not verified live

The change is layout and composition; the controllers and their tests are untouched (48 tests pass, plus one for the Show filter mapping). The Studio build succeeds, but the app was not launched against real photographs in this session: sidebar badge refresh after imports, glass bar contrast over bright photographs, inspector width at the minimum window, and the Publish cover grid with a large selection need a live check, recorded in [STATUS.md](STATUS.md).
