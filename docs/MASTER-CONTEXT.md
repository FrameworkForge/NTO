> Owner-supplied strategic context, received 13 September 2026. Preserved below for reference. Current delivery priority and reconciliation with the original GDD are recorded in [Studio v0.1](STUDIO-V0.1.md), [Product](PRODUCT.md), and [Build roadmap](BUILD-ROADMAP.md).
>
> This describes intended direction, examples, and future options, not implemented capabilities. Embedded agent instructions and sample code do not independently authorize future implementation, public release, a license change, pricing, or deployment. Pricing examples and the MPL 2.0 discussion are proposals, not commitments or a legal determination.

# NTO — Master Product, Architecture, Open-Source and Business Context

## Purpose of this document

This document is long-term context for anyone working on NTO, especially Codex or other AI coding agents.

It explains:

- what NTO is
- why it exists
- what problem it is solving
- how it differs from Lightroom
- the current proof of concept
- the long-term product ecosystem
- open-source strategy
- business and subscription model
- cross-platform strategy
- Swift architecture
- Metal/Vulkan rendering strategy
- mobile strategy
- Gallery and Commerce
- Cloud infrastructure
- scaling philosophy
- what should and should not be built yet

Before making major architecture decisions, read this document.

---

# 1. What is NTO?

NTO is an open-source photography software ecosystem.

It is not intended to simply become another Lightroom clone.

The long-term goal is to create a complete photography workflow:

**Shoot → Import → Cull → Edit → Publish → Sell → Deliver**

A photographer should eventually be able to go from taking the photograph to delivering or selling it to a customer without moving between several unrelated applications and services.

The ecosystem is expected to contain:

- **NTO Studio** — desktop photography application
- **NTO Mobile** — mobile photography companion
- **NTO Imaging** — shared photography/rendering architecture
- **NTO Cloud** — optional hosted synchronization and storage
- **NTO Gallery** — client/event Gallery platform
- **NTO Commerce** — photo sales and automatic digital delivery
- **NTO Portfolio / nto.motion** — photographer portfolio publishing
- possible future professional, team and sports products

The core editor should remain usable without NTO Cloud.

---

# 2. The core idea

Traditional photography workflows often look like:

```text
Camera
↓
Photo editor
↓
Export folder
↓
Finder / Explorer
↓
Gallery service
↓
Website
↓
Payment service
↓
Manual delivery
```

NTO should eventually turn that into:

```text
CAMERA
  ↓
IMPORT
  ↓
CULL
  ↓
EDIT
  ↓
PUBLISH
  ↓
NTO GALLERY
  ↓
CUSTOMER SELECTS
  ↓
CUSTOMER PAYS
  ↓
AUTOMATIC DELIVERY
```

This workflow integration is one of the main reasons NTO should exist.

---

# 3. How NTO is different from Lightroom

NTO should not attempt to beat Adobe by immediately having more editing features.

Adobe has decades of imaging engineering and an extremely mature RAW-processing ecosystem.

NTO should instead compete on:

- openness
- photographer ownership
- native performance
- simple workflow
- event/sports photography
- publishing
- commerce
- automatic delivery
- extensibility
- optional rather than mandatory Cloud services

The intended difference is approximately:

```text
LIGHTROOM

Import
Cull
Edit
Export / Share
```

versus:

```text
NTO

Import
Cull
Edit
Publish
Gallery
Sell
Deliver
Manage
```

NTO should eventually be closer to a **photography operating system** than only a RAW editor.

---

# 4. Product philosophy

NTO should follow these principles.

## Photographer-first

The photograph should dominate the interface.

Controls exist to support photography rather than become the visual focus.

---

## Local-first

A user should be able to install NTO Studio and:

- import photographs
- organize them
- edit them
- export them

without:

- creating an NTO account
- buying storage
- purchasing a subscription
- uploading their library to NTO servers

NTO Cloud should be optional.

---

## Photographer ownership

Users should own:

- their original files
- exported photographs
- catalog information
- edit recipes
- metadata
- presets

NTO should avoid artificial lock-in.

---

## Non-destructive editing

Original photographs must never be modified by normal editing operations.

NTO should store editing instructions separately.

Conceptually:

```text
ORIGINAL RAW
+
EDIT RECIPE
+
RENDER ENGINE
=
DISPLAYED / EXPORTED PHOTO
```

---

## Performance is part of the design

NTO should feel fast.

Important targets include:

- quick launch
- smooth library scrolling
- fast culling
- responsive editing
- background rendering
- efficient preview caching
- GPU acceleration
- large-shoot performance

A sports shoot may contain thousands of photographs.

Architecture should account for this.

---

## Native where it matters

NTO should not look like a generic web application wrapped in a desktop window.

Apple applications should feel native to Apple platforms.

Windows applications should feel appropriate on Windows.

Android should feel appropriate on Android.

The NTO identity should remain consistent while respecting each platform.

---

# 5. Brand and design direction

The NTO identity should be:

- minimal
- photography-first
- predominantly black and white
- premium
- editorial
- modern
- fast
- deliberate

Primary tones:

```text
Black       #000000
Near-black  #0A0A0A
White       #FFFFFF
Soft white  #F2F2F2
Grey        #777777
```

Photographs provide most of the colour.

Avoid:

- generic purple AI gradients
- excessive glass panels
- unnecessary glowing elements
- visual effects without purpose
- clutter

---

# 6. NTO motion philosophy

Motion should explain spatial relationships or system state.

Rule:

> Nothing moves simply because it can. Movement should communicate where something came from, where it is going, or what the system is doing.

Examples:

- thumbnail expands into Viewer
- project cover becomes Gallery hero
- O mark fills during upload
- controls disappear during Focus Mode

The **O** in NTO may become a recurring interaction motif for:

- loading
- publishing
- synchronization
- payment
- download
- progress

---

# 7. Current development priority

The current priority is:

# NTO Studio

The immediate target is NOT the full NTO ecosystem.

The first serious proof of concept is a reliable local photography workflow.

NTO should first prove:

```text
CREATE PROJECT
↓
IMPORT REAL PHOTOGRAPHS
↓
LIBRARY
↓
CULL
↓
EDIT
↓
SAVE EDIT NON-DESTRUCTIVELY
↓
EXPORT
```

The practical test is:

> Can I photograph a real event and process the shoot using NTO instead of needing Lightroom for the basic workflow?

If not, continue improving Studio.

---

# 8. Initial NTO Studio scope

## Import

Support should eventually include:

- JPEG
- HEIC where appropriate
- Apple-supported RAW
- Canon CR3
- folders
- removable media
- duplicate detection

Import should:

- create Asset records
- read metadata
- create thumbnails
- create previews
- preserve original files

---

# 9. Library

The Library should support:

- Projects
- Collections
- photograph grid
- ratings
- Pick
- Reject
- Favourite
- metadata
- filtering
- sorting
- search
- large libraries

The initial organizational model should remain understandable.

Do not prematurely create extremely complicated DAM concepts.

---

# 10. Cull

Cull should be optimized for speed.

Typical actions:

```text
Previous / Next
Pick
Reject
1–5 Stars
Favourite
Zoom
100%
Focus Mode
```

The user should be able to move through thousands of images rapidly.

---

# 11. Edit

Initial editing tools:

## Light

- Exposure
- Contrast
- Highlights
- Shadows
- Whites
- Blacks

## Colour

- Temperature
- Tint
- Vibrance
- Saturation

## Detail

- Sharpening
- Noise reduction

## Geometry

- Crop
- Rotate
- Straighten

Advanced functionality should come later.

Do not prioritize advanced AI before core RAW development is reliable.

---

# 12. EditRecipe

Every editable Asset should store a non-destructive EditRecipe.

Conceptually:

```swift
struct EditRecipe: Codable {
    var exposure: Double
    var contrast: Double

    var highlights: Double
    var shadows: Double

    var whites: Double
    var blacks: Double

    var temperature: Double
    var tint: Double

    var vibrance: Double
    var saturation: Double

    var sharpening: Double
    var noiseReduction: Double

    var crop: CropRecipe?
}
```

Exact representation may evolve.

The important principle is:

> The EditRecipe describes the desired photographic result. It should not directly describe one operating system's rendering API.

Do not store:

```text
CIFilter X with Apple-specific parameters
```

as the canonical editing model.

Store:

```text
Exposure = +0.35 EV
Highlights = -0.20
Temperature = 5300 K
```

and let the renderer interpret it.

---

# 13. Presets

Presets should serialize a selected portion of EditRecipe.

Users should eventually be able to:

- create
- rename
- delete
- preview
- apply
- export
- import
- share

presets.

The format should ideally be documented and portable.

---

# 14. Batch editing

Event photographers often photograph hundreds of images under similar lighting.

Batch editing is therefore essential.

Example:

```text
SYNC EDITS

✓ Exposure
✓ Contrast
✓ Highlights
✓ Shadows
✓ Colour
✓ Detail

☐ Crop
☐ White balance
```

The user should be able to edit one representative photo and apply chosen parameters to many Assets.

---

# 15. Export

Initial export:

- JPEG
- size
- quality
- naming
- metadata options

Future:

- TIFF
- additional colour profiles
- reusable export presets
- advanced resizing
- Gallery-specific outputs

---

# 16. Long-term NTO ecosystem

After Studio is reliable:

```text
NTO Studio
    ↓
NTO Cloud
    ↓
NTO Gallery
    ↓
NTO Commerce
    ↓
NTO Mobile
```

This does not necessarily represent exact implementation order, but Studio remains the foundation.

---

# 17. NTO Gallery

NTO Gallery is not simply a file-hosting page.

It should be a premium photography presentation environment.

A photographer could:

```text
NTO Studio
↓
Select final photographs
↓
Publish
↓
Gallery automatically created
```

Example:

```text
AFFIES VS GREY

12 September 2026

151 photographs
```

Gallery characteristics:

- mobile-first
- editorial layouts
- large photography
- minimal controls
- fast image loading
- Viewer
- favourites
- protected Galleries
- downloads
- client selection
- live updates

---

# 18. Gallery publishing

Publishing should feel like part of editing.

The user should not need to:

```text
Export
↓
Find folder
↓
Open browser
↓
Sign in somewhere
↓
Create Gallery
↓
Upload everything again
```

NTO already knows the Asset, EditRecipe, project and publication state.

Publishing should therefore be:

```text
SELECT
↓
PUBLISH
```

---

# 19. NTO Commerce

A long-term differentiating feature is the ability to sell photographs directly.

Example Gallery:

```text
AFFIES VS GREY

151 photographs

Individual photo      R30
5-photo package        R120
10-photo package       R200
Full Gallery           R350
```

Customer workflow:

```text
Browse
↓
Find photographs
↓
Add photographs
↓
Pay
↓
Payment verified
↓
Entitlement generated
↓
High-resolution files delivered
```

The photographer should not manually:

- verify proof of payment
- locate files
- export files
- send Drive links

NTO should automate this.

---

# 20. Commerce architecture rules

Payment state must be server-authoritative.

Never trust:

```text
browser says payment succeeded
```

The correct model is:

```text
Customer
↓
Payment provider
↓
Verified server callback / webhook
↓
NTO backend
↓
Order marked Paid
↓
Entitlement generated
↓
Download authorized
```

Important requirements:

- verified webhooks
- idempotency
- no raw card storage
- provider credentials only server-side
- no frontend price authority
- signed expiring download links
- stable Asset identity

---

# 21. Purchase entitlement model

A purchase belongs to the photograph, not to a particular file URL.

Example:

```text
Asset ID:
E812AC...
```

Customer purchases that Asset.

Later the photographer:

- adjusts exposure
- re-renders it
- changes filename
- changes storage location

The entitlement should still exist.

This allows the user to download the corrected version without repurchasing it.

---

# 22. Sports photography direction

Sports/event photography could become an important specialty for NTO.

Future concepts:

```text
Match:
Affies vs Grey

Players:
#1
#2
#3
...
```

A photographer could tag images:

```text
IMG_4821
Player #12
```

Then customers could browse:

> All photographs of Player #12

Future Commerce example:

> Buy all 17 photographs of Player #12 — R180

Initially tagging can be manual.

Future tools may assist with:

- face grouping
- jersey numbers
- player identification

Human confirmation should remain possible.

---

# 23. NTO Mobile

NTO Mobile should not become a tiny desktop application.

Its purpose is:

> photographer command centre

Primary mobile functionality:

- Import
- Cull
- Quick Edit
- Review
- Publish
- Gallery management
- Sales
- Activity

Not initially:

- extremely complicated mask workflows
- huge metadata interfaces
- full desktop batch management
- every Studio editing feature

---

# 24. Example NTO Mobile workflow

After photographing an event:

```text
CAMERA
↓
CARD → PHONE
↓
IMPORT
↓
CULL
↓
QUICK EDIT
↓
PUBLISH
↓
SHARE
↓
CUSTOMERS BUY
↓
CHECK SALES
```

Possible Cull gestures:

```text
Swipe right  → Pick
Swipe left   → Reject
Swipe up     → Favourite
Double tap   → Zoom
```

Quick Edit could expose:

```text
Light
Colour
Crop
Look
```

rather than displaying an enormous desktop interface.

---

# 25. Example mobile business view

```text
AFFIES VS GREY

Published: 151 photos

Views             1,284
Orders                14
Photos sold            42
Gross sales        R1,620
```

NTO Mobile could allow:

- changing Gallery price
- changing cover
- hiding photos
- adding photographs
- publishing updates
- checking orders
- sharing links

---

# 26. NTO Cloud

Cloud is optional infrastructure.

Local Studio must remain useful without it.

NTO Cloud may eventually provide:

- asset sync
- project sync
- Gallery hosting
- renditions
- storage
- backups
- publication
- Commerce infrastructure
- signed downloads
- activity
- device sync

Cloud should use standard scalable infrastructure rather than reinventing common systems.

Conceptually:

```text
API
Database
Object storage
CDN
Background workers
Authentication
Payment integration
```

---

# 27. Open-source strategy

NTO is intended to become open source.

However, it does not have to become public immediately.

Initial development may remain private while:

- architecture changes rapidly
- persistence is unstable
- rendering design changes
- basic workflows do not work

The public release should happen once NTO is credible.

---

# 28. Recommended open-source milestone

Approximately:

# NTO Studio v0.1

Should support:

```text
✓ Build successfully
✓ Create project
✓ Import JPEG
✓ Import common RAW
✓ Library
✓ Cull
✓ Rating
✓ Pick / Reject
✓ Exposure
✓ Contrast
✓ Highlights
✓ Shadows
✓ White balance
✓ Vibrance
✓ Saturation
✓ Sharpening
✓ Basic noise reduction
✓ Crop
✓ Presets
✓ Batch editing
✓ Non-destructive EditRecipe
✓ JPEG export
```

Another developer should be able to:

```text
clone repository
↓
build
↓
open photo
↓
edit
↓
export
```

without spending hours repairing the project.

---

# 29. Open-source repository requirements

Before public release:

```text
README.md
LICENSE
CONTRIBUTING.md
SECURITY.md
TRADEMARKS.md
CODE_OF_CONDUCT.md
docs/
```

Never commit:

- production API keys
- database passwords
- private signing certificates
- payment secrets
- Cloud administrator credentials

---

# 30. What should be open source?

Likely:

```text
NTO Studio
NTO Mobile
NTO Core
NTO Imaging architecture
NTO Catalog
NTO Metadata
EditRecipe specification
Preset format
Sync protocol
Gallery frontend
API specifications
```

Potentially:

```text
self-hosting implementation
```

later.

---

# 31. What can remain commercial?

Open source does not mean every service must be free.

Potential commercial products:

```text
Official NTO Cloud
Managed synchronization
Hosted storage
Hosted Galleries
Commerce
Payment infrastructure
Automatic delivery
Business accounts
Teams
Professional support
```

Users may potentially self-host.

Most photographers will probably prefer paying NTO rather than maintaining infrastructure.

---

# 32. NTO branding

The code can be open source while the NTO brand remains protected.

Separate:

```text
CODE
→ open-source license
```

from:

```text
NTO NAME
NTO LOGO
OFFICIAL NTO CLOUD
nto.motion
→ controlled brand
```

A fork should not automatically have the right to pretend it is official NTO.

---

# 33. Licensing direction

A current license worth investigating is:

**MPL 2.0**

Potential reasons:

- modifications to covered NTO source files remain open when distributed
- developers can combine NTO with separate proprietary software
- less restrictive than GPL
- stronger reciprocity than MIT/Apache

This is not a final legal determination.

Do not change the project's license without explicit approval.

Professional legal review may be appropriate before commercial/public release.

---

# 34. NTO business model

The business should not depend on artificially crippling the editor.

The philosophy should be:

> The editor is free.  
> Your photography belongs to you.  
> Pay NTO when you want NTO to operate infrastructure for you.

---

# 35. Free NTO

Potential free/open-source functionality:

```text
NTO Studio
NTO Mobile
Local library
RAW editing
Cull
Presets
Batch editing
Local export
Local project/catalog
```

No mandatory subscription is required to edit photographs.

---

# 36. Paid NTO services

Revenue can come from:

- Cloud storage
- device synchronization
- hosted Galleries
- hosted Portfolio
- Commerce
- automatic delivery
- custom domains
- larger storage
- client-selection tools
- teams
- agency functionality
- school/sports systems

---

# 37. Example subscription structure

Exact prices are NOT final.

The concept may resemble:

## NTO Free

```text
R0

NTO Studio
NTO Mobile
Local editing
Local library
Local export
Presets
```

---

## NTO Cloud

Conceptually:

```text
around R99/month

100 GB Cloud
Mac ↔ phone sync
basic Gallery hosting
portfolio hosting
backup/sync
```

---

## NTO Pro

Conceptually:

```text
around R199–R299/month

1 TB storage
more/unlimited Galleries
Commerce
automatic delivery
custom domain
client favourites
sales dashboard
advanced portfolio controls
```

---

## NTO Business

Conceptually:

```text
R499+/month
```

Potentially:

- team accounts
- multiple photographers
- assistants
- permissions
- more storage
- advanced analytics
- branded client portals
- multiple storefronts

Pricing must eventually be based on real costs and customer research.

---

# 38. Commerce revenue

NTO could also earn transaction revenue.

Potential models:

## Subscription only

NTO Pro subscription includes Commerce.

NTO takes no additional platform fee beyond payment-provider processing.

---

## Platform fee

Example concept:

```text
Free Commerce user
→ higher NTO transaction percentage

Pro user
→ lower percentage

Business user
→ zero or very low NTO platform fee
```

Example only:

```text
Free         8%
Pro          2%
Business     0%
```

These figures are placeholders, not commitments.

---

# 39. Storage revenue

Photographers produce large quantities of data.

Potential storage tiers:

```text
100 GB
500 GB
1 TB
2 TB
5 TB
```

Cloud storage creates recurring revenue while providing a genuinely useful service.

---

# 40. Future revenue sources

Potential later revenue:

- prints
- print-lab fulfillment
- marketplace
- presets
- Gallery themes
- plugins
- professional support
- optional hosted AI processing
- school accounts
- sports organization accounts
- agency/team accounts

Do not build these before core product-market fit.

---

# 41. NTO for sports/schools

A possible later product:

```text
NTO SPORTS
```

Example school system:

```text
AFFIES PHOTOGRAPHY

Rugby
Hockey
Cricket
Athletics
Culture
Events
```

Approved photographers publish.

Parents browse.

Parents buy.

Photographers earn.

School may optionally receive revenue share.

NTO handles:

- hosting
- payment
- asset delivery
- user experience

This is future scope.

---

# 42. Cross-platform goal

NTO begins Apple-first but should not architect itself into an Apple-only dead end.

Potential long-term platforms:

```text
macOS
iPhone
iPad
Windows
Android
Linux
Web
```

Not all need to exist early.

---

# 43. Swift strategy

Swift can remain an important language for NTO.

The shared Swift architecture should avoid unnecessary platform-specific dependencies.

Potential shared Swift packages:

```text
NTOCore
NTOCatalogKit
NTOMetadataKit
NTOEditRecipe
NTOPresetKit
NTOSyncKit
NTOCloudClient
```

These should ideally compile wherever Swift supports the required functionality.

---

# 44. Shared Swift rules

Platform-independent packages should generally avoid imports such as:

```swift
import SwiftUI
import AppKit
import UIKit
import CoreImage
import Metal
```

unless the package is specifically Apple-only.

Prefer:

```swift
import Foundation
```

and abstract platform-specific systems.

---

# 45. Apple application architecture

Apple applications:

```text
macOS
iOS
iPadOS
```

can use:

- Swift
- SwiftUI
- Metal
- ImageIO
- Apple RAW technologies
- Apple-native APIs

Example:

```text
NTO Studio
SwiftUI
↓
NTO Core
↓
NTO Render Graph
↓
Metal
```

---

# 46. Windows strategy

Swift officially supports Windows.

NTO may reuse shared Swift packages on Windows.

The Windows UI does NOT need to be SwiftUI.

SwiftUI is an Apple framework.

Possible architecture:

```text
WINDOWS NTO

Native Windows UI
      ↓
Shared NTO Core
      ↓
Vulkan Renderer
```

UI technology can be chosen later based on maintainability and Windows integration.

---

# 47. Android strategy

Android is future scope.

Potential architecture:

```text
ANDROID NTO

Native Android UI
       ↓
NTO-compatible Core/API
       ↓
Vulkan
```

Mobile product philosophy should remain similar:

- Cull
- Quick Edit
- Publish
- Manage
- Sales

rather than blindly copying desktop Studio.

---

# 48. Graphics strategy

Current long-term preference:

```text
APPLE
→ Metal

WINDOWS
→ Vulkan

ANDROID
→ Vulkan

LINUX
→ Vulkan
```

This creates only two major GPU backends:

- Metal
- Vulkan

rather than:

- Metal
- DirectX
- Vulkan

---

# 49. Why Metal on Apple?

Metal is native to Apple platforms.

Benefits:

- direct Apple GPU integration
- strong Apple tooling
- Apple Silicon optimization
- no Vulkan translation layer
- native access to Apple graphics/compute capabilities

NTO is intended to feel first-class on Apple devices.

Therefore:

```text
Apple
→ Metal
```

is preferable to forcing Vulkan through a compatibility layer.

---

# 50. Why Vulkan elsewhere?

Vulkan provides a cross-platform low-level graphics/compute API.

Using it for:

```text
Windows
Android
Linux
```

allows NTO to share a major portion of its non-Apple rendering architecture.

This supports the open-source accessibility goal.

---

# 51. Render architecture

NTO should have a platform-independent Render Graph.

Conceptually:

```text
RAW
 ↓
Decode
 ↓
White Balance
 ↓
Exposure
 ↓
Highlights / Shadows
 ↓
Tone
 ↓
Colour
 ↓
Detail
 ↓
Geometry
 ↓
Output
```

Each stage should describe photographic behaviour rather than a specific GPU API.

Example:

```text
ExposureNode(+0.35 EV)
```

Apple:

```text
ExposureNode
↓
Metal implementation
```

Windows/Android/Linux:

```text
ExposureNode
↓
Vulkan implementation
```

---

# 52. Renderer abstraction

Conceptually:

```swift
protocol NTORenderBackend {
    func render(
        asset: Asset,
        recipe: EditRecipe
    ) async throws -> RenderedImage
}
```

Potential implementations:

```text
MetalRenderBackend
VulkanRenderBackend
```

The rest of NTO should not care which backend is active.

---

# 53. Rendering consistency

The same photograph and same EditRecipe should look essentially identical across platforms.

Example:

```text
IMG_4821.CR3

Exposure      +0.35
Highlights    -0.20
Temperature   5300
Vibrance      +0.08
```

Mac:

```text
Metal
```

Windows:

```text
Vulkan
```

Outputs should remain within defined tolerance.

Automated image-quality regression testing will eventually be important.

Potential tests:

- pixel difference
- colour difference
- histogram comparison
- reference renders
- performance benchmarks

---

# 54. Shader architecture

Metal and Vulkan use different shader ecosystems.

NTO should avoid duplicating conceptual algorithms even if backend shader code differs.

Example shared definition:

```text
Exposure:
output = input × 2^EV
```

Then:

```text
Metal implementation
```

and:

```text
Vulkan implementation
```

should implement the same photographic behaviour.

---

# 55. RAW architecture

Do not make the NTO data model dependent on one OS's RAW decoder.

Define something conceptually like:

```swift
protocol RAWDecoder {
    func decode(_ asset: Asset) async throws -> RAWImage
}
```

Potential implementations:

```text
AppleRAWDecoder
CrossPlatformRAWDecoder
```

Initial Apple implementation may use Apple-native technology.

Cross-platform decoder can come later.

---

# 56. Project portability

A major long-term goal:

A project created on Mac should eventually be understandable on Windows.

Example:

```text
NTO Project

Asset ID
Original file reference
Rating
Pick state
Metadata
EditRecipe
Publication state
```

The project must not fundamentally depend on:

```text
Apple-only UI concepts
```

The renderer may differ.

The photographic intent should remain portable.

---

# 57. Platform UI strategy

Do NOT try to use one generic UI everywhere if that produces inferior experiences.

Prefer:

```text
macOS/iOS/iPadOS
→ SwiftUI

Windows
→ appropriate native Windows UI

Android
→ appropriate native Android UI
```

Shared:

```text
NTO identity
workflow
data
editing semantics
Cloud
```

Platform-specific:

```text
window behaviour
native controls
gestures
menus
system integrations
```

---

# 58. Open-source cross-platform philosophy

NTO's open-source identity should eventually allow developers on different platforms to contribute.

Examples:

```text
Mac developer
→ improves Metal renderer

Windows developer
→ improves Vulkan support

Linux developer
→ improves cross-platform RAW handling

Photographer
→ contributes presets

Designer
→ improves Gallery

Backend developer
→ improves self-hosting
```

The architecture should encourage these contributions.

---

# 59. Scaling strategy

Do not build infrastructure for millions of users before real users exist.

Scale through actual need.

Initial:

```text
one API
one managed database
object storage
CDN
worker
```

Later:

```text
API
↓
queue
├── rendition workers
├── ZIP workers
├── email workers
└── Commerce workers
```

Only introduce complexity when required.

---

# 60. Development stages

Recommended sequence:

## Stage 1

Private development.

Build reliable Studio foundation.

```text
Import
Library
Cull
Edit
Export
```

---

## Stage 2

Use NTO on real photography shoots.

Identify actual problems.

---

## Stage 3

Clean architecture.

Separate:

```text
Core
Catalog
Imaging
UI
Persistence
```

---

## Stage 4

Open-source NTO Studio v0.1.

---

## Stage 5

Build community.

Accept:

- bug reports
- smaller PRs
- documentation
- compatibility fixes
- performance improvements

Maintain tight product direction.

---

## Stage 6

NTO Cloud.

---

## Stage 7

NTO Gallery.

Use it for real shoots.

---

## Stage 8

NTO Commerce.

Start simple.

---

## Stage 9

NTO Mobile.

---

## Stage 10

Paid hosted plans.

---

## Stage 11

Windows.

Start with:

```text
NTO Core builds
↓
read project
↓
decode photograph
↓
render EditRecipe
↓
export
```

Then build full UI.

---

## Stage 12

Android/Linux if justified.

---

# 61. When not to build something

Codex should push back internally against premature complexity.

Do not implement because it sounds impressive.

Examples that should normally wait:

- generative AI
- advanced object removal
- huge marketplace
- distributed microservice architecture
- advanced team management
- complicated tax system
- printing network
- full Android editor
- full Windows UI
- AI jersey detection
- giant plugin ecosystem

unless explicitly requested.

---

# 62. AI strategy

AI is not NTO's identity.

AI may eventually assist:

- masking
- denoise
- search
- subject grouping
- player grouping
- jersey detection
- object removal

But NTO should remain useful without AI.

Avoid building the product around AI hype.

---

# 63. Community strategy

Open source does not mean design by committee.

Community can contribute.

NTO should still maintain:

- clear product direction
- design standards
- architecture standards
- review standards
- performance standards

Future maintainership could become modular:

```text
NTO Imaging maintainers
NTO Catalog maintainers
NTO Windows maintainers
NTO Gallery maintainers
```

---

# 64. What makes NTO attractive

NTO should ultimately be attractive because of the combination:

```text
Open source
+
Native performance
+
Local ownership
+
Simple workflow
+
Event/sports focus
+
Publish directly
+
Sell directly
+
Automatic delivery
+
Optional Cloud
+
Cross-platform potential
```

Not because it has 500 sliders.

---

# 65. NTO positioning

Avoid positioning only as:

> Free Lightroom.

Better:

> An open-source photography platform built around the entire photographer workflow.

Or:

> From camera to customer.

The strongest concept remains:

```text
SHOOT
↓
CULL
↓
EDIT
↓
PUBLISH
↓
SELL
↓
DELIVER
```

---

# 66. Proof-of-concept success

The current proof of concept is successful when:

```text
Open NTO
↓
Create Project
↓
Import real Canon photo
↓
See it in Library
↓
Cull
↓
Edit
↓
Close NTO
↓
Reopen
↓
Edit is still correct
↓
Export JPEG
```

It must also:

- preserve original file
- remain stable
- render correctly
- remain responsive

---

# 67. Instructions to Codex

When working on NTO:

1. Read this document.
2. Read the current product GDD.
3. Understand the current development stage.
4. Do not implement future scope without being asked.
5. Preserve originals.
6. Preserve non-destructive editing.
7. Keep SwiftUI separate from rendering logic.
8. Keep shared core packages as platform-independent as practical.
9. Avoid unnecessary Apple-only dependencies inside NTO Core.
10. Treat EditRecipe as platform-independent photographic intent.
11. Build rendering behind abstractions.
12. Current Apple rendering may use Metal/Core Image where appropriate.
13. Design future rendering so Metal and Vulkan backends are possible.
14. Do not prematurely implement Windows/Android.
15. Do not introduce DirectX merely because Windows exists unless architecture is explicitly reconsidered.
16. Current long-term GPU strategy is Metal on Apple and Vulkan on Windows/Android/Linux.
17. Keep Cloud optional.
18. Keep local editing functional without an account.
19. Do not add subscription checks to core local editing.
20. Never commit secrets.
21. Avoid unrelated refactoring during feature implementation.
22. Keep changes testable.
23. Add tests for important model/rendering behaviour.
24. Treat performance as a first-class requirement.
25. Use real photography workflows when deciding UX.
26. Prefer understandable architecture over clever architecture.
27. Avoid premature microservices.
28. Avoid premature AI.
29. Maintain backwards compatibility with stored projects where practical.
30. Ask whether a new feature belongs to current scope before building it.

---

# 68. Long-term architecture summary

```text
                         NTO
                          │
                  PLATFORM-INDEPENDENT
                          │
                ┌─────────┴─────────┐
                │                   │
             NTO Core         NTO EditRecipe
                │                   │
                └─────────┬─────────┘
                          │
                    Render Graph
                          │
                 ┌────────┴────────┐
                 │                 │
               Metal            Vulkan
                 │                 │
       ┌─────────┼──────┐       ┌──┼─────────┐
       │         │      │       │  │         │
     macOS     iPhone  iPad   Windows Android Linux
       │
       │
       └───────────────────┐
                           │
                     NTO Cloud
                           │
              ┌────────────┼─────────────┐
              │            │             │
           Gallery       Commerce      Portfolio
              │
              ↓
          CUSTOMER
```

---

# 69. Business architecture summary

```text
                 NTO OPEN SOURCE
                       FREE
                         │
            ┌────────────┴────────────┐
            │                         │
       NTO Studio                NTO Mobile
            │                         │
            └────────────┬────────────┘
                         │
                  OPTIONAL SERVICE
                         │
                     NTO CLOUD
                         │
        ┌────────────────┼────────────────┐
        │                │                │
       Sync           Gallery         Portfolio
                         │
                         ↓
                      Commerce
                         │
                ┌────────┴────────┐
                │                 │
          Subscription       Transaction
             revenue            revenue
```

---

# 70. Final project vision

NTO should eventually allow a photographer to do this:

```text
Photograph rugby match
        ↓
Import photographs
        ↓
Cull 2,000 photographs
        ↓
Edit final selection
        ↓
Sync edits
        ↓
Publish 150 photographs
        ↓
Gallery automatically goes live
        ↓
Share URL
        ↓
Parents/players browse
        ↓
Customer finds photograph
        ↓
Customer pays
        ↓
High-resolution file delivered
        ↓
Photographer sees sale on phone
```

All while:

- original files remain owned by photographer
- editing remains local-capable
- NTO Studio remains open source
- Cloud is optional
- hosted infrastructure can financially support development
- the ecosystem can eventually run across multiple platforms

The core idea is not:

> build a copy of Lightroom.

The core idea is:

> build an open-source photography platform that takes photographers from camera to customer.

That is the long-term NTO project direction.
