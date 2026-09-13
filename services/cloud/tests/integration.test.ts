import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import { projectClient } from "../src/projects";

test("local Auth, project API, ownership, immutable originals, and private storage", async () => {
  let config: Record<string, string>;
  try {
    config = JSON.parse(
      execFileSync("pnpm", ["exec", "supabase", "status", "--output", "json"], {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "pipe"],
      }),
    );
  } catch {
    throw new Error(
      "Local Supabase is unavailable. Start the container runtime, then run pnpm cloud:start and pnpm cloud:reset.",
    );
  }
  const url = config.API_URL;
  const key = config.ANON_KEY;
  const admin = config.SERVICE_ROLE_KEY;
  assert.ok(
    ["localhost", "127.0.0.1"].includes(new URL(url).hostname),
    "Integration tests are restricted to local Supabase",
  );
  const adminHeaders = {
    apikey: key,
    Authorization: `Bearer ${admin}`,
    "Content-Type": "application/json",
  };
  const ids: string[] = [];
  let objectPath: string | undefined;
  async function user() {
    const email = `nto-${randomUUID()}@example.test`;
    const password = randomUUID() + "Aa1!";
    const response = await fetch(`${url}/auth/v1/admin/users`, {
      method: "POST",
      headers: adminHeaders,
      body: JSON.stringify({ email, password, email_confirm: true }),
    });
    assert.equal(response.status, 200);
    const created = await response.json();
    ids.push(created.id);
    const sessionResponse = await fetch(
      `${url}/auth/v1/token?grant_type=password`,
      {
        method: "POST",
        headers: { apikey: key, "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
      },
    );
    assert.equal(sessionResponse.status, 200);
    const session = await sessionResponse.json();
    return { id: created.id as string, token: session.access_token as string };
  }
  const auth = (token: string) => ({
    apikey: key,
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
    Prefer: "return=representation",
  });
  try {
    const a = await user(),
      b = await user();
    const client = projectClient(url, key);
    const p = await client.create("Integration project", a.id, a.token);
    assert.equal(p.ownerId, a.id);
    assert.equal((await client.list(a.token))[0].id, p.id);
    assert.deepEqual(await client.list(b.token), []);
    await assert.rejects(() => client.create("Forged owner", a.id, b.token));
    const forgedUpdate = await fetch(`${url}/rest/v1/projects?id=eq.${p.id}`, {
      method: "PATCH",
      headers: auth(b.token),
      body: JSON.stringify({ title: "Hijacked" }),
    });
    assert.equal(forgedUpdate.status, 200);
    assert.deepEqual(await forgedUpdate.json(), []);
    assert.equal((await client.list(a.token))[0].title, "Integration project");
    const anonymous = await fetch(`${url}/rest/v1/projects`, {
      headers: { apikey: key },
    });
    assert.ok(anonymous.status >= 400);
    objectPath = `${a.id}/${randomUUID()}/source.txt`;
    const upload = await fetch(
      `${url}/storage/v1/object/originals/${objectPath}`,
      {
        method: "POST",
        headers: { ...auth(a.token), "Content-Type": "text/plain" },
        body: "NTO test fixture",
      },
    );
    assert.ok(upload.ok, `upload status ${upload.status}`);
    const guessed = await fetch(
      `${url}/storage/v1/object/public/originals/${objectPath}`,
    );
    assert.ok(!guessed.ok);
    const other = await fetch(
      `${url}/storage/v1/object/authenticated/originals/${objectPath}`,
      { headers: auth(b.token) },
    );
    assert.ok(!other.ok);
    const signed = await fetch(
      `${url}/storage/v1/object/sign/originals/${objectPath}`,
      {
        method: "POST",
        headers: auth(a.token),
        body: JSON.stringify({ expiresIn: 60 }),
      },
    );
    assert.ok(signed.ok);
    const signature = await signed.json();
    const download = await fetch(`${url}/storage/v1${signature.signedURL}`);
    assert.equal(await download.text(), "NTO test fixture");
    const assetResponse = await fetch(`${url}/rest/v1/assets`, {
      method: "POST",
      headers: auth(a.token),
      body: JSON.stringify({
        owner_id: a.id,
        filename: "source.txt",
        media_type: "text/plain",
        original_object_key: objectPath,
        width: 1,
        height: 1,
      }),
    });
    assert.equal(assetResponse.status, 201);
    const [asset] = await assetResponse.json();
    const replace = await fetch(`${url}/rest/v1/assets?id=eq.${asset.id}`, {
      method: "PATCH",
      headers: auth(a.token),
      body: JSON.stringify({ original_object_key: `${a.id}/replacement.txt` }),
    });
    assert.ok(!replace.ok);
    const bProject = await client.create("Other owner", b.id, b.token);
    const crossLink = await fetch(`${url}/rest/v1/project_assets`, {
      method: "POST",
      headers: auth(a.token),
      body: JSON.stringify({
        owner_id: a.id,
        asset_id: asset.id,
        project_id: bProject.id,
      }),
    });
    assert.ok(!crossLink.ok);
  } finally {
    if (objectPath)
      await fetch(`${url}/storage/v1/object/originals`, {
        method: "DELETE",
        headers: adminHeaders,
        body: JSON.stringify({ prefixes: [objectPath] }),
      });
    for (const id of ids)
      await fetch(`${url}/auth/v1/admin/users/${id}`, {
        method: "DELETE",
        headers: adminHeaders,
      });
  }
});
