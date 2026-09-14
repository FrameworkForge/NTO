export const CONTRACT_VERSION = 1 as const;
export type UUID = string;
export interface Project {
  id: UUID;
  ownerId: UUID;
  title: string;
  createdAt: string;
}
export interface Asset {
  id: UUID;
  ownerId: UUID;
  filename: string;
  mediaType: string;
  originalObjectKey: string | null;
  width: number;
  height: number;
  rating: number;
  flag: "none" | "pick" | "reject";
  favourite: boolean;
}
export interface Collection {
  id: UUID;
  projectId: UUID;
  title: string;
  assetIds: UUID[];
}
export interface EditRecipe {
  schemaVersion: 1;
  assetId: UUID;
  revision: number;
  exposure: number;
  contrast: number;
  saturation: number;
  temperature: number | null;
  tint: number;
  sharpness: number;
  noiseReduction: number;
  crop: { x: number; y: number; width: number; height: number };
  rotation: number;
  /** Tonal range and vibrance (−1…1) were added in Phase 05 with a schema default of 0; absent means neutral in recipes saved earlier. */
  highlights?: number;
  shadows?: number;
  whites?: number;
  blacks?: number;
  vibrance?: number;
}
export interface Rendition {
  id: UUID;
  assetId: UUID;
  recipeRevision: number;
  kind: "thumbnail" | "preview" | "web" | "master" | "export";
  objectKey: string;
  width: number;
  height: number;
  contentKey: string;
}
export interface Publication {
  id: UUID;
  ownerId: UUID;
  projectId: UUID;
  destination: "gallery" | "portfolio";
  title: string;
  slug: string;
  status: "draft" | "published";
  visibility: "public" | "unlisted" | "password";
  downloads: "none" | "web" | "master";
  assetIds: UUID[];
  coverAssetId: UUID | null;
  revision: number;
}
export interface EcosystemFixture {
  contractVersion: 1;
  projects: Project[];
  assets: Asset[];
  collections: Collection[];
  recipes: EditRecipe[];
  renditions: Rendition[];
  publications: Publication[];
}
export interface RenditionJob {
  id: UUID;
  assetId: UUID;
  sourceObjectKey: string;
  recipeRevision: number;
  target: {
    kind: Rendition["kind"];
    maxDimension: number;
    format: "jpeg" | "webp" | "tiff";
  };
}
export type RenditionJobResult =
  | { jobId: UUID; status: "completed"; rendition: Rendition }
  | { jobId: UUID; status: "failed"; error: CloudError };
export interface CloudError {
  code: string;
  message: string;
  retryable: boolean;
}
export function assertRecipeVersion(value: { schemaVersion: number }): void {
  if (value.schemaVersion !== 1)
    throw new Error(`Unsupported recipe version: ${value.schemaVersion}`);
}

/** Renderer v1 parameter semantics; schema validation separately enforces the payload shape. */
export function validateRecipe(recipe: EditRecipe): void {
  assertRecipeVersion(recipe);
  const ranges = {
    exposure: [-5, 5],
    contrast: [-1, 1],
    saturation: [0, 2],
    tint: [-150, 150],
    sharpness: [0, 2],
    noiseReduction: [0, 1],
    rotation: [-180, 180],
    highlights: [-1, 1],
    shadows: [-1, 1],
    whites: [-1, 1],
    blacks: [-1, 1],
    vibrance: [-1, 1],
  } as const;
  if (!Number.isSafeInteger(recipe.revision) || recipe.revision < 1)
    throw new Error("Invalid recipe revision");
  for (const key of Object.keys(ranges) as (keyof typeof ranges)[]) {
    const [min, max] = ranges[key];
    const value = recipe[key] ?? 0;
    if (!Number.isFinite(value) || value < min || value > max)
      throw new Error(`Invalid recipe ${key}`);
  }
  if (
    recipe.temperature !== null &&
    (!Number.isFinite(recipe.temperature) ||
      recipe.temperature < 2000 ||
      recipe.temperature > 50000)
  )
    throw new Error("Invalid recipe temperature");
  const { x, y, width, height } = recipe.crop;
  if (
    ![x, y, width, height].every(
      (v) => Number.isFinite(v) && v >= 0 && v <= 1,
    ) ||
    width <= 0 ||
    height <= 0 ||
    x + width > 1 ||
    y + height > 1
  )
    throw new Error("Invalid recipe crop");
}
