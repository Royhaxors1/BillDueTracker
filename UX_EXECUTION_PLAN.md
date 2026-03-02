# Bill Due Tracker UX Optimization Plan

This plan is a hard-cutover execution sequence for maximizing user value.

## Phase 0 (Immediate)
- [x] P0.1 Preserve cycle context end-to-end.
  - Timeline and Dashboard now open Bill Detail with an explicit cycle target.
  - Bill Detail resolves targeted cycle first, then falls back to current cycle.
- [x] P0.2 Add notification tap routing.
  - Reminder notifications carry bill/cycle IDs in payload.
  - App delegate captures notification taps and forwards to app navigation.
  - App routes directly to the matching bill detail.
- [x] P0.3 Move notification permission request to post-value moment.
  - Remove bootstrap-time permission request.
  - Request permission after first successful bill creation.

## Phase 1 (Value Unlock)
- [x] P1.1 Add bill lifecycle controls.
  - Archive/Pause/Reactivate/Delete actions in Bill Detail.
  - Add active/inactive filters so users can manage free-plan cap naturally.
- [x] P1.2 Make payment proofs actionable.
  - Open/preview/share/delete proof attachments from Bill Detail.
- [x] P1.3 Clean Settings information architecture.
  - Separate user controls from diagnostics/advanced maintenance actions.

## Phase 2 (Conversion + Trust Polish)
- [x] P2.1 Paywall flow clarity upgrades.
  - Improve restore outcomes messaging and recovery guidance.
  - Show product-load state and fallback guidance inline.
- [x] P2.2 Reminder trust loop.
  - Surface “last reconciliation” and “last successful schedule” in user-facing language.
- [x] P2.3 Navigation polish.
  - Add quick actions from timeline/dashboard cards for mark-paid and edit.

## Exit Criteria
- No cycle mismatch when navigating from Timeline/Dashboard to Detail.
- Notification tap always lands on the intended bill detail.
- Permission request shown only after user receives value (first bill added).
- All tests pass in `make ios-verify`.
