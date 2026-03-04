import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementState: EntitlementState
    @AppStorage(AppAppearanceMode.storageKey) private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @Query private var users: [UserProfile]
    @Query private var bills: [BillItem]
    @Query private var reminderEvents: [ReminderEvent]

    let notificationService: ReminderNotificationService

    @State private var statusMessage: String?
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var earliestNextTrigger: Date?
    @State private var pendingEventCount = 0
    @State private var exportURL: URL?
    @State private var backupURL: URL?
    @State private var paywallEntryPoint: PaywallEntryPoint?
    @State private var showingBackupImporter = false
    @State private var showRestoreConfirmation = false
    @State private var pendingRestoreURL: URL?
    @State private var reminderStageSelections: [ReminderStage: Bool] = [:]
    @State private var isRestoringPurchases = false

    private var reminderFreshness: ReminderFreshness {
        guard let lastReconciledAt = users.first?.lastReminderReconciledAt else {
            return .unknown("Run Reconcile once to initialize schedules.")
        }

        let ageHours = Date().timeIntervalSince(lastReconciledAt) / 3600
        if ageHours <= 24 {
            return .healthy("Schedules are synced.")
        }
        return .stale("Schedules may be stale. Reconcile now.")
    }

    private var reminderFreshnessShortLabel: String {
        switch reminderFreshness {
        case .healthy:
            return "Healthy"
        case .stale:
            return "Stale"
        case .unknown:
            return "Unknown"
        }
    }

    private var reminderFreshnessTone: AppTone {
        switch reminderFreshness {
        case .healthy:
            return .paid
        case .stale:
            return .dueSoon
        case .unknown:
            return .accent
        }
    }

    private var isUITestMode: Bool {
        ProcessInfo.processInfo.environment["UITEST_MODE"] == "1"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    SectionCard(title: "Account Snapshot", subtitle: "Plan and reminder readiness at a glance.") {
                        VStack(spacing: AppTheme.Spacing.sm) {
                            detailLine("Plan", entitlementState.tier.title)
                            detailLine("Active Bills", "\(bills.filter(\.isActive).count)")
                            detailLine("Pending Reminders", "\(pendingEventCount)")

                            HStack {
                                Text("Reminder Sync")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                                Spacer()
                                StatusPill(label: reminderFreshnessShortLabel, tone: reminderFreshnessTone)
                            }
                        }
                    }

                    SectionCard(title: "Subscription", subtitle: "Current plan and Pro access.") {
                        VStack(spacing: AppTheme.Spacing.sm) {
                            detailLine("Current Plan", entitlementState.tier.title)
                            detailLine("Free Bill Limit", "\(UsageLimitService.freeActiveBillLimit) active bills")
                            detailLine("Renewal", renewalStatusText)

                            Button {
                                Task {
                                    await restorePurchasesFromSettings()
                                }
                            } label: {
                                actionRow(
                                    icon: "arrow.clockwise.circle.fill",
                                    text: isRestoringPurchases ? "Restoring Purchases..." : "Restore Purchases"
                                )
                            }
                            .buttonStyle(.bordered)
                            .disabled(isRestoringPurchases)
                            .accessibilityIdentifier("settings.restorePurchases")

                            if entitlementState.isPro {
                                HStack(spacing: AppTheme.Spacing.xs) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(AppTheme.Colors.paid)
                                    Text("Pro features are active on this device.")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.Colors.textSecondary)
                                    Spacer()
                                }
                            } else {
                                UpgradeBanner(
                                    title: "Unlock Pro",
                                    message: "Get unlimited bills, OCR/PDF extraction, monthly insights, and CSV export.",
                                    ctaTitle: "View Plans"
                                ) {
                                    paywallEntryPoint = .settingsSubscription
                                }
                            }

                            if let errorMessage = entitlementState.lastErrorMessage, !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.overdue)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    SectionCard(title: "Appearance", subtitle: "Choose light, dark, or system theme.") {
                        Picker("Theme", selection: $appearanceModeRaw) {
                            ForEach(AppAppearanceMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("settings.appearanceMode")
                    }

                    SectionCard(title: "Notifications", subtitle: "Permission and reminder stages.") {
                        VStack(spacing: AppTheme.Spacing.sm) {
                            detailLine("Permission", authorizationLabel(authorizationStatus))
                            detailLine(
                                "Next Trigger",
                                earliestNextTrigger?.formatted(date: .abbreviated, time: .shortened) ?? "Not scheduled"
                            )

                            HStack(alignment: .top, spacing: AppTheme.Spacing.xs) {
                                Image(systemName: reminderFreshness.icon)
                                    .foregroundStyle(reminderFreshness.toneColor)
                                Text(reminderFreshness.message)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                            .padding(AppTheme.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.inner, style: .continuous)
                                    .fill(reminderFreshness.backgroundColor)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.inner, style: .continuous)
                                    .stroke(AppTheme.Colors.border, lineWidth: AppTheme.Border.standard)
                            )

                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs + 2) {
                                Text("Enabled Reminder Stages")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)

                                ForEach(ReminderStage.allCases, id: \.rawValue) { stage in
                                    Toggle(stage.label, isOn: reminderToggleBinding(for: stage))
                                        .tint(AppTheme.Colors.accent)
                                }
                            }
                            .padding(AppTheme.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.inner, style: .continuous)
                                    .fill(AppTheme.Colors.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.Radius.inner, style: .continuous)
                                    .stroke(AppTheme.Colors.border, lineWidth: AppTheme.Border.standard)
                            )

                            if authorizationStatus != .authorized {
                                Button {
                                    Task {
                                        await notificationService.requestAuthorization()
                                        statusMessage = "Notification permission prompt requested."
                                        await refreshNotificationHealth()
                                    }
                                } label: {
                                    actionRow(icon: "bell.badge.fill", text: "Request Notification Permission")
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("settings.requestPermission")
                            }

                            if authorizationStatus == .denied {
                                Button {
                                    openSystemSettings()
                                } label: {
                                    actionRow(icon: "gearshape.fill", text: "Open iOS Settings")
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("settings.openSystemSettings")
                            }

                            Button {
                                Task {
                                    do {
                                        if isUITestMode {
                                            statusMessage = "Test notification simulated (UITest mode)."
                                        } else {
                                            try await notificationService.scheduleSelfTestNotification(after: 5)
                                            statusMessage = "Test notification scheduled for 5 seconds."
                                        }
                                    } catch {
                                        statusMessage = "Failed to schedule test notification: \(error.localizedDescription)"
                                    }
                                    await refreshNotificationHealth()
                                }
                            } label: {
                                actionRow(icon: "bell.and.waves.left.and.right.fill", text: "Send Test Notification (5s)")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("settings.sendTest")

                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                    Text("Use this only if reminder delivery looks out of sync.")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.Colors.textSecondary)

                                    Button {
                                        Task {
                                            await BillOperations.reconcileReminders(
                                                context: modelContext,
                                                notificationService: notificationService,
                                                now: .now,
                                                timeZone: .current
                                            )
                                            statusMessage = "Reminder schedules refreshed."
                                            await refreshNotificationHealth()
                                        }
                                    } label: {
                                        actionRow(icon: "arrow.clockwise", text: "Force Reminder Sync")
                                    }
                                    .buttonStyle(.bordered)
                                    .accessibilityIdentifier("settings.reconcile")
                                }
                                .padding(.top, AppTheme.Spacing.xs)
                            } label: {
                                Label("Advanced Notification Maintenance", systemImage: "wrench.and.screwdriver.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }
                    }

                    SectionCard(title: "Data Export", subtitle: "Create and share bill records in CSV format.") {
                        if entitlementState.hasAccess(to: .csvExport) {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                Button {
                                    do {
                                        exportURL = try prepareCSVExport()
                                        statusMessage = "CSV export is ready. Use Share to send it."
                                    } catch {
                                        statusMessage = "CSV export failed: \(error.localizedDescription)"
                                    }
                                } label: {
                                    actionRow(icon: "square.and.arrow.up.fill", text: "Generate CSV Export")
                                }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("settings.exportCSV")

                                if let exportURL {
                                    ShareLink(item: exportURL) {
                                        actionRow(icon: "paperplane.fill", text: "Share Last CSV Export")
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        } else {
                            UpgradeBanner(
                                title: "CSV export is Pro-only",
                                message: "Upgrade to export your bills for reporting and reconciliation.",
                                ctaTitle: "Unlock Export"
                            ) {
                                paywallEntryPoint = .settingsExport
                            }
                        }
                    }

                    SectionCard(title: "Backup & Restore", subtitle: "Protect local data and recover quickly on new devices.") {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            detailLine("Active Bills", "\(bills.filter(\.isActive).count)")
                            detailLine("Total Bills", "\(bills.count)")

                            Divider()
                                .overlay(AppTheme.Colors.hairline)

                            Button {
                                do {
                                    backupURL = try BackupService.exportBackup(context: modelContext)
                                    statusMessage = "Backup file generated. Use Share Backup File to save it."
                                } catch {
                                    statusMessage = "Backup generation failed: \(error.localizedDescription)"
                                }
                            } label: {
                                actionRow(icon: "archivebox.fill", text: "Create Full Backup")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("settings.createBackup")

                            if let backupURL {
                                ShareLink(item: backupURL) {
                                    actionRow(icon: "square.and.arrow.up", text: "Share Backup File")
                                }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("settings.shareBackup")
                            }

                            Button {
                                showingBackupImporter = true
                            } label: {
                                actionRow(icon: "arrow.clockwise.doc.on.clipboard", text: "Restore From Backup")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("settings.restoreBackup")
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
            .navigationTitle("Settings")
            .task {
                loadReminderStageSelections()
                await refreshNotificationHealth()
                await entitlementState.refresh()
            }
            .onChange(of: users.count) { _, _ in
                loadReminderStageSelections()
            }
            .onChange(of: reminderEvents.count) { _, _ in
                Task { await refreshNotificationHealth() }
            }
            .alert("Bill Due Tracker", isPresented: Binding(
                get: { statusMessage != nil },
                set: { if !$0 { statusMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(statusMessage ?? "")
            }
            .confirmationDialog(
                "Restore backup and replace all current local data?",
                isPresented: $showRestoreConfirmation,
                titleVisibility: .visible
            ) {
                Button("Restore", role: .destructive) {
                    guard let pendingRestoreURL else { return }
                    Task {
                        await restoreFromBackup(pendingRestoreURL)
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingRestoreURL = nil
                }
            } message: {
                Text("This action cannot be undone. Current local records will be replaced.")
            }
            .fileImporter(
                isPresented: $showingBackupImporter,
                allowedContentTypes: [UTType.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case let .success(urls):
                    guard let url = urls.first else { return }
                    pendingRestoreURL = url
                    showRestoreConfirmation = true
                case let .failure(error):
                    statusMessage = "Restore import failed: \(error.localizedDescription)"
                }
            }
            .sheet(item: $paywallEntryPoint) { entry in
                PaywallView(entryPoint: entry)
            }
        }
    }

    private func refreshNotificationHealth() async {
        authorizationStatus = await notificationService.authorizationStatus()

        let pendingRequests = await notificationService.pendingRequests()
        let reminderRequests = pendingRequests.filter { !$0.identifier.hasPrefix("reminder-self-test-") }
        earliestNextTrigger = reminderRequests
            .compactMap(notificationService.nextTriggerDate(from:))
            .sorted()
            .first

        pendingEventCount = reminderEvents.filter { $0.deliveryStatus == .pending }.count
    }

    private func loadReminderStageSelections() {
        let enabledStages = BillOperations.enabledReminderStages(context: modelContext)
        reminderStageSelections = Dictionary(
            uniqueKeysWithValues: ReminderStage.allCases.map { stage in
                (stage, enabledStages.contains(stage))
            }
        )
    }

    private func reminderToggleBinding(for stage: ReminderStage) -> Binding<Bool> {
        Binding(
            get: { reminderStageSelections[stage] ?? true },
            set: { isEnabled in
                reminderStageSelections[stage] = isEnabled
                Task {
                    await updateReminderPreference(stage: stage, enabled: isEnabled)
                }
            }
        )
    }

    private func updateReminderPreference(stage: ReminderStage, enabled: Bool) async {
        do {
            try BillOperations.setReminderStagePreference(
                stage: stage,
                enabled: enabled,
                context: modelContext
            )
            await BillOperations.reconcileReminders(
                context: modelContext,
                notificationService: notificationService,
                now: .now,
                timeZone: .current
            )
            await refreshNotificationHealth()
        } catch {
            statusMessage = "Unable to update reminder preferences: \(error.localizedDescription)"
            loadReminderStageSelections()
        }
    }

    private func actionRow(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(text)
            Spacer()
        }
        .font(.subheadline.weight(.semibold))
    }

    private func detailLine(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var renewalStatusText: String {
        guard entitlementState.isPro else {
            return "-"
        }

        guard let renewalDate = entitlementState.renewalDate else {
            return "Active"
        }
        return renewalDate.formatted(date: .abbreviated, time: .omitted)
    }

    private func prepareCSVExport() throws -> URL {
        try BillCSVExportService.writeCSV(for: bills)
    }

    private func restoreFromBackup(_ fileURL: URL) async {
        let isAccessible = fileURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessible {
                fileURL.stopAccessingSecurityScopedResource()
            }
            pendingRestoreURL = nil
        }

        do {
            let payload = try BackupService.payload(from: fileURL)
            let report = try await BackupService.restore(
                payload: payload,
                context: modelContext,
                notificationService: notificationService,
                subscriptionTier: entitlementState.tier
            )
            if report.deactivatedBillCount > 0 {
                statusMessage = "Restore complete: \(report.bills) bills, \(report.cycles) cycles, \(report.reminders) reminders. \(report.deactivatedBillCount) bill(s) were deactivated to match the Free plan limit."
            } else {
                statusMessage = "Restore complete: \(report.bills) bills, \(report.cycles) cycles, \(report.reminders) reminders."
            }
            await refreshNotificationHealth()
        } catch {
            statusMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func restorePurchasesFromSettings() async {
        guard !isRestoringPurchases else { return }
        isRestoringPurchases = true
        defer { isRestoringPurchases = false }

        do {
            try await entitlementState.restorePurchases()
            statusMessage = "Purchases restored successfully."
        } catch EntitlementError.noActiveSubscription {
            statusMessage = "No active subscription found for this Apple Account."
        } catch {
            statusMessage = "Restore purchases failed: \(error.localizedDescription)"
        }
    }

    private func authorizationLabel(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Authorized"
        case .provisional:
            return "Provisional"
        case .denied:
            return "Denied"
        case .ephemeral:
            return "Ephemeral"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

}

private enum ReminderFreshness {
    case healthy(String)
    case stale(String)
    case unknown(String)

    var message: String {
        switch self {
        case let .healthy(message), let .stale(message), let .unknown(message):
            return message
        }
    }

    var icon: String {
        switch self {
        case .healthy:
            return "checkmark.seal.fill"
        case .stale:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    var toneColor: Color {
        switch self {
        case .healthy:
            return AppTheme.Colors.paid
        case .stale:
            return AppTheme.Colors.dueSoon
        case .unknown:
            return AppTheme.Colors.accent
        }
    }

    var backgroundColor: Color {
        switch self {
        case .healthy:
            return AppTheme.Colors.toneFill(for: .paid)
        case .stale:
            return AppTheme.Colors.toneFill(for: .dueSoon)
        case .unknown:
            return AppTheme.Colors.toneFill(for: .accent)
        }
    }
}
