# Homestead Review Home

This HA OS custom app runs a second, fictional Home Assistant instance for App Review. It is intentionally separate from the production Home Assistant Core container.

## Isolation Contract

- No production Home Assistant configuration folders are mapped.
- No Supervisor, Home Assistant, or authentication API token is granted.
- Host networking is disabled.
- Automatic LAN discovery components are omitted, so the review instance does not enumerate production devices.
- The app receives only its Supervisor-managed `/data` volume.
- The review instance listens on the host's port `8124`; only this port should be published at `review.homesteadcontrol.com`.
- All entities, users, OAuth tokens, history, and dashboards belong exclusively to the review instance.

The app still shares the Raspberry Pi's hardware and Docker bridge. Keep HA OS and the app updated, use a unique reviewer password, and disable the public route when review access is no longer needed.

## HA OS Installation

Copy this directory to `/addons/homestead_review_home`, reload the app store, install **Homestead Review Home**, and start it. The first launch exposes Home Assistant onboarding at `http://<HA OS host>:8124`.

After onboarding, populate only fictional entities and create a dedicated non-owner reviewer account. Do not reuse production Home Assistant credentials or configuration.

## Published Review Route

The App Store review deployment uses:

- Public URL: `https://review.homesteadcontrol.com`
- Cloudflare Tunnel ingress: `review.homesteadcontrol.com` to `http://local-homestead-review-home:8123`
- Cloudflare DNS: proxied CNAME to the existing Home Assistant tunnel
- HA OS host-only fallback: `http://<HA OS host>:8124`

Keep the reviewer password outside the repository. The deployed instance contains only Home Assistant's fictional Demo integration and supporting built-in services; automatic discovery integrations must not be added.

## Removal And Recovery

The review environment is disposable and does not participate in the production Home Assistant backup configuration.

1. Remove the `review.homesteadcontrol.com` entry from the Cloudflared app's `additional_hosts` option and restart Cloudflared.
2. Delete the `review.homesteadcontrol.com` DNS record from the `homesteadcontrol.com` Cloudflare zone.
3. Uninstall **Homestead Review Home** from HA OS.
4. Optionally remove `/addons/homestead_review_home` from HA OS and this repository directory.

Removing the review app does not change the production Home Assistant Core container, its integrations, or the existing automatic backup schedule and Cloudflare backup destination. Cloudflare DNS records are not automatically deleted when the tunnel route or HA OS app is removed.
