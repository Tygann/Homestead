# Live Home Assistant Previews

Homestead includes a debug-only `Live Home Assistant` Xcode preview. It is intentionally opt-in so Home Assistant credentials are not stored in source code.

## Preferred local setup

Create a Home Assistant long-lived access token for local preview work, then copy `PreviewCredentials.example.json` to `PreviewCredentials.json` at the repo root and fill in:

```json
{
  "baseURL": "https://homeassistant.example.com",
  "accessToken": "your-preview-only-long-lived-token"
}
```

`PreviewCredentials.json` is ignored by git and copied into Debug builds only.

Do not commit this file or reuse a personal token you care about elsewhere.

## Live Preview Behavior

The live preview reads the bundled `PreviewCredentials.json` copied by the Debug build phase. This keeps the native app's OAuth sign-in flow clean while giving Xcode Preview a deterministic credential source.

If `PreviewCredentials.json` is missing, the live preview falls back to the saved base URL and OAuth credential from local app storage. Xcode Preview may not reliably share the simulator app's Keychain/container, so the local JSON file is the recommended live preview path.

## Notes

The default `Sample Data` preview never connects to Home Assistant. Use it for UI work when you do not need real entities.

The `Live Home Assistant` preview stores dashboard card selection and sizing in a preview-specific `UserDefaults` suite. This keeps live preview layout edits persistent across preview reloads without mixing them into the simulator app's normal on-device dashboard layout.
