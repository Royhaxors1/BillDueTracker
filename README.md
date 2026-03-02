# Bill Due Tracker

## Automated iOS Verification

This project enforces a hard cutover build flow where tests run whenever we build via automation:

- Local verify: `make ios-verify`
- Local build alias (build + tests): `make ios-build`
- CI verify: `.github/workflows/ios-verify.yml`

You can override project/scheme/destination when needed:

```bash
IOS_PROJECT_PATH=BillDueTracker.xcodeproj IOS_SCHEME=BillDueTracker IOS_DESTINATION="platform=iOS Simulator,name=iPhone 17" ./scripts/ios_verify.sh
```
