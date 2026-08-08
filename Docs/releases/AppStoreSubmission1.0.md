# App Store Submission 1.0

Last audited: August 7, 2026

This document tracks the first public App Store submission for Homestead. App Store Connect remains the live source of truth; recheck every item immediately before submission.

## Current App Store Connect Audit

### Version 1.0

- Status: Prepare for Submission
- Selected binary: Version 1.0, Build 12
- App previews: none
- iPhone screenshots: six polished 6.5-inch screenshots uploaded in final story order
- Promotional text, description, and keywords: saved
- Support URL: `https://homesteadcontrol.com/support`
- Marketing URL: `https://homesteadcontrol.com`
- Copyright: `2026 Tyler Keegan`
- App Review sign-in required: enabled, with credentials not yet supplied
- App Review contact information: incomplete
- Release behavior: manual release after approval

### App Information

- Name: `Homestead: Home Assistant`
- Subtitle: `Native control for your home`
- Bundle ID and SKU: `com.tyler.Homestead`
- Content rights: not configured
- Primary category: Lifestyle; secondary category: Utilities
- Age rating: 4+ (with Apple's regional equivalents)
- Export compliance: `ITSAppUsesNonExemptEncryption` is `false` in the shipping Info.plist
- Digital Services Act status: developer is currently identified as a non-trader

### Trust And Safety

- Privacy policy URL: `https://homesteadcontrol.com/privacy`
- App privacy questionnaire: published; Device ID, App Functionality, linked to the user/device, not used for tracking
- Accessibility declaration: iPhone and iPad drafts prepared with Dark Interface support; Apple disables publication until version 1.0 is released

### Pricing And Availability

- App price: free in all 175 countries or regions
- Storefront availability: all 175 countries or regions, including future storefronts
- Public distribution: selected
- Apple silicon Mac availability: disabled for version 1.0
- Apple Vision Pro availability: disabled for version 1.0
- Apple School Manager reduced-price option: enabled

### Homestead+

- Subscription group: `Homestead+`
- Monthly: `com.tyler.Homestead.plus.monthly`, Prepare for Submission
- Annual: `com.tyler.Homestead.plus.annual`, Prepare for Submission
- Lifetime: `com.tyler.Homestead.plus.lifetime`, Prepare for Submission
- Family Sharing: enabled for all three products
- Availability: all countries or regions selected for all three products
- Product localizations and review notes: present
- Production prices: not configured on Monthly or Annual; confirm Lifetime pricing separately
- Annual 14-day introductory trial: described in review notes, but no production introductory-offer configuration was visible during the audit
- Required product review screenshot: missing from Monthly, Annual, and Lifetime
- First products must be added to the version 1.0 submission and reviewed with the app

## Recommended Listing Positioning

Homestead should be presented as a fast, private, native companion for an existing Home Assistant home. It is an independent third-party client, not the official Home Assistant app. Avoid implying affiliation or ownership of the Home Assistant name or trademarks. Retain the preferred App Store name `Homestead: Home Assistant` for the initial submission, with clear non-affiliation copy, unless Apple or the Home Assistant project objects or direct trademark guidance requires a change.

### Subtitle

`Native control for your home`

### Promotional Text

`A fast, private, native way to control your Home Assistant home, build focused dashboards, explore every room, and keep important controls close at hand.`

### Description

Homestead brings your Home Assistant home to iPhone and iPad with a focused, native experience designed for everyday control.

Build dashboards around the devices and information that matter most. Adjust lights and climate, secure doors, run scenes, check cameras and sensors, and explore your home by area—all with familiar Apple-platform interactions.

FEATURES

• Native controls for lights, switches, fans, locks, covers, climate, media players, vacuums, scenes, scripts, automations, helpers, and more
• Flexible dashboards with controls, status cards, charts, gauges, weather, media, cameras, and activity summaries
• Area and entity browsing backed by your Home Assistant configuration
• Detailed sensor history, timelines, update information, and device context
• Home Screen widgets for controls, status, sensors, actions, and Sensor Boards
• Home Assistant notifications and secure OAuth sign-in
• Optional iCloud synchronization for Homestead-owned preferences and dashboards
• Support for multiple Home Assistant servers with Homestead+

PRIVATE BY DESIGN

Homestead connects to Home Assistant servers you choose. Credentials are kept in the device Keychain. Homestead does not sell personal information or use third-party advertising.

HOMESTEAD+

Core home control, one server, one dashboard, wallpaper, history, notifications, and standard widgets are free. Homestead+ adds multiple dashboards and servers, iCloud synchronization, Sensor Board widgets, and advanced sensor presentations. Choose monthly, annual, or lifetime access. Eligible customers receive a 14-day trial with the annual plan.

Homestead requires an existing Home Assistant installation. Homestead is an independent third-party client and is not affiliated with or endorsed by the Home Assistant project.

### Keywords

`smart home,automation,dashboard,widgets,lights,sensors,climate,security,control,HomeKit`

Do not repeat `Homestead` or `Home Assistant` in keywords because they already appear in the app name.

### Categories

- Primary: Lifestyle
- Secondary: Utilities

### Contact And URLs

- Public contact email: `support@homesteadcontrol.com`
- Privacy policy: `https://homesteadcontrol.com/privacy`
- Recommended support URL: `https://homesteadcontrol.com/support`
- Recommended marketing URL: `https://homesteadcontrol.com`
- Recommended privacy URL: `https://homesteadcontrol.com/privacy`

Create one small public site containing the product overview, support/contact information, privacy policy, and independent-client disclosure. The existing `connect.homesteadcontrol.com` page remains the OAuth client-identification page and should not be repurposed as the support or marketing destination.

## Recommended Screenshot Story

The first three screenshots receive priority because Apple may use only those on installation sheets.

1. **Your home, beautifully organized** — full Home dashboard with lights, climate, lock, shades, fan, weather, and a person chip.
2. **Control every room at a glance** — a populated Areas screen or area detail with several recognizable controls. The current deterministic Areas fixture is too sparse and must be improved before capture.
3. **Understand what changed** — polished sensor detail with history chart and range statistics.
4. **Dashboards that fit your home** — dashboard customization or card configuration with a representative live preview.
5. **Powerful widgets, right where you need them** — curated widget gallery or a real Home Screen composition showing Control, Sensor, and Sensor Board widgets.
6. **More home with Homestead+** — purchase screen showing multiple dashboards and servers, iCloud sync, Sensor Boards, and advanced sensor presentations.

Use fictional, coherent sample-home data. Do not include personal names, real cameras, addresses, server URLs, entity identifiers, notification contents, or identifiable household details.

### Capture Requirements

- Prepare portrait iPhone assets at an App Store Connect-accepted 6.9-inch size. The clean launch set uses `1320 x 2868` pixels, JPEG, without alpha.
- Capture clean app UI first; create a second marketing-composite set only if headline treatments materially improve the story.
- Keep text large, concise, and inside safe margins.
- Verify every depicted feature is present in the submitted build.
- Create one Homestead+ screen capture that can also serve as the review screenshot for Monthly, Annual, and Lifetime if App Store Connect accepts the same image for all three products.

## Recommended Submission Choices

- Release manually after approval so storefront timing and product availability can be checked before launch. Approved August 7, 2026.
- Keep the app itself free. Approved August 7, 2026.
- Use worldwide storefront availability after the privacy policy, support channel, tax, agreements, and DSA/trader decisions are complete. Approved August 7, 2026.
- Disable Apple silicon Mac and Vision Pro availability for version 1.0 until each experience is explicitly tested and supported for launch. Approved August 7, 2026.
- Do not enable an education-volume discount for a free app unless App Store Connect requires a retained default.
- Treat Family Sharing as intentionally enabled and permanent for the three Homestead+ products.

## Remaining User Decisions

- Destination inbox for forwarding `support@homesteadcontrol.com`
- DSA trader or non-trader status based on the developer's legal/commercial circumstances
- Whether to seek written confirmation from the Home Assistant project about the preferred `Homestead: Home Assistant` name before submission

## Confirmed Legal Metadata

- Copyright: `2026 Tyler Keegan` (confirmed August 7, 2026; Homestead is not a registered rights-owning entity)

## App Store Connect Configuration Completed

- Free pricing in all 175 countries or regions
- Availability in all 175 countries or regions, including future storefronts
- Manual release after App Review approval
- Apple silicon Mac availability disabled for version 1.0
- Apple Vision Pro availability disabled for version 1.0
- Promotional text, description, keywords, support URL, marketing URL, and copyright saved for version 1.0
- Subtitle and Lifestyle / Utilities categories saved
- Privacy Policy URL saved
- Privacy details published by the account holder: Device ID, App Functionality, linked to the user/device, not used for tracking.
- Age Rating questionnaire saved: calculated 4+, with standard regional equivalents; all listed capabilities and content categories answered No or None.
- Accessibility drafts prepared for iPhone and iPad with Dark Interface as the only currently declared supported feature. Apple keeps Publish disabled until an app version is released.

## Screenshot Assets Prepared

- Six clean iPhone 6.9-inch launch candidates are stored in `AppStoreAssets/Screenshots/iPhone-6.9` at `1320 x 2868`, JPEG, without alpha.
- Six polished headline composites are stored in `AppStoreAssets/Screenshots/iPhone-6.9-Marketing` with the same accepted dimensions and format for future 6.9-inch slots.
- App Store Connect requested the version's 6.5-inch slot, so matching `1284 x 2778` composites are stored in `AppStoreAssets/Screenshots/iPhone-6.5-Marketing` and were uploaded August 7, 2026.
- The ordered story covers the full Dashboard, Areas, sensor History, card customization, widgets, and Homestead+.
- Screenshot-only person fixtures use the fictional name `Alex`; the user's real name no longer appears in the launch candidates.
- The clean set remains available as a fallback, and `Scripts/compose_app_store_screenshots.py` reproducibly regenerates the marketing set without altering the captured app UI.

## Public Website Completed

- `https://homesteadcontrol.com`
- `https://homesteadcontrol.com/support`
- `https://homesteadcontrol.com/privacy`
- Deployed through the existing `homestead-api` Cloudflare Worker; public, API, and OAuth hosts remain route-isolated
- Redesigned around Homestead's native iOS visual language with responsive light/dark presentation, a fictional dashboard preview, and a branded social sharing card

## Notification Privacy Hardening Completed

- The app sends only its pseudonymous relay token, APNs token, and APNs environment to the Homestead notification relay.
- The Worker stores only the APNs token and environment, keyed by the relay token; device name and app version are not retained. The next app build also stops transmitting those unnecessary fields.
- Successful registration applies a 90-day expiration, so inactive notification mappings are removed automatically.
- The bundled privacy manifest, public privacy policy, and App Store privacy responses use the same Device ID / App Functionality / linked / no-tracking contract.
- Upload a new App Store build containing this minimized client request and bundled privacy manifest before final submission.

## Final Preflight

- Complete Paid Applications agreement, banking, and tax requirements
- Configure Monthly, Annual, and Lifetime production prices
- Configure and verify the Annual 14-day introductory trial
- Upload review screenshots for all three Homestead+ products
- Add all three products to the version 1.0 review submission
- Publish the prepared accessibility declarations after version 1.0 is released
- Complete the content-rights declaration
- Supply App Review contact information, test instructions, and a reviewable Home Assistant account/server path
- Prepare and upload the required iPad screenshot set
- Run focused tests, generic simulator build, Release/archive-oriented build, and rendered screenshot-route checks
- Retest purchase, restore, expiration/lapse, redemption, and Family Sharing with the final TestFlight build
- Review every field and asset before selecting Add for Review
