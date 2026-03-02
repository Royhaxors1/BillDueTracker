# BillDueTracker — Comprehensive Review

> Generated: 2026-03-03 | Scope: Architecture, Services, UI/UX, Tests, Build Config

---

## What the App Does Well

- **Clean SwiftData model graph** with proper cascade deletes and well-defined relationships
- **Correct `@MainActor` isolation** across all services — no data races
- **Zero external dependencies** — only Apple first-party frameworks
- **Professional design system** in `DesignTokens.swift` with 90%+ consistent token usage
- **First-class dark mode** with adaptive shadows, gradients, and elevation hierarchy
- **Non-disruptive paywall** — contextual, always dismissible, never unsolicited
- **Smart information hierarchy** — dashboard prioritizes Overdue > Due Soon > Upcoming > Paid
- **Well-designed notification deep-linking** from `AppDelegate` through `AppNavigationState`
- **Haptic feedback** consistently used on state-changing actions
- **Thoughtful animations** — `.snappy`, `.spring`, `.numericText()` transitions
- **Zero TODOs/FIXMEs** in the codebase
- **Comprehensive empty states** with clear CTAs everywhere

---

## Architecture Issues

### Critical

| # | Issue | Location |
|---|---|---|
| 1 | **Non-transactional backup restore** — `deleteCurrentData` saves immediately, then if subsequent insert fails, all data is permanently lost with no rollback | `BackupService.swift:243-356` |
| 2 | **Freemium bypass via backup restore** — free users can restore a backup with unlimited bills, completely bypassing the 8-bill limit | `BackupService.swift:276-297` |

### High

| # | Issue | Location |
|---|---|---|
| 3 | **No repository abstraction** — `ModelContext` leaks into views; services are static enums that cannot be mocked | `BillOperations.swift`, all Views |
| 4 | **Silently swallowed errors** — `try?` on `context.fetch()` and `context.save()` hides data corruption | `BillOperations.swift:35,49`, `ProviderActionSeeder.swift:29` |
| 5 | **Overdue notifications repeat forever** — daily `UNCalendarNotificationTrigger` fires indefinitely if the user never reopens the app | `ReminderNotificationService.swift:110-113` |
| 6 | **Heavy computed properties** — `billAndCyclePairs`, `overdueBills`, `dueSoonBills` cascade on every body evaluation | `DashboardView.swift:388-462` |

### Medium

| # | Issue | Location |
|---|---|---|
| 7 | **Orphaned files on bill deletion** — cascade-deleted `PaymentProof` records leave files on disk | `AttachmentStore.swift` (missing cleanup) |
| 8 | **No schema migration for backups** — old backups permanently rejected | `BackupService.swift:381` |
| 9 | **Broken file references after restore** — `PaymentProof.fileURLString` restored but actual files aren't in backup | `BackupService.swift:329-338` |
| 10 | **Singleton + injection ambiguity** — `ReminderNotificationService.shared` coexists with parameter injection | `ReminderNotificationService.swift:46` |
| 11 | **Eager NavigationLink in Timeline** — destination views created eagerly instead of value-based | `TimelineView.swift:114` |
| 12 | **No logging framework** — errors either shown via alerts or silently dropped | Entire codebase |
| 13 | **Duplicated code** — `markCyclePaid`, `deleteBill`, `actionRow`, `detailLine`, `formattedAmount` copy-pasted across 3+ views | `DashboardView`, `TimelineView`, `BillDetailView` |
| 14 | **Vision OCR double-resume risk** — `perform` throw + completion handler could crash | `BillExtractionService.swift:61-85` |

---

## UI/UX Issues

### Medium

| # | Issue | Location |
|---|---|---|
| 15 | **No VoiceOver labels** — only 2 real `.accessibilityLabel` instances across the entire app | All Views |
| 16 | **No Dynamic Type support** — zero `@ScaledMetric` usage; fixed frame sizes won't scale | `BillCardView.swift:13`, `SharedUIComponents.swift:110,179` |
| 17 | **Quick Add isn't quick** — 5 sections, 8+ fields, `.graphical` date picker takes half the screen | `QuickAddBillView.swift:115-134` |
| 18 | **No inline validation** — Save button disabled with no indication of which field needs attention | `QuickAddBillView.swift:196-200` |
| 19 | **"Due day behavior" is jargon** — "End-of-month clamp" vs "Fixed day" means nothing to users | `QuickAddBillView.swift:131-134` |
| 20 | **Hardcoded `cornerRadius: 12`** bypasses the design token system (which defines `card=16` and `section=20`) | `BillDetailView.swift:318,322,380,384`, `SettingsView.swift:148,152,168,172` |
| 21 | **No reminder setup in bill creation** — global-only config in Settings with no discoverability | `SettingsView.swift:156-165` |

### Low

| # | Issue | Location |
|---|---|---|
| 22 | Section subtitle copy reads like internal docs ("Verified completed cycles in current month") | `DashboardView.swift:132,141,150` |
| 23 | "Scope" is abstract jargon — "Filter" or "Bill Status" is clearer | `DashboardView.swift:81` |
| 24 | MetricTiles are not tappable despite looking like buttons | `DashboardView.swift:43-74` |
| 25 | SGD currency hardcoded in formatters — limits to Singapore users | `DashboardView.swift:32`, `TimelineView.swift:20` |
| 26 | Border widths inconsistent (1.0, 1.15, 1.2, 1.25) with no token | Various files |
| 27 | SwipeToDeleteContainer puts delete button before content in VoiceOver order | `SharedUIComponents.swift:184-198` |

---

## Test Coverage Gaps

| Priority | Gap |
|---|---|
| **Critical** | `BillOperations` (addBill, markPaid, deleteBill, setBillActive) — zero direct unit tests |
| **High** | `ReminderNotificationService.schedule()` — notification trigger construction untested |
| **High** | `AttachmentStore` — file operations completely untested |
| **High** | `BillStatusTests.swift:173` uses real `ReminderNotificationService.shared` instead of fake |
| **Medium** | No StoreKit Configuration file for local subscription testing |
| **Medium** | `BackupService.validate` — only 1 of 4 error paths tested |
| **Medium** | No UI tests for swipe-to-delete, bill lifecycle, or backup restore |
| **Low** | `BillExtractionService` image/PDF paths untested (only text path covered) |

---

## Step-by-Step Optimisation Plan

### Phase 1 — Fix Critical Data Safety Issues

1. **Make backup restore transactional**: Before deleting current data, validate and prepare all new objects. Only delete + insert in a single save. If insert fails, current data survives.
2. **Enforce freemium limits in restore**: After restoring, check `UsageLimitService.canCreateBill` and either reject the restore or deactivate excess bills with a user warning.
3. **Cap overdue notification repeats**: Add a `dateComponents.day` or set a `UNTimeIntervalNotificationTrigger` with a finite repeat window (e.g., 7 days).

### Phase 2 — Architecture Hardening

4. **Add error logging**: Replace all `try?` in `BillOperations` and `ProviderActionSeeder` with `do/catch` that logs to `os.Logger`. This surfaces silent failures.
5. **Extract computed properties from DashboardView**: Move `billAndCyclePairs`, `overdueBills`, `dueSoonBills`, etc. into a `@Observable` DashboardViewModel. This prevents recalculation on every body eval.
6. **Deduplicate shared logic**: Extract `markCyclePaid`, `deleteBill`, `actionRow`, `detailLine`, `formattedAmount` into `SharedUIComponents.swift` or a shared extension.
7. **Add orphaned file cleanup**: In `BillOperations.deleteBill`, call `AttachmentStore.removeFileIfExists` for each `PaymentProof` before cascade delete.
8. **Remove singleton**: Drop `ReminderNotificationService.shared` and pass the instance through the environment consistently.

### Phase 3 — UI/UX Polish

9. **Add accessibility labels**: Prioritize `BillCardView`, `MetricTile`, `PrimaryActionButton`, and all action buttons. Target full VoiceOver navigability.
10. **Add `@ScaledMetric`**: Replace fixed frame sizes (32pt icon, 44pt button height) with scaled metrics for Dynamic Type.
11. **Simplify Quick Add**: Switch date picker to `.compact` style; hide "Due day behavior" behind an "Advanced" disclosure; replace custom provider toggle with a picker + "Other..." option.
12. **Add inline validation**: Show a red outline or helper text on the provider name field when empty. Show amount format hint.
13. **Fix design token inconsistencies**: Add `AppTheme.Radius.inner = 12` and `AppTheme.Border.standard = 1.0` / `.elevated = 1.2`. Replace all hardcoded values.
14. **Rewrite user-facing copy**: "Scope" → "Filter"; "Verified completed cycles" → "Paid this month"; "End-of-month clamp" → "Use last day of short months".

### Phase 4 — Test Coverage

15. **Unit test `BillOperations`**: Cover `addBill`, `markPaid`, `deleteBill`, `setBillActive`, and `reconcileReminders` with in-memory `ModelContext`.
16. **Unit test `AttachmentStore`**: Test file write, read, and cleanup with a temp directory.
17. **Fix `BillStatusTests.swift:173`**: Replace `ReminderNotificationService.shared` with `FakeNotificationCenter`.
18. **Add StoreKit Configuration file**: Enable local subscription testing in the Simulator.
19. **Add `BackupService.validate` tests** for all 4 error paths.
20. **Add UI tests** for swipe-to-delete, bill lifecycle actions, and backup restore flow.

### Phase 5 — Launch Blockers

21. **Create subscription products** in App Store Connect (monthly + annual).
22. **Set up App Store metadata** — privacy policy URL, support URL, screenshots.
23. **Execute the full TestFlight smoke checklist** (all 8 gates in `TESTFLIGHT_SMOKE_CHECKLIST.md`).
24. **Update `LAUNCH_RUNBOOK.md`** to reflect build number 3 (currently says 2).
