import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlementState: EntitlementState

    let entryPoint: PaywallEntryPoint

    @State private var selectedPlan: SubscriptionPlan = .annualPro
    @State private var isProcessing = false
    @State private var inlineStatus: InlineStatus?

    private var isLoadingPlans: Bool {
        entitlementState.isLoadingProducts || !entitlementState.hasLoadedProducts
    }

    private var hasUnavailablePlans: Bool {
        entitlementState.hasLoadedProducts &&
        SubscriptionPlan.allCases.contains { !entitlementState.isPlanAvailable($0) }
    }

    private var canStartPurchase: Bool {
        !isProcessing && !isLoadingPlans && entitlementState.isPlanAvailable(selectedPlan)
    }

    private var primaryCTA: String {
        if isProcessing {
            return "Processing..."
        }
        if isLoadingPlans {
            return "Loading plans..."
        }
        if !entitlementState.hasAnyAvailablePlan {
            return "Plans Unavailable"
        }
        return selectedPlan.ctaLabel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text("Bill Due Tracker Pro")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Text(entryPoint.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.Colors.textPrimary)

                        Text(entryPoint.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }

                    if isLoadingPlans {
                        statusCard(
                            title: "Loading available plans",
                            message: "Fetching current pricing from the App Store.",
                            tone: .neutral,
                            systemImage: "hourglass"
                        )
                    } else if !entitlementState.hasAnyAvailablePlan {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            statusCard(
                                title: "Plans unavailable",
                                message: "This build could not load subscription products. Check App Store account/region and retry.",
                                tone: .overdue,
                                systemImage: "exclamationmark.triangle.fill"
                            )

                            Button {
                                Task {
                                    await refreshPaywall()
                                }
                            } label: {
                                HStack {
                                    Text("Retry Plan Load")
                                    Spacer()
                                }
                                .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                            .disabled(isProcessing || entitlementState.isLoadingProducts)
                        }
                    } else if hasUnavailablePlans {
                        statusCard(
                            title: "Limited plan availability",
                            message: "Only plans currently available for this build can be selected.",
                            tone: .neutral,
                            systemImage: "info.circle.fill"
                        )
                    }

                    VStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(SubscriptionPlan.allCases) { plan in
                            let isAvailable = entitlementState.isPlanAvailable(plan)
                            let isSelected = selectedPlan == plan && isAvailable
                            let isSelectable = !isProcessing && !isLoadingPlans && isAvailable

                            Button {
                                guard isSelectable else { return }
                                inlineStatus = nil
                                selectedPlan = plan
                            } label: {
                                HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
                                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                        Text(plan.title)
                                            .font(.headline)
                                            .foregroundStyle(isAvailable ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                                        Text(priceLabel(for: plan))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(isAvailable ? AppTheme.Colors.textPrimary : AppTheme.Colors.textMuted)
                                        Text(badgeLabel(for: plan))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(isAvailable ? AppTheme.Colors.accent : AppTheme.Colors.textMuted)
                                    }

                                    Spacer()

                                    Image(systemName: selectionSymbol(for: plan, isAvailable: isAvailable, isSelected: isSelected))
                                        .foregroundStyle(isAvailable ? AppTheme.Colors.accent : AppTheme.Colors.textMuted)
                                }
                                .padding(AppTheme.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                                        .fill(AppTheme.Colors.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                                        .stroke(
                                            isSelected ? AppTheme.Colors.accent : AppTheme.Colors.border,
                                            lineWidth: isSelected ? 2 : 1.2
                                        )
                                )
                                .opacity(isSelectable ? 1 : 0.7)
                            }
                            .buttonStyle(.plain)
                            .disabled(!isSelectable)
                        }
                    }

                    SectionCard(title: "Everything in Pro", subtitle: "Unlock all advanced workflows.") {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            ForEach(UsageLimitService.proFeatures) { feature in
                                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppTheme.Colors.paid)
                                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                        Text(feature.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.Colors.textPrimary)
                                        Text(feature.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.Colors.textSecondary)
                                    }
                                }
                            }
                        }
                    }

                    PrimaryActionButton(
                        title: primaryCTA,
                        systemImage: "sparkles"
                    ) {
                        Task {
                            await purchaseSelectedPlan()
                        }
                    }
                    .disabled(!canStartPurchase)
                    .opacity(canStartPurchase ? 1 : 0.65)
                    .accessibilityIdentifier("paywall.primaryCta")

                    Button {
                        Task {
                            await restorePurchases()
                        }
                    } label: {
                        HStack {
                            Text("Restore Purchases")
                            Spacer()
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing)
                    .accessibilityIdentifier("paywall.restore")

                    if let inlineStatus {
                        statusCard(
                            title: inlineStatus.title,
                            message: inlineStatus.message,
                            tone: inlineStatus.tone,
                            systemImage: inlineStatus.systemImage
                        )
                    }

                    Text("Prices are in SGD. Manage or cancel from iOS subscriptions settings.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.xl)
            }
            .appScreenBackground()
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await refreshPaywall()
            }
            .onChange(of: entitlementState.lastUpdatedAt) { _, _ in
                reconcileSelectedPlan()
            }
        }
    }

    private func purchaseSelectedPlan() async {
        guard canStartPurchase else { return }
        isProcessing = true
        inlineStatus = nil
        defer { isProcessing = false }

        do {
            try await entitlementState.purchase(plan: selectedPlan)
            dismiss()
        } catch EntitlementError.userCancelled {
            // User cancellation is an expected flow.
        } catch EntitlementError.productUnavailable {
            await refreshPaywall()
            inlineStatus = .purchaseFailure("That plan is unavailable right now. Choose an available plan and try again.")
        } catch {
            inlineStatus = .purchaseFailure(error.localizedDescription)
        }
    }

    private func restorePurchases() async {
        guard !isProcessing else { return }
        isProcessing = true
        inlineStatus = nil
        defer { isProcessing = false }

        do {
            try await entitlementState.restorePurchases()
            inlineStatus = .restoreSuccess
        } catch EntitlementError.noActiveSubscription {
            inlineStatus = .restoreNoSubscription
        } catch {
            inlineStatus = .restoreFailure(error.localizedDescription)
        }
    }

    private func refreshPaywall() async {
        await entitlementState.refresh()
        reconcileSelectedPlan()
    }

    private func reconcileSelectedPlan() {
        guard entitlementState.hasLoadedProducts else { return }
        guard !entitlementState.isPlanAvailable(selectedPlan) else { return }
        if let firstAvailable = SubscriptionPlan.allCases.first(where: { entitlementState.isPlanAvailable($0) }) {
            selectedPlan = firstAvailable
        }
    }

    private func priceLabel(for plan: SubscriptionPlan) -> String {
        if isLoadingPlans {
            return "Loading current price..."
        }
        if entitlementState.isPlanAvailable(plan) {
            return entitlementState.priceLabel(for: plan)
        }
        return "Unavailable for this build"
    }

    private func badgeLabel(for plan: SubscriptionPlan) -> String {
        if isLoadingPlans {
            return "Checking..."
        }
        return entitlementState.isPlanAvailable(plan) ? plan.badge : "Unavailable"
    }

    private func selectionSymbol(for plan: SubscriptionPlan, isAvailable: Bool, isSelected: Bool) -> String {
        if !isAvailable && !isLoadingPlans {
            return "nosign"
        }
        return isSelected ? "largecircle.fill.circle" : "circle"
    }

    @ViewBuilder
    private func statusCard(title: String, message: String, tone: AppTone, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.Colors.tint(for: tone))
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .fill(AppTheme.Colors.toneFill(for: tone))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .stroke(AppTheme.Colors.border, lineWidth: 1)
        )
    }
}

private enum InlineStatus {
    case purchaseFailure(String)
    case restoreSuccess
    case restoreNoSubscription
    case restoreFailure(String)

    var title: String {
        switch self {
        case .purchaseFailure:
            return "Purchase couldn't complete"
        case .restoreSuccess:
            return "Subscription restored"
        case .restoreNoSubscription:
            return "No subscription found"
        case .restoreFailure:
            return "Restore failed"
        }
    }

    var message: String {
        switch self {
        case let .purchaseFailure(detail):
            return detail
        case .restoreSuccess:
            return "Pro is active on this Apple Account. Close this screen to continue."
        case .restoreNoSubscription:
            return "No active Pro plan was found for this Apple Account. Check the purchasing account or choose a plan above."
        case let .restoreFailure(detail):
            return "\(detail) Check App Store login and network connection, then try again."
        }
    }

    var tone: AppTone {
        switch self {
        case .restoreSuccess:
            return .paid
        case .restoreNoSubscription:
            return .neutral
        case .purchaseFailure, .restoreFailure:
            return .overdue
        }
    }

    var systemImage: String {
        switch self {
        case .restoreSuccess:
            return "checkmark.circle.fill"
        case .restoreNoSubscription:
            return "info.circle.fill"
        case .purchaseFailure, .restoreFailure:
            return "exclamationmark.triangle.fill"
        }
    }
}
