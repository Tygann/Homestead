import assert from "node:assert/strict";
import test from "node:test";

import worker, { type Env } from "./index.ts";

const API_HOST = "api.homesteadcontrol.com";
const CONNECT_HOST = "connect.homesteadcontrol.com";
const SITE_HOST = "homesteadcontrol.com";

const env = {
  HOMESTEAD_PUSH_TOKENS: undefined as never,
  APNS_KEY_ID: "test-key-id",
  APNS_TEAM_ID: "test-team-id",
  APNS_BUNDLE_ID: "com.tyler.Homestead",
  APNS_PRIVATE_KEY: "test-private-key",
  HOMESTEAD_PUSH_ADMIN_TOKEN: "test-admin-token"
} satisfies Env;

function request(host: string, path: string, init?: RequestInit): Request {
  return new Request(`https://${host}${path}`, init);
}

async function json(response: Response): Promise<Record<string, unknown>> {
  const value = await response.json();
  assert.equal(typeof value, "object");
  assert.notEqual(value, null);
  assert.equal(Array.isArray(value), false);
  return value as Record<string, unknown>;
}

test("GET /health still works on the API host", async () => {
  const response = await worker.fetch(request(API_HOST, "/health"), env);
  const body = await json(response);

  assert.equal(response.status, 200);
  assert.equal(body.ok, true);
  assert.equal(body.service, "homestead-api");
});

test("GET / on the connect host returns the connect HTML", async () => {
  const response = await worker.fetch(request(CONNECT_HOST, "/"), env);
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("content-type"), "text/html; charset=utf-8");
  assert.match(body, /<title>Homestead<\/title>/);
  assert.match(body, /<h1>Homestead<\/h1>/);
  assert.match(body, /A native Home Assistant client for iPhone\./);
  assert.match(body, /Open Homestead on your iPhone to continue setup\./);
});

test("connect HTML includes the Home Assistant redirect_uri metadata", async () => {
  const response = await worker.fetch(request(CONNECT_HOST, "/"), env);
  const body = await response.text();

  assert.match(body, /<link rel="redirect_uri" href="homestead:\/\/auth" \/>/);
});

test("push endpoints still route on the API host", async () => {
  const init: RequestInit = {
    method: "POST",
    body: "not-json",
    headers: {
      "content-type": "application/json"
    }
  };

  const registerResponse = await worker.fetch(
    request(API_HOST, "/mobile-app/register-push-token", init),
    env
  );
  const pushResponse = await worker.fetch(request(API_HOST, "/mobile-app/push", init), env);

  assert.equal(registerResponse.status, 400);
  assert.equal((await json(registerResponse)).error, "invalid_json");
  assert.equal(pushResponse.status, 400);
  assert.equal((await json(pushResponse)).error, "invalid_json");
});

test("connect host does not expose admin or push API routes", async () => {
  const init: RequestInit = {
    method: "POST",
    body: "{}",
    headers: {
      "authorization": "Bearer test-admin-token",
      "content-type": "application/json"
    }
  };

  const adminResponse = await worker.fetch(request(CONNECT_HOST, "/admin/test-push", init), env);
  const pushResponse = await worker.fetch(request(CONNECT_HOST, "/mobile-app/push", init), env);

  assert.equal(adminResponse.status, 404);
  assert.equal(await adminResponse.text(), "Not found.");
  assert.equal(pushResponse.status, 404);
  assert.equal(await pushResponse.text(), "Not found.");
});

test("unknown connect paths return a clean 404", async () => {
  const response = await worker.fetch(request(CONNECT_HOST, "/anything-else"), env);

  assert.equal(response.status, 404);
  assert.equal(response.headers.get("content-type"), "text/plain; charset=utf-8");
  assert.equal(await response.text(), "Not found.");
});

test("public site serves marketing, support, and privacy pages", async () => {
  const homeResponse = await worker.fetch(request(SITE_HOST, "/"), env);
  const supportResponse = await worker.fetch(request(SITE_HOST, "/support"), env);
  const privacyResponse = await worker.fetch(request(SITE_HOST, "/privacy"), env);

  assert.equal(homeResponse.status, 200);
  assert.match(await homeResponse.text(), /Your home, beautifully organized\./);
  assert.match(await supportResponse.text(), /support@homesteadcontrol\.com/);
  assert.match(await privacyResponse.text(), /Homestead does not sell personal information/);
  assert.equal(privacyResponse.headers.get("x-content-type-options"), "nosniff");
});

test("public site supports App Store link checks and rejects API routes", async () => {
  const headResponse = await worker.fetch(request(SITE_HOST, "/support", { method: "HEAD" }), env);
  const apiResponse = await worker.fetch(
    request(SITE_HOST, "/mobile-app/push", { method: "POST", body: "{}" }),
    env
  );

  assert.equal(headResponse.status, 200);
  assert.equal(await headResponse.text(), "");
  assert.equal(apiResponse.status, 404);
  assert.equal(await apiResponse.text(), "Not found.");
});
