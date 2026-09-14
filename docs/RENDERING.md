# Studio rendering and recipe semantics

Phase 04 implements engine `nto-ci-v1` behind `PhotoRenderer`. It is an Apple backend for platform-independent recipe intent. No Cloud image worker or portable shader backend is included.

## Recipe v1

The existing v1 fields are retained. This milestone defines their first implemented semantics and adds matching range validation; it does not add fields or silently reinterpret an existing rendered release. Future incompatible meanings or pipeline changes require an explicit version/migration decision.

| Field | Meaning and range | Neutral |
| --- | --- | --- |
| exposure | EV, −5…5 | 0 |
| contrast | Signed offset −1…1; Core Image factor is `1 + contrast` | 0 |
| saturation | Multiplier 0…2 | 1 |
| temperature | 2,000…50,000 K, or null | null |
| tint | Offset −150…150 | 0 |
| sharpness | Additional luminance sharpening 0…2 | 0 |
| noiseReduction | 0…1 mapped to Core Image noise level 0…0.1, without extra sharpening | 0 |
| crop | Normalized top-left rectangle on the oriented original; positive size wholly within [0,1] | Full image |
| rotation | Clockwise degrees −180…180, applied after crop | 0 |
| highlights | −1…1; moves the three-quarter tone (0.75 in sRGB-encoded tone) by ±0.10 | 0 |
| shadows | −1…1; moves the quarter tone (0.25) by ±0.10 | 0 |
| whites | −1…1; positive pulls the white point in to 1 − 0.15·whites (clipping), negative lowers output white to 1 + 0.15·whites | 0 |
| blacks | −1…1; negative pulls the black point in to −0.15·blacks (clipping), positive lifts output black to 0.15·blacks | 0 |
| vibrance | −1…1; saturation weighted toward muted colours, applied before saturation | 0 |
| revision | Positive, monotonically increasing safe JSON integer | 1 |

The five tonal-range and vibrance fields were added in Phase 05 with a schema default of 0. They are not required in the JSON Schema, the TypeScript interface marks them optional, and the generated Swift decoder substitutes 0 when absent, so recipes and edit journals saved before Phase 05 decode unchanged and render identically. Encoders always write them.

RAW null temperature retains camera/as-shot white balance. Explicit temperature replaces its Kelvin value; tint offsets the decoder's as-shot tint, clamped to its supported range. Raster white balance corrects a supplied neutral relative to D65 (6500 K, zero tint); null preserves the existing appearance unless tint is adjusted. This is not RAW recovery from a JPEG.

Direction: `temperature` names the illuminant under which a neutral was captured, and the renderer corrects that neutral toward D65. A lower Kelvin therefore cools the image and a higher Kelvin warms it, the same convention as a conventional editor's temperature slider. The Edit controls (Phase 05) expose this directly; verified in `EditingTests`.

The pipeline is **decode → camera/RAW → tone → colour → detail → geometry → effects → output**. `CIRAWFilter` handles supported RAW; Core Image loads oriented non-RAW images and their source colour profiles. RAW uses full decode scale and non-draft mode, with lens correction disabled for the deferred optics workflow. Other decoder baseline processing remains camera/system dependent. Tone applies exposure, then contrast, then the tonal range as one five-point curve through (blacks point), (0.25, 0.25 + 0.10·shadows), the pinned midtone (0.5, 0.5), (0.75, 0.75 + 0.10·highlights) and (whites point); the curve is skipped when all four values are 0. The control points are expressed in sRGB-encoded tone, and the engine's tests confirm that a 0.25 grey moves to 0.35 under shadows +1 while 0.5 stays fixed. Colour applies raster white balance where needed, then vibrance, then saturation. Detail works at original resolution. Geometry crops then rotates into its bounding box; exposed rotation corners are black. Effects are identity in v1.

Working colour space is extended linear sRGB using half-float processing; output is opaque 8-bit SDR sRGB. Both preview and full output use the same photographic graph, followed by output resizing without upscaling. PNG and TIFF are lossless; JPEG quality is part of `RenderSpecification` (0.1…1, default 0.95; the export sheet offers 50–100%). Since Phase 07 the export workflow uses these outputs directly, copying the encoded bytes to disk without re-encoding when attaching metadata.

## Persistence and history

`LocalEditState` is an additive SwiftData model keyed by the stable asset UUID. Its Codable journal stores the current recipe, up to 100 undo operations, redo state and an in-progress gesture baseline. Every adjustment autosaves synchronously; completing a slider gesture adds one undo operation. Reopening an interrupted gesture finalizes the saved baseline into one operation. Undo/redo restore exact parameter values while assigning a new revision, avoiding cache identity reuse. A new edit clears redo.

Annotations and editing are asset-wide when the same original belongs to multiple projects. No original bytes or public filesystem payloads are changed. Unsupported or corrupt saved recipes are reported and retained. Save failures keep unsaved state in memory and prevent the editor from replacing it with another photo until saving succeeds.

## Scheduling, caching and limits

`CoreImageRenderer` is an actor owning its `CIContext` and a 64 MiB LRU cache of encoded results. Keys include asset/recipe contents and revision, original fingerprint, output specification, engine identifier and operating-system version. Original readability and fingerprint are checked before cache use; the fingerprint is checked again before returning a fresh render. Bookmarked access remains scoped throughout decoding.

Interactive preview requests debounce for 120 ms and cancel/supersede prior requests. A request identity check prevents even a cancellation-insensitive backend from installing stale output. GPU/decoder work already in progress may finish before cancellation is observed. UI decoding of the produced preview is also off the main thread. The previous edited preview remains visible with an updating indicator while a new render is pending.

Originals are limited to 120 megapixels; maximum output dimension is 30,000 pixels. Preview size is currently 2,000 pixels. Full-resolution photographic processing favours consistent semantics over draft RAW speed; it is not a guarantee of interactive performance on every camera or machine. Raw decoder versions and baseline processing can change across OS updates. Cross-platform/OS pixel identity, HDR, wide-gamut export, colour-critical print qualification and a persistent render disk cache are not claimed.

## Primary API references

- [Apple: CIRAWFilter image URL initializer](https://developer.apple.com/documentation/coreimage/cirawfilter/init(imageurl:))
- [Apple: Core Image working colour space](https://developer.apple.com/documentation/coreimage/cicontext/workingcolorspace)

See [Phase 04 verification](PHASE-04-VERIFICATION.md) for actual checks and remaining qualification.
