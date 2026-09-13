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
