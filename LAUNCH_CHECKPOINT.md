# BillDueTracker Launch Checkpoint

Last updated: March 3, 2026

## Completed Locally
- Entitlement/paywall build blocker fixed.
- CSV export flow implemented and covered by tests.
- Backup/restore flow implemented and covered by tests.
- `xcodegen generate` completed.
- `make ios-verify` passed (unit + UI tests).
- Release build metadata prepared for the latest upload:
  `CURRENT_PROJECT_VERSION = 5`
- Release archive succeeded:
  `build/BillDueTracker.xcarchive`
- Release IPA export succeeded:
  `build/export/BillDueTracker.ipa`
- Upload to App Store Connect succeeded:
  `Upload succeeded. Uploaded BillDueTracker`
- Build status confirmed in App Store Connect:
  - Build `1.0 (5)` is `VALID` (processed)
  - Build `5` is already assigned to internal TestFlight group `Bills Tracking test`
- App Store version `1.0` is now linked to build `5` for submission.
- StoreKit products verified:
  - Subscription group: `BillsDueTracker Pro`
  - Products: `com.marcuschin.billduetracker.pro.monthly`, `com.marcuschin.billduetracker.pro.annual`
  - Global annual intro offer configured (`FREE_TRIAL`, `ONE_WEEK`) across all territories.
- App Store metadata configured via API:
  - Privacy policy URL set.
  - Support URL and marketing URL set.
  - Description/keywords/promotional text populated with subscription disclosure + terms/privacy/support links.
  - App review contact details set (name, email, phone, review notes).
- Age rating declaration completed (all sensitive content categories set to `NONE` or `false`).
- App icon asset pipeline fixed:
  - Added `INFOPLIST_KEY_CFBundleIconName = AppIcon`
  - Added complete iPhone+iPad AppIcon PNG set in
    `BillDueTracker/Resources/Assets.xcassets/AppIcon.appiconset`
  - Source icon applied from:
    `/Users/marcuschin/Downloads/ChatGPT Image Mar 2, 2026, 01_20_13 AM.png`

## Current Hard Blockers (External)
- Internal tester install + smoke test checklist are still pending.
- Primary/secondary app categories remain unset (App Store Connect API disallows updating category relationships; must be set in UI).

## Exact Resume Steps
1. Install build `1.0 (5)` from TestFlight (internal group `Bills Tracking test`).
2. Execute the manual smoke list in `LAUNCH_RUNBOOK.md` Section 6.
3. In App Store Connect UI, set primary category and optional secondary category.
4. Submit version `1.0` with first-time subscriptions for review.
5. If any smoke item fails, return here and patch before submission.
