import test from "node:test";
import assert from "node:assert/strict";
import Ajv from "ajv";
import addFormats from "ajv-formats";
import schema from "../schema.json";
import fixture from "../fixtures/ecosystem.json";
import { assertRecipeVersion, type EcosystemFixture } from "../src/index";
const ajv = new Ajv();
addFormats(ajv);
const validate = ajv.compile(schema);
test("canonical fixture validates and round-trips", () => {
  assert.equal(validate(fixture), true, JSON.stringify(validate.errors));
  const typed = fixture as EcosystemFixture;
  assert.deepEqual(JSON.parse(JSON.stringify(typed)), fixture);
});
test("rejects unsupported contract and recipe versions", () => {
  const value = structuredClone(fixture);
  value.recipes[0].schemaVersion = 2;
  assert.equal(validate(value), false);
  assert.throws(() => assertRecipeVersion({ schemaVersion: 2 }), /Unsupported/);
  value.contractVersion = 2;
  assert.equal(validate(value), false);
});
test("rejects local filesystem paths and unknown fields", () => {
  const value = structuredClone(fixture);
  Object.assign(value.assets[0], {
    originalObjectKey: "file:///Users/private/photo.raw",
  });
  assert.equal(validate(value), false);
  Object.assign(value.assets[0], {
    originalObjectKey: null,
    localPath: "/private",
  });
  assert.equal(validate(value), false);
});

test("render recipes have matching bounded semantics and normalized crops", async () => {
  const { validateRecipe } = await import("../src/index");
  for (const recipe of fixture.recipes)
    validateRecipe(recipe as EcosystemFixture["recipes"][number]);
  const recipe = structuredClone(
    fixture.recipes[1],
  ) as EcosystemFixture["recipes"][number];
  recipe.crop.x = 0.9;
  assert.throws(() => validateRecipe(recipe), /crop/);
  recipe.crop.x = 0.1;
  recipe.exposure = NaN;
  assert.throws(() => validateRecipe(recipe), /exposure/);
  recipe.exposure = 6;
  assert.throws(() => validateRecipe(recipe), /exposure/);
  const invalid = structuredClone(fixture);
  invalid.recipes[0].exposure = 6;
  assert.equal(validate(invalid), false);
});
