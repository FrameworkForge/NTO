import test from "node:test";
import assert from "node:assert/strict";
import { health } from "../supabase/functions/health/handler";
import { projectClient } from "../src/projects";
test("health returns version without secrets and rejects writes", async () => {
  assert.deepEqual(
    await health(new Request("http://localhost/health")).json(),
    { service: "nto-cloud", status: "ok", contractVersion: 1 },
  );
  const rejected = health(
    new Request("http://localhost/health", { method: "POST" }),
  );
  assert.equal(rejected.status, 405);
  assert.equal((await rejected.json()).error.retryable, false);
});
test("project adapter rejects empty names before network calls", async () => {
  await assert.rejects(
    () =>
      projectClient("http://127.0.0.1:1", "public-key").create(
        "  ",
        "owner",
        "token",
      ),
    /title is required/,
  );
});
