# BillDueTracker TestFlight Smoke Checklist

Build target:
- App: `BillDueTracker`
- Expected marketing version: `1.0`
- Expected build number: `7`

Tester/device:
- Tester name:
- Device model + iOS version:
- Test date:

## Gate 1: Installation
1. Install the latest TestFlight build.
2. Launch app from fresh install state.
3. Confirm no crash on first launch.

Result:
- [Yes] Pass
- [ ] Fail
- Notes:

## Gate 2: Core Bills Flow
1. Add a bill from Dashboard.
2. Edit the same bill.
3. Mark bill paid.
4. Confirm Dashboard sections update (`Overdue`, `Due Soon`, `Upcoming`, `Paid This Month`).

Result:
- [yes] Pass
- [ ] Fail
- Notes: Scrolling seems unresponsive when scrolling over each bill. 

## Gate 2B: Edit Due Date Save Regression
1. Open an existing bill.
2. Tap `Edit`.
3. Change due date in schedule picker.
4. Tap `Save`.
5. Re-open the same bill and confirm updated due date persists.

Result:
- [ ] Pass
- [fail] Fail
- Notes: changing to a date on different month doesnt save. Also when adding bill, doesn't allow user to select bill due date on different months

## Gate 3: Notifications
1. In Settings, request notification permission if needed.
2. Trigger `Send Test Notification (5s)`.
3. Confirm notification appears on device.
4. Re-open app and ensure no crash.

Result:
- [Pass] Pass
- [ ] Fail
- Notes:

## Gate 4: Paywall Entry
1. Trigger paywall from upgrade entry point.
2. Confirm monthly and annual options are visible.
3. Confirm disclosure text and legal links are present and readable.

Result:
- [ ] Pass
- [ ] Fail
- Notes:

## Gate 5: Purchase + Restore
1. Complete monthly purchase in sandbox TestFlight flow.
2. Verify entitlement unlock behavior.
3. Restore purchases.
4. Verify entitlement remains active.

Result:
- [Pass] Pass
- [ ] Fail
- Notes: No restore purchases button.

## Gate 6: CSV Export
1. Go to Settings.
2. Tap `Generate CSV Export`.
3. Verify success alert appears.
4. Tap `Share Last CSV Export`.
5. Confirm share sheet appears and file name ends with `.csv`.

Result:
- [Pass] Pass
- [ ] Fail
- Notes: Not sure if having CSV exports is worth it. We're bringing users a step back instead of managing it in-app.

## Gate 6B: Swipe Delete (Dashboard + Timeline)
1. In Dashboard, swipe left on a bill card.
2. Tap `Delete`, confirm destructive alert.
3. Verify bill is removed from Dashboard sections.
4. Go to Timeline > `Bills & Subscriptions`.
5. Swipe left on a cycle row, delete and confirm.
6. Verify the same bill no longer appears.

Result:
- [ ] Pass
- [Fail] Fail
- Notes: Not sure why Dashboard doesn't show the same info as Dashboard. Can see 3 unpaid bills on Timeline but in Dashboard only see 1 Upcoming

## Gate 6C: Notification Settings Simplified UX
1. Go to Settings > Notifications.
2. Verify only actionable fields are shown (`Permission`, `Next Trigger`, stage toggles, permission/reconcile/test actions).
3. Toggle at least one reminder stage on/off.
4. Verify no success popup appears for toggle changes.
5. Tap `Reconcile Reminder Schedules` and confirm completion message.

Result:
- [Pass] Pass
- [ ] Fail
- Notes: Not sure why there needs to be reconcile reminder schedules button. Seems irrelevant, doesn't conform to best apps practices.

## Gate 7: Backup + Restore
1. Tap `Create Full Backup`.
2. Verify success alert appears.
3. Tap `Share Backup File` and confirm file is present.
4. Use `Restore From Backup` with the backup file.
5. Verify app data rehydrates and no crash occurs.

Result:
- [ ] Pass
- [ ] Fail
- Notes:

## Gate 8: Regression Sweep
1. Navigate Dashboard, Timeline, Settings tabs repeatedly.
2. Force close and relaunch app.
3. Confirm no visual corruption or crash.

Result:
- [Pass] Pass
- [ ] Fail
- Notes:

## Launch Decision
- [ ] Go
- [No-go] No-Go

No-Go if any gate above fails.
