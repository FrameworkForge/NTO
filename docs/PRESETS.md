# Preset format and edit synchronisation

Presets are user-owned files. Each one is a JSON document in the library's `Presets` folder (by default `~/Library/Application Support/NTO/Studio/Presets/<uuid>.json`). They can be exported, imported and shared as plain files; Studio never needs an account or Cloud for them.

## Format version 1

```json
{
  "formatVersion": 1,
  "id": "9F0C0A2E-6C7B-4E5B-9E2A-3B1C2D4E5F60",
  "name": "Evening warmth",
  "adjustments": {
    "exposure": 0.3,
    "highlights": -0.2,
    "vibrance": 0.25,
    "temperature": null
  }
}
```

- `formatVersion` is required and must be `1`. Studio refuses other versions rather than guessing.
- `id` is a UUID. Importing a file whose id already exists in the library keeps both presets by assigning a fresh id to the import.
- `name` is a non-empty display name.
- `adjustments` holds **only the parameters the preset carries**. Parameters that are absent are untouched when the preset is applied. At least one is required.

### Parameter keys and values

| Key | Value | Range | Group |
| --- | --- | --- | --- |
| `exposure` | number (EV) | −5…5 | Light |
| `contrast`, `highlights`, `shadows`, `whites`, `blacks` | number | −1…1 | Light |
| `temperature` | number in Kelvin, or `null` for as shot | 2,000…50,000 | Colour |
| `tint` | number | −150…150 | Colour |
| `vibrance` | number | −1…1 | Colour |
| `saturation` | number | 0…2 | Colour |
| `sharpness` | number | 0…2 | Detail |
| `noiseReduction` | number | 0…1 | Detail |
| `crop` | object `{ "x", "y", "width", "height" }` in normalized fractions | inside the unit square, positive size | Geometry |
| `rotation` | number in clockwise degrees | −180…180 | Geometry |

Meanings and ranges are those of recipe v1 in [RENDERING.md](RENDERING.md). Values are validated when applied; an out-of-range value is refused with a message and the photograph's recipe is left unchanged. A value of the wrong kind (for example a number for `crop`) is also refused.

## Applying, copying and syncing

Presets, **Copy edits** and **Sync to selected** all move the same thing: a chosen subset of recipe parameters. Applying a subset to a photograph changes only those parameters and records **one undo step** for that photograph, whether it came from a preset click, Paste, or a sync. Deleting a preset removes its file only; photographs that used it keep their recipes.

By default a new preset or copy includes every Light, Colour and Detail parameter **except white balance** (`temperature`, `tint`) and excludes **geometry** (`crop`, `rotation`). Those belong to one photograph; include them deliberately when a whole series shares them.

Hovering a preset renders the current photograph with it applied as a preview; the recipe does not change until it is clicked.

### Sync behaviour

- Sync applies the copied subset to every selected photograph. The photograph open in Edit is updated through the editor so its on-screen history stays authoritative; the rest are updated in the background in yielding batches, with progress and a Stop button. Stopping keeps the photographs already updated.
- Photographs whose values already match are left without a new history entry.
- **Revert sync** undoes the last sync on every photograph still at the revision the sync produced. A photograph edited after the sync is skipped and reported, so later work is never discarded. Revert covers only the most recent sync.
- Each photograph's own Undo still works independently of the batch.
