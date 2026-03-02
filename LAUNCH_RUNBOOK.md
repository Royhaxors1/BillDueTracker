# BillDueTracker Launch Runbook

This runbook is strict and hard-cutover by design.

## 1) Release Config (Repo)
- [x] `DEVELOPMENT_TEAM` set in `project.yml`
- [x] `MARKETING_VERSION` confirmed for release (`1.0`)
- [x] `CURRENT_PROJECT_VERSION` confirmed for release (`2`)
- [x] `xcodegen generate` executed after config changes

## 2) Preflight Verification
- [x] `make ios-verify` passes (build + all tests)

## 3) StoreKit Production Readiness (App Store Connect)
- [ ] Monthly product exists: `com.marcuschin.billduetracker.pro.monthly`
- [ ] Annual product exists: `com.marcuschin.billduetracker.pro.annual`
- [ ] Products are in the same subscription group
- [ ] Price + territory + trial config confirmed
- [ ] Review metadata/screenshots for subscriptions completed

## 4) Compliance / Metadata (App Store Connect)
- [ ] Privacy policy URL set
- [ ] Terms/support links set
- [ ] Subscription disclosure text is complete and consistent

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

## Current External Blockers (March 1, 2026)
- Uploaded build is still processing in App Store Connect TestFlight.
- StoreKit subscription products/metadata are still incomplete (Section 3).
- Compliance metadata (privacy policy, terms/support) is still incomplete (Section 4).

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
