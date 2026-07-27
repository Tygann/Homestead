# Homestead Plus App Store Connect Checklist

The app owns StoreKit behavior and capability gating. App Store Connect remains the source of truth for sale availability, localized prices, trials, Family Sharing, and production offer codes.

## Products

Create one subscription group named `Homestead Plus`:

| Reference name | Product ID | Type | US price |
| --- | --- | --- | --- |
| Homestead Plus Monthly | `com.tyler.Homestead.plus.monthly` | Auto-renewable, 1 month | $4.99 |
| Homestead Plus Annual | `com.tyler.Homestead.plus.annual` | Auto-renewable, 1 year | $24.99 |
| Homestead Plus Lifetime | `com.tyler.Homestead.plus.lifetime` | Non-consumable | $69.99 |

- Give Annual a 14-day free introductory offer.
- Enable Family Sharing for all three products only after confirming the permanent App Store Connect choice.
- Localize display names, descriptions, prices, and subscription-group metadata for every supported storefront.
- Add review screenshots from Settings > Homestead Plus and submit the products with the app version that first exposes them.

## App Review Notes

Homestead is a free native Home Assistant client with an optional Homestead Plus purchase. Core entity control, one dashboard, one configured server, standard single-item widgets, notifications, wallpaper, history, and management views remain free.

Reviewers can open Settings > Homestead Plus. Plus unlocks creation of additional dashboards, adding additional servers, iCloud preference sync, Sensor Board widgets, and advanced Sensor chart/gauge presentations. Existing premium configuration is preserved if access expires. Restore Purchases and Redeem Code are on the Homestead Plus screen.

Use the StoreKit sandbox account supplied through App Review for purchase-state testing. Homestead has no separate application account.

## Tester Access

Before release, have the four TestFlight testers exercise the normal annual introductory trial and accelerated sandbox renewal/expiration behavior.

The checked-in StoreKit configuration includes a free annual test offer named
`Homestead Plus Annual Test Code` for exercising the redemption sheet locally.
This is test data only; the complimentary production access below uses the
lifetime product configured in App Store Connect.

After the app and lifetime product are approved:

1. In App Store Connect, open the Homestead Plus Lifetime non-consumable.
2. Create four unique, one-time-use offer codes with free access.
3. Distribute one code privately to each tester.
4. Have each tester open Settings > Homestead Plus > Redeem Code.
5. Confirm the Settings status becomes Lifetime after StoreKit verifies the transaction.

Never implement complimentary access using hard-coded Apple IDs, local flags, or Home Assistant account identifiers.
