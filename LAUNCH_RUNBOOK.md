# BillDueTracker Launch Runbook

This runbook is strict and hard-cutover by design.

Last updated: March 3, 2026

## 1) Release Config (Repo)
- [x] `DEVELOPMENT_TEAM` set in `project.yml`
- [x] `MARKETING_VERSION` confirmed for release (`1.0`)
- [x] `CURRENT_PROJECT_VERSION` confirmed for release (`5`)
- [x] `xcodegen generate` executed after config changes

## 2) Preflight Verification
- [x] `make ios-verify` passes (build + all tests)

## 3) StoreKit Production Readiness (App Store Connect)
- [x] Monthly product exists: `com.marcuschin.billduetracker.pro.monthly`
- [x] Annual product exists: `com.marcuschin.billduetracker.pro.annual`
- [x] Products are in the same subscription group
- [x] Price + territory + trial config confirmed
- [x] Review metadata/screenshots for subscriptions completed

## 4) Compliance / Metadata (App Store Connect)
- [x] Privacy policy URL set
- [x] Terms/support links set
- [x] Subscription disclosure text is complete and consistent
- [x] App Review contact phone set
- [ ] Primary/secondary app categories set in App Store Connect UI

## 5) Archive + TestFlight
- [x] Archive succeeds (generic iOS device)
- [x] IPA export succeeds (`xcodebuild -exportArchive`, app-store-connect)
- [x] Upload to TestFlight succeeds
- [ ] Internal tester install succeeds

## 6) Must-Pass Manual Smoke (TestFlight)
- [ ] Add/edit bills works
- [ ] Notification permission + test notification works
- [ ] Paywall opens
- [ ] Purchase monthly works
- [ ] Purchase annual/trial works
- [ ] Restore purchases works
- [ ] CSV export works
- [ ] Full backup create works
- [ ] Full restore from backup file works

## 7) Go/No-Go
- Go only if every must-pass item above is green.
- Any blocker is a hard stop and must be fixed before submission.

## Current External Blockers (March 3, 2026)
- Build `1.0 (5)` is `VALID` in App Store Connect and assigned to internal group `Bills Tracking test`; internal install + smoke are still pending.
- Primary/secondary app categories are currently unset and must be updated in App Store Connect UI.

## Local Commands
```bash
cd /Users/marcuschin/Codex/BillDueTracker
xcodegen generate
make ios-verify
xcodebuild \
  -project BillDueTracker.xcodeproj \
  -scheme BillDueTracker \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath build/BillDueTracker.xcarchive \
  archive
```
