# Homestead Privacy Policy

Last updated: July 27, 2026

Homestead is a native client for Home Assistant. It connects directly to Home Assistant servers that you choose and stores Home Assistant credentials in the device Keychain.

## Data Homestead handles

- Home Assistant server addresses, entity state, registry metadata, dashboards, and preferences needed to provide the app.
- Home Assistant sign-in credentials stored locally in the device Keychain.
- Notification delivery identifiers used to relay Home Assistant notifications to Apple Push Notification service.
- Optional iCloud key-value data for Homestead-owned server metadata, dashboards, safety preferences, and small appearance preferences. Credentials, Home Assistant state, notification secrets, widget snapshots, and wallpaper images are not placed in Homestead's iCloud sync payload.
- App Store purchase and subscription status supplied by Apple through StoreKit.

## Data sharing

Homestead does not sell personal information or use third-party advertising. Home Assistant data is sent only to the Home Assistant servers configured by the user, Apple services required for platform features such as StoreKit, iCloud, and push notifications, and Homestead's notification relay when remote Home Assistant notification delivery is enabled.

## Storage and deletion

Most Homestead data is stored on the user's device. Removing a server or deleting the app removes its local data subject to normal device backups and Apple platform behavior. Users can disable Homestead iCloud sync in Settings and manage App Store purchases through their Apple Account.

## Contact

Questions can be submitted through the Homestead repository at <https://github.com/Tygann/Homestead/issues>.
