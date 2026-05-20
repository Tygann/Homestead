# Live Home Assistant Previews

Homestead includes a debug-only `Live Home Assistant` Xcode preview. It is intentionally opt-in so Home Assistant credentials are not stored in source code.

## Preferred local setup

Run the app in the simulator once, open Settings, enter your Home Assistant base URL and long-lived access token, then tap Test Connection or Connect. The token is stored in Keychain and can be reused by the live preview on the same development machine.

## Environment variable fallback

If Keychain credentials are not available to Xcode previews, set these local environment variables in your Xcode scheme or shell environment:

```sh
HOMESTEAD_PREVIEW_HA_BASE_URL=https://your-home-assistant.example.com
HOMESTEAD_PREVIEW_HA_TOKEN=your-long-lived-access-token
```

Do not commit scheme files or shell scripts containing real tokens. Xcode user data is ignored by Git for this project.

## Notes

The default `Sample Data` preview never connects to Home Assistant. Use it for UI work when you do not need real entities.
