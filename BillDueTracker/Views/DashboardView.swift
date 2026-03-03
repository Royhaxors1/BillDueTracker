import SwiftData
import SwiftUI
import UIKit

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementState: EntitlementState
    @EnvironmentObject private var appNavigation: AppNavigationState

    @Query(sort: \BillItem.updatedAt, order: .reverse) private var bills: [BillItem]

    let notificationService: ReminderNotificationService
    let attachmentStore: AttachmentStore

    @State private var showingAddSheet = false
    @State private var paywallEntryPoint: PaywallEntryPoint?
    @State private var navigationPath = NavigationPath()
    @State private var scopeFilter: BillScopeFilter = .active
    @State private var editBillTarget: EditBillTarget?
    @State private var pendingDeletionBill: BillItem?
    @State private var quickActionErrorMessage: String?

    private let columns = [
        GridItem(.flexible(), spacing: AppTheme.Spacing.md),
        GridItem(.flexible(), spacing: AppTheme.Spacing.md)
    ]

    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "SGD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    if scopeFilter != .inactive {
                        LazyVGrid(columns: columns, spacing: AppTheme.Spacing.md) {
                            MetricTile(
                                title: "Overdue",
                                value: "\(overdueBills.count)",
                                systemImage: "exclamationmark.triangle.fill",
                                tone: .overdue
                            )
                            .accessibilityIdentifier("dashboard.metric.overdue")

                            MetricTile(
                                title: "Due Soon",
                                value: "\(dueSoonBills.count)",
                                systemImage: "clock.fill",
                                tone: .dueSoon
                            )
                            .accessibilityIdentifier("dashboard.metric.dueSoon")

                            MetricTile(
                                title: "Upcoming",
                                value: "\(upcomingBills.count)",
                                systemImage: "calendar",
                                tone: .accent
                            )
                            .accessibilityIdentifier("dashboard.metric.upcoming")

                            MetricTile(
                                title: "Paid This Month",
                                value: "\(paidThisMonthBills.count)",
                                systemImage: "checkmark.circle.fill",
                                tone: .paid
                            )
                            .accessibilityIdentifier("dashboard.metric.paid")
                        }
                        .animation(.snappy(duration: 0.3), value: overdueBills.count)
                        .animation(.snappy(duration: 0.3), value: dueSoonBills.count)
                        .animation(.snappy(duration: 0.3), value: upcomingBills.count)
                        .animation(.snappy(duration: 0.3), value: paidThisMonthBills.count)
                    }

                    SectionCard(title: "Filter", subtitle: "Choose which bills to show.") {
                        Picker("Bill Scope", selection: $scopeFilter) {
                            ForEach(BillScopeFilter.allCases) { filter in
                                Text(filter.title).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("dashboard.scopeFilter")
                    }

                    if scopeFilter != .inactive,
                       overdueBills.isEmpty,
                       dueSoonBills.isEmpty,
                       upcomingBills.isEmpty,
                       paidThisMonthBills.isEmpty {
                        EmptyStateCard(
                            title: "No Bills Yet",
                            message: "Add your first utility, telco, credit card, or subscription bill to start reminders.",
                            actionTitle: "Add First Bill",
                            systemImage: "tray.fill",
                            action: startAddFlow
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if scopeFilter != .inactive, entitlementState.hasAccess(to: .monthlyInsights) {
                        insightsSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if scopeFilter != .inactive {
                        UpgradeBanner(
                            title: "Monthly insights are in Pro",
                            message: "See projected due amounts and risk concentration for the current month.",
                            ctaTitle: "Unlock Insights"
                        ) {
                            paywallEntryPoint = .dashboardInsights
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if scopeFilter != .inactive, !overdueBills.isEmpty {
                        billSection(
                            title: "Overdue",
                            subtitle: "Settle these first to stop daily overdue reminders.",
                            pairs: overdueBills
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if scopeFilter != .inactive, !dueSoonBills.isEmpty {
                        billSection(
                            title: "Due Soon (7 Days)",
                            subtitle: "Upcoming due dates with highest short-term risk.",
                            pairs: dueSoonBills
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if scopeFilter != .inactive, !upcomingBills.isEmpty {
                        billSection(
                            title: "Upcoming 30 Days",
                            subtitle: "Planned obligations for the rest of this month window.",
                            pairs: upcomingBills
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if scopeFilter != .inactive, !paidThisMonthBills.isEmpty {
                        billSection(
                            title: "Paid This Month",
                            subtitle: "Bills you already paid this month.",
                            pairs: paidThisMonthBills
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if scopeFilter != .active, !inactiveBills.isEmpty {
                        inactiveBillSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if scopeFilter == .inactive, inactiveBills.isEmpty {
                        EmptyStateCard(
                            title: "No Inactive Bills",
                            message: "Archived bills will appear here so you can reactivate them anytime.",
                            actionTitle: "View Active Bills",
                            systemImage: "archivebox"
                        ) {
                            scopeFilter = .active
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.xl)
                .animation(.snappy(duration: 0.3), value: bills.count)
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear
                    .frame(height: AppTheme.Spacing.lg)
            }
            .appScreenBackground()
            .navigationTitle("Bill Due Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: startAddFlow) {
                        Label("Add Bill", systemImage: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityIdentifier("dashboard.addBill")
                    .accessibilityLabel("Add bill")
                    .accessibilityHint("Creates a new bill profile")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                QuickAddBillView(notificationService: notificationService)
            }
            .sheet(item: $paywallEntryPoint) { entry in
                PaywallView(entryPoint: entry)
            }
            .sheet(item: $editBillTarget) { target in
                if let bill = bill(for: target.billID) {
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
            .navigationDestination(for: BillNavigationTarget.self) { target in
                if let bill = bill(for: target.billID) {
                    BillDetailView(
                        bill: bill,
                        notificationService: notificationService,
                        attachmentStore: attachmentStore,
                        initialCycleID: target.cycleID
                    )
                } else {
                    Text("Bill is no longer available.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            .onReceive(appNavigation.$pendingNavigationTarget) { target in
                guard let target else { return }
                openNavigationTarget(target)
                appNavigation.pendingNavigationTarget = nil
            }
        }
    }

    @ViewBuilder
    private func billSection(
        title: String,
        subtitle: String,
        pairs: [(BillItem, BillCycle)]
    ) -> some View {
        SectionCard(title: title, subtitle: subtitle) {
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(pairs, id: \.0.id) { bill, cycle in
                    SwipeToDeleteContainer(
                        onDelete: { pendingDeletionBill = bill },
                        actionAccessibilityIdentifier: "dashboard.swipeDelete"
                    ) {
                        dashboardRow(bill: bill, cycle: cycle)
                    }
                }
            }
        }
    }

    private func dashboardRow(bill: BillItem, cycle: BillCycle) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            NavigationLink(value: BillNavigationTarget(billID: bill.id, cycleID: cycle.id)) {
                BillCardView(bill: bill, cycle: cycle, showContainer: false)
            }
            .buttonStyle(.plain)

            Divider()
                .overlay(AppTheme.Colors.hairline)

            cardQuickActions(bill: bill, cycle: cycle)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        )
        .appElevatedCard(cornerRadius: AppTheme.Radius.card, borderWidth: AppTheme.Border.standard)
    }

    @ViewBuilder
    private func cardQuickActions(bill: BillItem, cycle: BillCycle) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            if bill.isActive, cycle.paymentState == .unpaid {
                Button {
                    markCyclePaid(cycle)
                } label: {
                    Label("Mark Paid", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityIdentifier("dashboard.quickAction.markPaid")
            }

            Button {
                editBillTarget = EditBillTarget(billID: bill.id)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("dashboard.quickAction.edit")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Spacing.xs)
    }

    private var insightsSection: some View {
        SectionCard(title: "Monthly Insights", subtitle: "Projected due volume for this month.") {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text("Projected Due")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Text(formattedAmount(projectedMonthDueAmount))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .contentTransition(.numericText())
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: AppTheme.Spacing.xxs) {
                        Text("At Risk")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        Text("\(overdueBills.count + dueSoonBills.count)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle((overdueBills.count + dueSoonBills.count) > 0 ? AppTheme.Colors.dueSoon : AppTheme.Colors.paid)
                            .contentTransition(.numericText())
                    }
                }

                Text("\(activeBillCount) active bills are being tracked this month.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    private func startAddFlow() {
        let decision = UsageLimitService.canCreateBill(tier: entitlementState.tier, activeBillCount: activeBillCount)
        guard decision.isAllowed else {
            paywallEntryPoint = .addBillLimit
            return
        }
        showingAddSheet = true
    }

    private func formattedAmount(_ amount: Double) -> String {
        if let formatted = Self.amountFormatter.string(from: NSNumber(value: amount)) {
            return formatted
        }
        return String(format: "%.2f", amount)
    }

    private var activeBillCount: Int {
        bills.filter(\.isActive).count
    }

    private var projectedMonthDueAmount: Double {
        let monthStart = Date().startOfMonth(in: .current)
        let monthEnd = monthStart.addingMonths(1, in: .current)

        return billAndCyclePairs.reduce(0) { partialResult, pair in
            let bill = pair.0
            let cycle = pair.1
            guard cycle.dueDate >= monthStart,
                  cycle.dueDate < monthEnd,
                  cycle.paymentState == .unpaid,
                  let amount = bill.expectedAmount else {
                return partialResult
            }
            return partialResult + amount
        }
    }

    private var scopedBills: [BillItem] {
        switch scopeFilter {
        case .active:
            return bills.filter(\.isActive)
        case .inactive:
            return bills.filter { !$0.isActive }
        case .all:
            return bills
        }
    }

    private var billAndCyclePairs: [(BillItem, BillCycle)] {
        scopedBills.compactMap { bill in
            guard bill.isActive,
                  let cycle = BillOperations.cycleForCurrentMonth(bill: bill, now: .now, timeZone: .current)
            else {
                return nil
            }
            return (bill, cycle)
        }
    }

    private var overdueBills: [(BillItem, BillCycle)] {
        billAndCyclePairs
            .filter { _, cycle in
                cycle.paymentState == .unpaid && cycle.overdueStartedAt != nil
            }
            .sorted { $0.1.dueDate < $1.1.dueDate }
    }

    private var dueSoonBills: [(BillItem, BillCycle)] {
        let end = Date().addingDays(7, in: .current)
        return billAndCyclePairs
            .filter { _, cycle in
                cycle.paymentState == .unpaid && cycle.dueDate >= .now && cycle.dueDate <= end
            }
            .sorted { $0.1.dueDate < $1.1.dueDate }
    }

    private var upcomingBills: [(BillItem, BillCycle)] {
        let start = Date().addingDays(8, in: .current)
        let end = Date().addingDays(30, in: .current)
        return billAndCyclePairs
            .filter { _, cycle in
                cycle.paymentState == .unpaid && cycle.dueDate >= start && cycle.dueDate <= end
            }
            .sorted { $0.1.dueDate < $1.1.dueDate }
    }

    private var paidThisMonthBills: [(BillItem, BillCycle)] {
        let monthStart = Date().startOfMonth(in: .current)
        let monthEnd = monthStart.addingMonths(1, in: .current)
        return scopedBills
            .filter(\.isActive)
            .compactMap { bill in
                let matchingCycle = bill.cycles
                    .filter { cycle in
                        guard cycle.paymentState == .paid, let paidAt = cycle.paidAt else {
                            return false
                        }
                        return paidAt >= monthStart && paidAt < monthEnd
                    }
                    .sorted { lhs, rhs in
                        (lhs.paidAt ?? lhs.dueDate) > (rhs.paidAt ?? rhs.dueDate)
                    }
                    .first
                guard let matchingCycle else { return nil }
                return (bill, matchingCycle)
            }
            .sorted { lhs, rhs in
                (lhs.1.paidAt ?? lhs.1.dueDate) > (rhs.1.paidAt ?? rhs.1.dueDate)
            }
    }

    private var inactiveBills: [(BillItem, BillCycle?)] {
        scopedBills
            .filter { !$0.isActive }
            .map { bill in
                let latestCycle = bill.cycles.max { lhs, rhs in
                    lhs.dueDate < rhs.dueDate
                }
                return (bill, latestCycle)
            }
            .sorted { lhs, rhs in
                (lhs.1?.dueDate ?? .distantPast) > (rhs.1?.dueDate ?? .distantPast)
            }
    }

    private var inactiveBillSection: some View {
        SectionCard(title: "Inactive Bills", subtitle: "Archived bills do not count toward active limits.") {
            VStack(spacing: AppTheme.Spacing.sm) {
                ForEach(inactiveBills, id: \.0.id) { bill, cycle in
                    SwipeToDeleteContainer(
                        onDelete: { pendingDeletionBill = bill },
                        actionAccessibilityIdentifier: "dashboard.swipeDelete"
                    ) {
                        NavigationLink(value: BillNavigationTarget(billID: bill.id, cycleID: cycle?.id)) {
                            BillCardView(bill: bill, cycle: cycle)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func bill(for id: UUID) -> BillItem? {
        bills.first(where: { $0.id == id })
    }

    private func openNavigationTarget(_ target: BillNavigationTarget) {
        guard bill(for: target.billID) != nil else { return }
        appNavigation.selectedTab = .dashboard
        navigationPath = NavigationPath()
        navigationPath.append(target)
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

private struct EditBillTarget: Identifiable {
    let billID: UUID

    var id: UUID { billID }
}
