# Live Home Assistant Previews

Homestead includes a debug-only `Live Home Assistant` Xcode preview. It is intentionally opt-in so Home Assistant credentials are not stored in source code.

## Preferred local setup

Run the app in the simulator once, open Settings, enter your Home Assistant base URL, then use Sign in with Home Assistant. Homestead stores the OAuth refresh token and access-token metadata in Keychain.

## Live Preview Behavior

The live preview uses the saved base URL and OAuth credential from local app storage. There is no long-lived-token environment variable fallback anymore.

## Notes

The default `Sample Data` preview never connects to Home Assistant. Use it for UI work when you do not need real entities.

The `Live Home Assistant` preview stores dashboard card selection and sizing in a preview-specific `UserDefaults` suite. This keeps live preview layout edits persistent across preview reloads without mixing them into the simulator app's normal on-device dashboard layout.
