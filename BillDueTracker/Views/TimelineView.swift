import SwiftData
import SwiftUI
import UIKit

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BillCycle.dueDate, order: .forward) private var cycles: [BillCycle]

    let notificationService: ReminderNotificationService
    let attachmentStore: AttachmentStore

    @State private var selectedMonth = Date()
    @State private var editBillTarget: TimelineEditBillTarget?
    @State private var pendingDeletionBill: BillItem?
    @State private var quickActionErrorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    SectionCard(
                        title: "Month",
                        subtitle: "Filter obligations by billing cycle."
                    ) {
                        VStack(spacing: AppTheme.Spacing.sm) {
                            DatePicker(
                                "Selected Month",
                                selection: $selectedMonth,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .accessibilityIdentifier("timeline.monthPicker")

                            Button {
                                selectedMonth = Date()
                            } label: {
                                actionRow(icon: "calendar.badge.clock", text: "Jump to Current Month")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    SectionCard(
                        title: "Bills & Subscriptions",
                        subtitle: monthSummary
                    ) {
                        if filteredCycles.isEmpty {
                            EmptyStateCard(
                                title: "No Bills in This Month",
                                message: "No dues are scheduled for this period yet.",
                                actionTitle: "Back to Current Month",
                                systemImage: "calendar.badge.exclamationmark"
                            ) {
                                selectedMonth = Date()
                            }
                        } else {
                            VStack(spacing: AppTheme.Spacing.sm) {
                                ForEach(filteredCycles) { cycle in
                                    SwipeToDeleteContainer(
                                        onDelete: {
                                            if let bill = cycle.billItem {
                                                pendingDeletionBill = bill
                                            }
                                        },
                                        actionAccessibilityIdentifier: "timeline.swipeDelete"
                                    ) {
                                        timelineRow(for: cycle)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.xl)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: AppTheme.Spacing.lg)
            }
            .appScreenBackground()
            .navigationTitle("Monthly Timeline")
            .sheet(item: $editBillTarget) { target in
                if let cycle = cycles.first(where: { $0.id == target.cycleID }),
                   let bill = cycle.billItem {
                    QuickAddBillView(notificationService: notificationService, billToEdit: bill)
                } else {
                    Text("Bill is no longer available.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .alert("Action Failed", isPresented: Binding(
                get: { quickActionErrorMessage != nil },
                set: { if !$0 { quickActionErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(quickActionErrorMessage ?? "")
            }
            .alert("Delete this bill and all cycle records?", isPresented: Binding(
                get: { pendingDeletionBill != nil },
                set: { if !$0 { pendingDeletionBill = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    pendingDeletionBill = nil
                }
                Button("Delete Bill", role: .destructive) {
                    guard let bill = pendingDeletionBill else { return }
                    pendingDeletionBill = nil
                    deleteBill(bill)
                }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private func timelineRow(for cycle: BillCycle) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            NavigationLink {
                if let bill = cycle.billItem {
                    BillDetailView(
                        bill: bill,
                        notificationService: notificationService,
                        attachmentStore: attachmentStore,
                        initialCycleID: cycle.id
                    )
                } else {
                    Text("Bill unavailable")
                }
            } label: {
                if let bill = cycle.billItem {
                    BillCardView(bill: bill, cycle: cycle, showContainer: false)
                } else {
                    timelineFallbackCard(for: cycle)
                }
            }
            .buttonStyle(.plain)

            timelineQuickActions(for: cycle)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        )
        .appElevatedCard(cornerRadius: AppTheme.Radius.card, borderWidth: AppTheme.Border.standard)
    }

    private func timelineFallbackCard(for cycle: BillCycle) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text("Unknown Bill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                Text("Due \(cycle.dueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: AppTheme.Spacing.xs) {
                StatusPill(
                    label: cycle.paymentState == .paid ? "Paid" : "Unpaid",
                    tone: cycle.paymentState == .paid ? .paid : (cycle.overdueStartedAt != nil ? .overdue : .dueSoon)
                )
                Text(cycle.dueDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func timelineQuickActions(for cycle: BillCycle) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            if cycle.paymentState == .unpaid {
                Button {
                    markCyclePaid(cycle)
                } label: {
                    Label("Mark Paid", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityIdentifier("timeline.quickAction.markPaid")
            }

            if cycle.billItem != nil {
                Button {
                    editBillTarget = TimelineEditBillTarget(cycleID: cycle.id)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("timeline.quickAction.edit")
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Spacing.xs)
        .padding(.top, AppTheme.Spacing.xxs)
    }

    private var filteredCycles: [BillCycle] {
        let monthID = BillCycleEngine.cycleMonthIdentifier(for: selectedMonth, in: .current)
        return cycles
            .filter { $0.cycleMonth == monthID }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var monthSummary: String {
        let monthLabel = selectedMonth.formatted(.dateTime.month(.wide).year())
        let unpaidCount = filteredCycles.filter { $0.paymentState == .unpaid }.count
        return "All cycles for \(monthLabel). \(unpaidCount) unpaid."
    }

    private func actionRow(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(text)
            Spacer()
        }
        .font(.subheadline.weight(.semibold))
    }

    private func markCyclePaid(_ cycle: BillCycle) {
        do {
            try BillOperations.markPaid(
                cycle: cycle,
                context: modelContext,
                notificationService: notificationService,
                now: .now
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            quickActionErrorMessage = error.localizedDescription
        }
    }

    private func deleteBill(_ bill: BillItem) {
        do {
            removeAttachedProofFiles(for: bill)
            try BillOperations.deleteBill(
                bill,
                context: modelContext,
                notificationService: notificationService
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            quickActionErrorMessage = error.localizedDescription
        }
    }

    private func removeAttachedProofFiles(for bill: BillItem) {
        for cycle in bill.cycles {
            for proof in cycle.proofs {
                if let fileURL = proof.fileURL {
                    try? attachmentStore.removeFileIfExists(at: fileURL)
                }
            }
        }
    }
}

private struct TimelineEditBillTarget: Identifiable {
    let cycleID: UUID

    var id: UUID { cycleID }
}
