import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct QuickAddBillView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlementState: EntitlementState
    @EnvironmentObject private var appNavigation: AppNavigationState

    let notificationService: ReminderNotificationService
    var billToEdit: BillItem?

    @State private var draft = BillDraft()
    @State private var useCustomProvider = false
    @State private var customProviderName = ""

    @State private var showingFileImporter = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var extractionMessage = ""
    @State private var extractionConfidence: ExtractionConfidence?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var paywallEntryPoint: PaywallEntryPoint?
    @State private var isHydratingExistingBill = false

    private var providers: [String] {
        BillOperations.providerNames(for: draft.category, context: modelContext)
    }

    private var resolvedProviderName: String {
        useCustomProvider ? customProviderName.trimmingCharacters(in: .whitespacesAndNewlines) : draft.providerName
    }

    private var requiresAnnualDueMonth: Bool {
        draft.category == .subscriptionDue && draft.billingCadence == .yearly
    }

    private var dueDateSelection: Binding<Date> {
        Binding(
            get: { resolvedDueDate() },
            set: { updateDraftDueDate(from: $0) }
        )
    }

    private var canUseExtractionAutomation: Bool {
        entitlementState.hasAccess(to: .extractionAutomation)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text(billToEdit == nil ? "Create Bill" : "Edit Bill")
                            .font(.headline)
                        Text("Set provider, due schedule, and reminders. You can attach OCR/PDF hints to speed entry.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)
                }

                Section("Bill Profile") {
                    Picker("Category", selection: $draft.category) {
                        ForEach(BillCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("quickadd.category")
                    .onChange(of: draft.category) { _, newCategory in
                        guard !isHydratingExistingBill else { return }
                        draft.providerName = BillOperations.providerNames(
                            for: newCategory,
                            context: modelContext
                        ).first ?? ""
                        if newCategory != .subscriptionDue {
                            draft.billingCadence = .monthly
                            draft.annualDueMonth = nil
                        } else if draft.billingCadence == .yearly, draft.annualDueMonth == nil {
                            draft.annualDueMonth = Calendar.gregorian.component(.month, from: .now)
                        }
                    }

                    Toggle("Use Custom Provider", isOn: $useCustomProvider)

                    if useCustomProvider {
                        TextField("Provider name", text: $customProviderName)
                            .textInputAutocapitalization(.words)
                    } else {
                        Picker("Provider", selection: $draft.providerName) {
                            ForEach(providers, id: \.self) { provider in
                                Text(provider).tag(provider)
                            }
                        }
                    }

                    TextField("Nickname (optional)", text: $draft.nickname)
                }

                Section("Schedule") {
                    if draft.category == .subscriptionDue {
                        Picker("Billing cadence", selection: $draft.billingCadence) {
                            ForEach(BillingCadence.allCases, id: \.rawValue) { cadence in
                                Text(cadence.title).tag(cadence)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("quickadd.cadence")
                    }

                    DatePicker("Due date", selection: dueDateSelection, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .accessibilityIdentifier("quickadd.dueDate")

                    if draft.category == .subscriptionDue, draft.billingCadence == .yearly {
                        Text("Yearly bills recur on \(monthName(for: draft.annualDueMonth)) \(draft.dueDay).")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .accessibilityIdentifier("quickadd.yearlyHint")
                    } else {
                        Text("Bills recur on day \(draft.dueDay) each month.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .accessibilityIdentifier("quickadd.monthlyHint")
                    }

                    Picker("Due day behavior", selection: $draft.dueDateRule) {
                        Text("End-of-month clamp").tag(DueDateRule.endOfMonthClamp)
                        Text("Fixed day").tag(DueDateRule.fixedDay)
                    }
                }

                Section("Payment Details") {
                    TextField("Expected amount (SGD)", text: $draft.expectedAmountText)
                        .keyboardType(.decimalPad)

                    Toggle("Autopay enabled", isOn: $draft.autopayEnabled)
                    if draft.autopayEnabled {
                        TextField("Autopay notes", text: $draft.autopayNote)
                    }
                }

                Section("Extract From Photo / PDF") {
                    if canUseExtractionAutomation {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Use Photo OCR", systemImage: "photo")
                        }

                        Button {
                            showingFileImporter = true
                        } label: {
                            Label("Use PDF", systemImage: "doc.text")
                        }
                    } else {
                        UpgradeBanner(
                            title: "OCR and PDF import is Pro-only",
                            message: "Auto-fill due day, provider, and amount from bill attachments.",
                            ctaTitle: "Unlock Pro"
                        ) {
                            paywallEntryPoint = .extraction
                        }
                    }

                    if !extractionMessage.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                            Text(extractionMessage)
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                            if let extractionConfidence {
                                StatusPill(
                                    label: "Confidence: \(extractionConfidence.rawValue)",
                                    tone: toneForConfidence(extractionConfidence)
                                )
                            }
                        }
                        .padding(.vertical, AppTheme.Spacing.xxs)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appScreenBackground()
            .navigationTitle(billToEdit == nil ? "Quick Add Bill" : "Edit Bill")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task { await save() }
                    }
                    .accessibilityIdentifier("quickadd.save")
                    .disabled(
                        isSaving ||
                        resolvedProviderName.isEmpty ||
                        (requiresAnnualDueMonth && draft.annualDueMonth == nil)
                    )
                    .fontWeight(.semibold)
                }
            }
            .alert("Unable to Save", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .sheet(item: $paywallEntryPoint) { entry in
                PaywallView(entryPoint: entry)
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                guard canUseExtractionAutomation else {
                    paywallEntryPoint = .extraction
                    return
                }

                switch result {
                case let .success(urls):
                    guard let url = urls.first else { return }
                    let accessible = url.startAccessingSecurityScopedResource()
                    defer {
                        if accessible {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    let extraction = BillExtractionService.extractFromPDF(url: url)
                    applyExtraction(extraction)
                case let .failure(error):
                    extractionMessage = "PDF import failed: \(error.localizedDescription)"
                    extractionConfidence = .low
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                guard canUseExtractionAutomation else {
                    paywallEntryPoint = .extraction
                    return
                }
                Task {
                    do {
                        guard let data = try await newItem.loadTransferable(type: Data.self) else { return }
                        let extraction = try await BillExtractionService.extractFromImageData(data)
                        applyExtraction(extraction)
                    } catch {
                        extractionMessage = "Image extraction failed: \(error.localizedDescription)"
                        extractionConfidence = .low
                    }
                }
            }
            .onChange(of: draft.billingCadence) { _, newCadence in
                guard draft.category == .subscriptionDue else { return }
                switch newCadence {
                case .monthly:
                    draft.annualDueMonth = nil
                case .yearly:
                    if draft.annualDueMonth == nil {
                        draft.annualDueMonth = Calendar.gregorian.component(.month, from: .now)
                    }
                }
            }
            .onAppear {
                if let billToEdit {
                    applyFromBill(billToEdit)
                } else if draft.providerName.isEmpty {
                    draft.providerName = providers.first ?? ""
                }
            }
        }
    }

    private func applyFromBill(_ bill: BillItem) {
        isHydratingExistingBill = true

        draft.category = bill.category
        draft.providerName = bill.providerName
        draft.nickname = bill.nickname
        draft.dueDay = bill.dueDay
        draft.dueDateRule = bill.dueDateRule
        draft.billingCadence = bill.billingCadence
        draft.annualDueMonth = bill.annualDueMonth
        draft.expectedAmountText = bill.expectedAmount.map { String(format: "%.2f", $0) } ?? ""
        draft.autopayEnabled = bill.autopayEnabled
        draft.autopayNote = bill.autopayNote

        let listed = BillOperations.providerNames(for: bill.category, context: modelContext)
        if listed.contains(where: { $0.caseInsensitiveCompare(bill.providerName) == .orderedSame }) {
            useCustomProvider = false
            customProviderName = ""
        } else {
            useCustomProvider = true
            customProviderName = bill.providerName
        }

        DispatchQueue.main.async {
            isHydratingExistingBill = false
        }
    }

    private func applyExtraction(_ extraction: BillExtractionResult) {
        extractionConfidence = extraction.confidence

        if let dueDay = extraction.dueDay {
            draft.dueDay = min(max(dueDay, 1), 31)
        }
        if let amount = extraction.amount {
            draft.expectedAmountText = String(format: "%.2f", amount)
        }
        if let provider = extraction.providerHint {
            let availableProviders = BillOperations.providerNames(for: draft.category, context: modelContext)
            if availableProviders.contains(where: { $0.caseInsensitiveCompare(provider) == .orderedSame }) {
                useCustomProvider = false
                draft.providerName = provider
            } else {
                useCustomProvider = true
                customProviderName = provider
            }
        }

        let summary = [
            extraction.dueDay.map { "due day \($0)" },
            extraction.amount.map { String(format: "amount %.2f", $0) },
            extraction.providerHint.map { "provider \($0)" }
        ]
            .compactMap { $0 }
            .joined(separator: ", ")

        extractionMessage = summary.isEmpty ? "No due date detected." : "Detected: \(summary)"
    }

    private func toneForConfidence(_ confidence: ExtractionConfidence) -> AppTone {
        switch confidence {
        case .high: return .paid
        case .medium: return .dueSoon
        case .low: return .overdue
        }
    }

    @MainActor
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        var didCreateBill = false
        var createdBill: BillItem?

        draft.providerName = resolvedProviderName

        do {
            if useCustomProvider {
                try BillOperations.saveCustomProvider(
                    resolvedProviderName,
                    for: draft.category,
                    context: modelContext
                )
            }

            if let billToEdit {
                try await BillOperations.updateBill(
                    billToEdit,
                    draft: draft,
                    context: modelContext,
                    notificationService: notificationService,
                    now: .now,
                    timeZone: .current
                )
            } else {
                let decision = UsageLimitService.canCreateBill(
                    tier: entitlementState.tier,
                    activeBillCount: activeBillCount()
                )
                guard decision.isAllowed else {
                    errorMessage = decision.message
                    paywallEntryPoint = .addBillLimit
                    return
                }

                createdBill = try await BillOperations.addBill(
                    draft: draft,
                    context: modelContext,
                    notificationService: notificationService,
                    now: .now,
                    timeZone: .current
                )
                didCreateBill = true
            }

            if didCreateBill {
                await notificationService.requestAuthorization()
                if let createdBill {
                    let selectedCycle = BillOperations.cycleForCurrentMonth(
                        bill: createdBill,
                        now: .now,
                        timeZone: .current
                    )
                    appNavigation.routeToBill(
                        BillNavigationTarget(
                            billID: createdBill.id,
                            cycleID: selectedCycle?.id
                        )
                    )
                }
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func activeBillCount() -> Int {
        let descriptor = FetchDescriptor<BillItem>(predicate: #Predicate<BillItem> { $0.isActive })
        let activeBills = (try? modelContext.fetch(descriptor)) ?? []
        return activeBills.count
    }

    private func resolvedDueDate() -> Date {
        let calendar = Calendar.gregorian
        let today = Date.now
        let year = calendar.component(.year, from: today)
        let fallbackMonth = calendar.component(.month, from: today)

        let month: Int
        if draft.category == .subscriptionDue, draft.billingCadence == .yearly {
            month = min(max(draft.annualDueMonth ?? fallbackMonth, 1), 12)
        } else {
            month = fallbackMonth
        }

        let baseDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? today
        let maxDay = calendar.range(of: .day, in: .month, for: baseDate)?.count ?? 31
        let safeDay = min(max(draft.dueDay, 1), maxDay)
        return calendar.date(from: DateComponents(year: year, month: month, day: safeDay)) ?? today
    }

    private func updateDraftDueDate(from date: Date) {
        let calendar = Calendar.gregorian
        draft.dueDay = calendar.component(.day, from: date)
        if draft.category == .subscriptionDue, draft.billingCadence == .yearly {
            draft.annualDueMonth = calendar.component(.month, from: date)
        }
    }

    private func monthName(for month: Int?) -> String {
        let formatter = DateFormatter()
        let fallbackMonth = Calendar.gregorian.component(.month, from: .now)
        let resolved = min(max(month ?? fallbackMonth, 1), 12)
        return formatter.monthSymbols[resolved - 1]
    }
}
