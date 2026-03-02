# BillDueTracker Launch Checkpoint

Last updated: March 1, 2026

## Completed Locally
- Entitlement/paywall build blocker fixed.
- CSV export flow implemented and covered by tests.
- Backup/restore flow implemented and covered by tests.
- `xcodegen generate` completed.
- `make ios-verify` passed (unit + UI tests).
- Release build number bumped for re-upload:
  `CURRENT_PROJECT_VERSION = 2`
- Release archive succeeded:
  `build/BillDueTracker.xcarchive`
- Release IPA export succeeded:
  `build/export/BillDueTracker.ipa`
- Upload to App Store Connect succeeded:
  `Upload succeeded. Uploaded BillDueTracker` (processing in TestFlight)
- App icon asset pipeline fixed:
  - Added `INFOPLIST_KEY_CFBundleIconName = AppIcon`
  - Added complete iPhone+iPad AppIcon PNG set in
    `BillDueTracker/Resources/Assets.xcassets/AppIcon.appiconset`
  - Source icon applied from:
    `/Users/marcuschin/Downloads/ChatGPT Image Mar 2, 2026, 01_20_13 AM.png`

## Current Hard Blockers (External)
- Build processing in TestFlight must complete before install/testing.
- Internal tester install + smoke test checklist are still pending.
- Subscription products and App Store metadata/compliance setup are still pending.

## Exact Resume Steps
1. Wait until the uploaded build is marked ready in App Store Connect TestFlight.
2. Add internal testers and install the build.
3. Execute the manual smoke list in `LAUNCH_RUNBOOK.md` Section 6.
4. Complete StoreKit product setup and compliance metadata in `LAUNCH_RUNBOOK.md` Sections 3 and 4.
5. If any smoke item fails, return here and patch before submission.
