# Homestead API

Cloudflare Worker backend foundation for Homestead push notification relay and Home Assistant connect/auth client metadata.

The Worker project name is `homestead-api`. The repo folder is `api/`; when this is connected to Cloudflare Workers Builds, set the Git root directory to `api` so Cloudflare finds `wrangler.jsonc` and `package.json`.

## Domains

The Worker project name is `homestead-api` and should serve both Homestead backend hostnames after the manual Cloudflare cutover:

- `api.homesteadcontrol.com` custom domain on `homestead-api`
- `connect.homesteadcontrol.com` custom domain on `homestead-api`

Keep the old `homestead` Cloudflare Pages project untouched until the cutover is tested. It remains the temporary rollback target for `connect.homesteadcontrol.com`.

## API Routes

`api.homesteadcontrol.com` serves the push/API surface:

- `GET /health`
- `POST /mobile-app/register-push-token`
- `POST /mobile-app/push`
- `POST /admin/test-push`

```text
https://api.homesteadcontrol.com
```

The Home Assistant mobile app `push_url` should eventually be:

```text
https://api.homesteadcontrol.com/mobile-app/push
```

## Connect/Auth Route

`connect.homesteadcontrol.com` serves the Home Assistant OAuth/connect client page:

- `GET /`

The connect page includes:

```html
<link rel="redirect_uri" href="homestead://auth" />
```

The app's OAuth/client identifier should remain `connect.homesteadcontrol.com`. Do not move it to the API hostname.

Unknown paths on the connect hostname return a plain 404. API and admin routes are intentionally not exposed from `connect.homesteadcontrol.com`.

## Local Development

Install dependencies:

```sh
npm install
```

Run a type check:

```sh
npm run typecheck
```

Run tests:

```sh
npm test
```

Run Wrangler locally:

```sh
npm run dev
```

Use `.dev.vars` for local secrets only. Do not commit `.dev.vars`, `.env`, APNs `.p8` files, or copied private keys.

## Cloudflare Setup

1. Create a Cloudflare Worker named `homestead-api`.
2. Connect the Worker to the GitHub repo.
3. Set the Worker root/build directory to `api`.
4. Add the custom domain `api.homesteadcontrol.com`.
5. Create a KV namespace for push token mappings.
6. Bind that namespace as `HOMESTEAD_PUSH_TOKENS`.
7. Replace the placeholder KV namespace ID in `wrangler.jsonc`.
8. Add these Worker secrets:

```text
APNS_KEY_ID
APNS_TEAM_ID
APNS_BUNDLE_ID
APNS_PRIVATE_KEY
HOMESTEAD_PUSH_ADMIN_TOKEN
```

Set secrets with Wrangler from this folder:

```sh
npx wrangler secret put APNS_KEY_ID
npx wrangler secret put APNS_TEAM_ID
npx wrangler secret put APNS_BUNDLE_ID
npx wrangler secret put APNS_PRIVATE_KEY
npx wrangler secret put HOMESTEAD_PUSH_ADMIN_TOKEN
```

`APNS_PRIVATE_KEY` should be the contents of the Apple `.p8` private key, supplied only as a Worker secret. The `.p8` file itself must never be committed to the repo.

## Connect Domain Cutover

Do not delete the old `homestead` Pages project as part of this repo change. Cut over `connect.homesteadcontrol.com` manually after the updated Worker is deployed and the API hostname still passes smoke tests.

1. Deploy the updated `homestead-api` Worker.
2. Remove `connect.homesteadcontrol.com` from the old `homestead` Pages project.
3. Add `connect.homesteadcontrol.com` as a custom domain on `homestead-api`.
4. Test sign-in immediately from Homestead.
5. Keep the old Pages project temporarily as rollback.

If sign-in breaks, remove `connect.homesteadcontrol.com` from `homestead-api`, restore it to the old `homestead` Pages project, and confirm the old connect page is serving before retrying the Worker cutover.

## Push Token Registration

The iOS app will register an app-generated relay token and the current APNs device token:

```http
POST /mobile-app/register-push-token
Content-Type: application/json
```

```json
{
  "pushRelayToken": "random app-generated relay token",
  "apnsToken": "ios apns device token",
  "environment": "sandbox",
  "deviceName": "Tyler-iPhone",
  "appVersion": "1.0"
}
```

`environment` must be `sandbox` or `production`. Local Xcode builds use APNs sandbox; TestFlight and App Store builds use production APNs.

The Worker stores only the APNs token, APNs environment, device name, app version, and update timestamp in `HOMESTEAD_PUSH_TOKENS`, keyed by the relay token.

## Home Assistant Relay

Home Assistant sends notifications to:

```text
POST /mobile-app/push
```

The Worker expects Home Assistant's native-app cloud push payload, including:

```json
{
  "message": "Hello World",
  "title": "Test message sent via mobile_app.notify",
  "push_token": "registered relay token",
  "registration_info": {
    "app_id": "com.tyler.Homestead",
    "app_version": "1.0",
    "webhook_id": "webhook_id_from_registration"
  },
  "data": {
    "key": "value"
  }
}
```

The Worker looks up `push_token`, sends the alert to APNs using the stored APNs token and environment, and returns `201` when APNs accepts the notification.

## Admin Test Push

`POST /admin/test-push` is protected by:

```http
Authorization: Bearer <HOMESTEAD_PUSH_ADMIN_TOKEN>
```

Example body:

```json
{
  "pushRelayToken": "registered relay token",
  "title": "Homestead",
  "message": "Test notification"
}
```

If `HOMESTEAD_PUSH_ADMIN_TOKEN` is not configured, the endpoint rejects all requests.
