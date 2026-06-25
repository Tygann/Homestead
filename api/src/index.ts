type PushEnvironment = "sandbox" | "production";

interface Env {
  HOMESTEAD_PUSH_TOKENS: KVNamespace;
  APNS_KEY_ID: string;
  APNS_TEAM_ID: string;
  APNS_BUNDLE_ID: string;
  APNS_PRIVATE_KEY: string;
  HOMESTEAD_PUSH_ADMIN_TOKEN?: string;
}

interface PushTokenRecord {
  apnsToken: string;
  environment: PushEnvironment;
  deviceName: string;
  appVersion: string;
  updatedAt: string;
}

interface APNSJWTCache {
  jwt: string;
  issuedAt: number;
  keyID: string;
  teamID: string;
}

type JSONPrimitive = string | number | boolean | null;
type JSONValue = JSONPrimitive | JSONValue[] | { [key: string]: JSONValue };
type JSONObject = { [key: string]: JSONValue };

const SERVICE_NAME = "homestead-api";
const MAX_JSON_BYTES = 64 * 1024;
const APNS_JWT_MAX_AGE_SECONDS = 50 * 60;

let cachedAPNSJWT: APNSJWTCache | undefined;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      const url = new URL(request.url);

      if (request.method === "GET" && url.pathname === "/health") {
        return jsonResponse({ ok: true, service: SERVICE_NAME });
      }

      if (request.method === "POST" && url.pathname === "/mobile-app/register-push-token") {
        return await registerPushToken(request, env);
      }

      if (request.method === "POST" && url.pathname === "/mobile-app/push") {
        return await relayHomeAssistantPush(request, env);
      }

      if (request.method === "POST" && url.pathname === "/admin/test-push") {
        return await sendAdminTestPush(request, env);
      }

      return errorResponse(404, "not_found", "Endpoint not found.");
    } catch (error) {
      console.error("Unhandled Worker error", safeError(error));
      return errorResponse(500, "internal_error", "The request could not be completed.");
    }
  }
};

// MARK: - Routes

async function registerPushToken(request: Request, env: Env): Promise<Response> {
  const payload = await readJSONObject(request);
  if (!payload.ok) {
    return payload.response;
  }

  const pushRelayToken = requiredString(payload.value, "pushRelayToken");
  const apnsToken = requiredString(payload.value, "apnsToken");
  const environment = requiredString(payload.value, "environment");
  const deviceName = requiredString(payload.value, "deviceName");
  const appVersion = requiredString(payload.value, "appVersion");

  if (!pushRelayToken || !isUsableToken(pushRelayToken, 16, 512)) {
    return errorResponse(400, "invalid_push_relay_token", "A valid pushRelayToken is required.");
  }

  if (!apnsToken || !isUsableToken(apnsToken, 16, 512)) {
    return errorResponse(400, "invalid_apns_token", "A valid apnsToken is required.");
  }

  if (!isPushEnvironment(environment)) {
    return errorResponse(400, "invalid_environment", "environment must be sandbox or production.");
  }

  if (!deviceName || !appVersion) {
    return errorResponse(400, "invalid_device_metadata", "deviceName and appVersion are required.");
  }

  const record: PushTokenRecord = {
    apnsToken,
    environment,
    deviceName,
    appVersion,
    updatedAt: new Date().toISOString()
  };

  await env.HOMESTEAD_PUSH_TOKENS.put(pushRelayToken, JSON.stringify(record));
  return jsonResponse({ ok: true, registered: true, environment }, 201);
}

async function relayHomeAssistantPush(request: Request, env: Env): Promise<Response> {
  const payload = await readJSONObject(request);
  if (!payload.ok) {
    return payload.response;
  }

  const pushRelayToken = requiredString(payload.value, "push_token");
  const message = requiredString(payload.value, "message");
  const title = optionalString(payload.value, "title");

  if (!pushRelayToken || !isUsableToken(pushRelayToken, 16, 512)) {
    return errorResponse(400, "invalid_push_token", "A valid push_token is required.");
  }

  if (!message) {
    return errorResponse(400, "invalid_message", "A notification message is required.");
  }

  const record = await readPushTokenRecord(env, pushRelayToken);
  if (!record) {
    return errorResponse(404, "push_token_not_found", "No registered device was found for this push token.");
  }

  const apnsPayload = makeAPNSPayload({
    title,
    message,
    data: objectValue(payload.value.data)
  });

  const result = await sendAPNSNotification(env, record, apnsPayload);
  if (!result.ok) {
    return apnsErrorResponse(result);
  }

  return jsonResponse({ ok: true, accepted: true }, 201);
}

async function sendAdminTestPush(request: Request, env: Env): Promise<Response> {
  if (!(await isAuthorizedAdminRequest(request, env))) {
    return errorResponse(401, "unauthorized", "Authorization is required.");
  }

  const payload = await readJSONObject(request);
  if (!payload.ok) {
    return payload.response;
  }

  const pushRelayToken = requiredString(payload.value, "pushRelayToken");
  const message = requiredString(payload.value, "message") ?? "Homestead test notification";
  const title = optionalString(payload.value, "title") ?? "Homestead";

  if (!pushRelayToken || !isUsableToken(pushRelayToken, 16, 512)) {
    return errorResponse(400, "invalid_push_relay_token", "A valid pushRelayToken is required.");
  }

  const record = await readPushTokenRecord(env, pushRelayToken);
  if (!record) {
    return errorResponse(404, "push_token_not_found", "No registered device was found for this relay token.");
  }

  const apnsPayload = makeAPNSPayload({
    title,
    message,
    data: objectValue(payload.value.data)
  });

  const result = await sendAPNSNotification(env, record, apnsPayload);
  if (!result.ok) {
    return apnsErrorResponse(result);
  }

  return jsonResponse({ ok: true, accepted: true }, 201);
}

// MARK: - APNs

async function sendAPNSNotification(
  env: Env,
  record: PushTokenRecord,
  payload: JSONObject
): Promise<{ ok: true } | { ok: false; status: number; reason?: string }> {
  const jwt = await apnsJWT(env);
  const host = record.environment === "sandbox"
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";
  const response = await fetch(`https://${host}/3/device/${encodeURIComponent(record.apnsToken)}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": env.APNS_BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json"
    },
    body: JSON.stringify(payload)
  });

  if (response.ok) {
    return { ok: true };
  }

  const responseBody = await safeAPNSErrorBody(response);
  console.warn("APNs rejected Homestead notification", {
    status: response.status,
    reason: responseBody.reason
  });
  return { ok: false, status: response.status, reason: responseBody.reason };
}

async function apnsJWT(env: Env): Promise<string> {
  const issuedAt = Math.floor(Date.now() / 1000);
  if (
    cachedAPNSJWT &&
    cachedAPNSJWT.keyID === env.APNS_KEY_ID &&
    cachedAPNSJWT.teamID === env.APNS_TEAM_ID &&
    issuedAt - cachedAPNSJWT.issuedAt < APNS_JWT_MAX_AGE_SECONDS
  ) {
    return cachedAPNSJWT.jwt;
  }

  const header = base64URLString(JSON.stringify({ alg: "ES256", kid: env.APNS_KEY_ID }));
  const claims = base64URLString(JSON.stringify({ iss: env.APNS_TEAM_ID, iat: issuedAt }));
  const signingInput = `${header}.${claims}`;
  const privateKey = await importAPNSPrivateKey(env.APNS_PRIVATE_KEY);
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    privateKey,
    new TextEncoder().encode(signingInput)
  );
  const jwt = `${signingInput}.${base64URLBytes(normalizeECDSASignature(new Uint8Array(signature)))}`;

  cachedAPNSJWT = {
    jwt,
    issuedAt,
    keyID: env.APNS_KEY_ID,
    teamID: env.APNS_TEAM_ID
  };
  return jwt;
}

async function importAPNSPrivateKey(privateKeyPEM: string): Promise<CryptoKey> {
  const normalizedPEM = privateKeyPEM.replace(/\\n/g, "\n");
  const base64 = normalizedPEM
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const keyData = base64ToBytes(base64);

  return await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );
}

function makeAPNSPayload(input: {
  title?: string;
  message: string;
  data?: JSONObject;
}): JSONObject {
  const alert: JSONObject = { body: input.message };
  if (input.title) {
    alert.title = input.title;
  }

  const payload: JSONObject = {
    aps: {
      alert,
      sound: "default"
    }
  };

  if (input.data) {
    payload.data = input.data;
  }

  return payload;
}

function apnsErrorResponse(
  result: { ok: false; status: number; reason?: string }
): Response {
  const message = result.reason
    ? `APNs rejected the notification: ${result.reason}.`
    : "APNs rejected the notification.";
  return jsonResponse(
    {
      error: "apns_failed",
      errorMessage: message,
      apnsStatus: result.status
    },
    502
  );
}

async function safeAPNSErrorBody(response: Response): Promise<{ reason?: string }> {
  try {
    const value = await response.json();
    if (isRecord(value) && typeof value.reason === "string") {
      return { reason: value.reason };
    }
  } catch {
    // APNs may return an empty response body for some failures.
  }
  return {};
}

function normalizeECDSASignature(signature: Uint8Array): Uint8Array {
  if (signature.byteLength === 64) {
    return signature;
  }

  let offset = 0;
  if (signature[offset] !== 0x30) {
    throw new Error("Unexpected APNs signature format.");
  }
  offset += 1;

  const sequenceLength = readASN1Length(signature, offset);
  offset = sequenceLength.nextOffset;
  if (sequenceLength.length !== signature.byteLength - offset) {
    throw new Error("Invalid APNs signature length.");
  }

  const r = readASN1Integer(signature, offset);
  const s = readASN1Integer(signature, r.nextOffset);
  if (s.nextOffset !== signature.byteLength) {
    throw new Error("Invalid APNs signature structure.");
  }

  const normalized = new Uint8Array(64);
  normalized.set(leftPadInteger(r.value, 32), 0);
  normalized.set(leftPadInteger(s.value, 32), 32);
  return normalized;
}

function readASN1Length(bytes: Uint8Array, offset: number): { length: number; nextOffset: number } {
  const first = bytes[offset];
  if (first === undefined) {
    throw new Error("Invalid ASN.1 length.");
  }

  if ((first & 0x80) === 0) {
    return { length: first, nextOffset: offset + 1 };
  }

  const lengthByteCount = first & 0x7f;
  if (lengthByteCount === 0 || lengthByteCount > 2) {
    throw new Error("Unsupported ASN.1 length.");
  }

  let length = 0;
  let cursor = offset + 1;
  for (let index = 0; index < lengthByteCount; index += 1) {
    const byte = bytes[cursor];
    if (byte === undefined) {
      throw new Error("Invalid ASN.1 length.");
    }
    length = (length << 8) | byte;
    cursor += 1;
  }

  return { length, nextOffset: cursor };
}

function readASN1Integer(bytes: Uint8Array, offset: number): { value: Uint8Array; nextOffset: number } {
  if (bytes[offset] !== 0x02) {
    throw new Error("Invalid ASN.1 integer.");
  }

  const integerLength = readASN1Length(bytes, offset + 1);
  const start = integerLength.nextOffset;
  const end = start + integerLength.length;
  if (end > bytes.byteLength) {
    throw new Error("Invalid ASN.1 integer length.");
  }

  return {
    value: bytes.slice(start, end),
    nextOffset: end
  };
}

function leftPadInteger(bytes: Uint8Array, length: number): Uint8Array {
  let start = 0;
  while (start < bytes.byteLength - 1 && bytes[start] === 0) {
    start += 1;
  }

  const trimmed = bytes.slice(start);
  if (trimmed.byteLength > length) {
    throw new Error("ASN.1 integer is too large.");
  }

  const padded = new Uint8Array(length);
  padded.set(trimmed, length - trimmed.byteLength);
  return padded;
}

// MARK: - Storage

async function readPushTokenRecord(env: Env, pushRelayToken: string): Promise<PushTokenRecord | null> {
  const record = await env.HOMESTEAD_PUSH_TOKENS.get<PushTokenRecord>(pushRelayToken, "json");
  if (!record || !isPushEnvironment(record.environment)) {
    return null;
  }

  if (
    typeof record.apnsToken !== "string" ||
    typeof record.deviceName !== "string" ||
    typeof record.appVersion !== "string" ||
    typeof record.updatedAt !== "string"
  ) {
    return null;
  }

  return record;
}

// MARK: - Request / Response Helpers

async function readJSONObject(
  request: Request
): Promise<{ ok: true; value: JSONObject } | { ok: false; response: Response }> {
  const contentLength = request.headers.get("content-length");
  if (contentLength && Number(contentLength) > MAX_JSON_BYTES) {
    return { ok: false, response: errorResponse(413, "payload_too_large", "Request body is too large.") };
  }

  try {
    const body = await request.json();
    if (!isJSONObject(body)) {
      return { ok: false, response: errorResponse(400, "invalid_json", "Expected a JSON object.") };
    }

    return { ok: true, value: body };
  } catch {
    return { ok: false, response: errorResponse(400, "invalid_json", "Expected a valid JSON request body.") };
  }
}

function jsonResponse(body: JSONObject, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store"
    }
  });
}

function errorResponse(status: number, error: string, message: string): Response {
  return jsonResponse({ error, message }, status);
}

// MARK: - Validation

function requiredString(payload: JSONObject, key: string): string | undefined {
  const value = payload[key];
  if (typeof value !== "string") {
    return undefined;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function optionalString(payload: JSONObject, key: string): string | undefined {
  const value = payload[key];
  if (typeof value !== "string") {
    return undefined;
  }

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function isPushEnvironment(value: unknown): value is PushEnvironment {
  return value === "sandbox" || value === "production";
}

function isUsableToken(value: string, minLength: number, maxLength: number): boolean {
  return value.length >= minLength && value.length <= maxLength;
}

function isJSONObject(value: unknown): value is JSONObject {
  return isRecord(value) && Object.values(value).every(isJSONValue);
}

function isJSONValue(value: unknown): value is JSONValue {
  if (
    value === null ||
    typeof value === "string" ||
    typeof value === "number" ||
    typeof value === "boolean"
  ) {
    return true;
  }

  if (Array.isArray(value)) {
    return value.every(isJSONValue);
  }

  return isRecord(value) && Object.values(value).every(isJSONValue);
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function objectValue(value: JSONValue | undefined): JSONObject | undefined {
  return isJSONObject(value) ? value : undefined;
}

// MARK: - Auth / Encoding

async function isAuthorizedAdminRequest(request: Request, env: Env): Promise<boolean> {
  if (!env.HOMESTEAD_PUSH_ADMIN_TOKEN) {
    return false;
  }

  const authorization = request.headers.get("authorization");
  const token = authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) {
    return false;
  }

  return timingSafeEqual(token, env.HOMESTEAD_PUSH_ADMIN_TOKEN);
}

function timingSafeEqual(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  const length = Math.max(leftBytes.length, rightBytes.length);
  let difference = leftBytes.length ^ rightBytes.length;

  for (let index = 0; index < length; index += 1) {
    difference |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }

  return difference === 0;
}

function base64URLString(value: string): string {
  return base64URLBytes(new TextEncoder().encode(value));
}

function base64URLBytes(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function base64ToBytes(value: string): Uint8Array {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
}

function safeError(error: unknown): JSONObject {
  if (error instanceof Error) {
    return { name: error.name, message: error.message };
  }

  return { message: "Unknown error" };
}
