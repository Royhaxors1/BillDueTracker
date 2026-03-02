import PhotosUI
import QuickLook
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct BillDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let bill: BillItem
    let notificationService: ReminderNotificationService
    let attachmentStore: AttachmentStore
    var initialCycleID: UUID?

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingFileImporter = false
    @State private var showEditSheet = false
    @State private var errorMessage: String?
    @State private var showDeleteBillConfirmation = false
    @State private var lifecycleActionInFlight = false
    @State private var previewURL: URL?
    @State private var proofPendingDeletion: PaymentProof?

    private var selectedCycle: BillCycle? {
        if let initialCycleID,
           let targeted = bill.cycles.first(where: { $0.id == initialCycleID }) {
            return targeted
        }
        return BillOperations.cycleForCurrentMonth(bill: bill, now: .now, timeZone: .current)
    }

    private var providerActions: [ProviderAction] {
        let categoryRaw = bill.category.rawValue
        let providerName = bill.providerName
        let countryCode = "SG"

        let descriptor = FetchDescriptor<ProviderAction>(
            predicate: #Predicate {
                $0.categoryRaw == categoryRaw &&
                $0.providerName == providerName &&
                $0.countryCode == countryCode &&
                $0.isActive
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                SectionCard(title: "Summary", subtitle: "Core bill profile and cadence.") {
                    summaryContent
                }

                if let selectedCycle {
                    SectionCard(title: "Current Cycle", subtitle: "Payment state and due timing.") {
                        cycleContent(selectedCycle)
                    }

                    SectionCard(title: "Reminders", subtitle: "Scheduled nudges for this cycle.") {
                        remindersContent(selectedCycle)
                    }

                    SectionCard(title: "Payment Proofs", subtitle: "Attach supporting payment evidence.") {
                        proofsContent(selectedCycle)
                    }
                }

                SectionCard(title: "Lifecycle", subtitle: "Manage whether this bill is tracked and reminded.") {
                    lifecycleContent
                }

                if !providerActions.isEmpty {
                    SectionCard(title: "Action Links", subtitle: "Open provider portals quickly.") {
                        providerActionContent
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.top, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
        .appScreenBackground()
        .navigationTitle(bill.displayName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showEditSheet = true
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            QuickAddBillView(
                notificationService: notificationService,
                billToEdit: bill
            )
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [UTType.pdf],
            allowsMultipleSelection: false
        ) { result in
            guard let selectedCycle else { return }
            switch result {
            case let .success(urls):
                guard let sourceURL = urls.first else { return }
                let accessible = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if accessible {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let copiedURL = try attachmentStore.copy(from: sourceURL)
                    try BillOperations.addPaymentProof(cycle: selectedCycle, localFileURL: copiedURL, context: modelContext)
                } catch {
                    errorMessage = error.localizedDescription
                }
            case let .failure(error):
                errorMessage = error.localizedDescription
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let selectedCycle, let newItem else { return }
            Task {
                do {
                    guard let data = try await newItem.loadTransferable(type: Data.self) else { return }
                    let storedURL = try attachmentStore.store(data: data, fileExtension: "jpg")
                    try BillOperations.addPaymentProof(cycle: selectedCycle, localFileURL: storedURL, context: modelContext)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
        .alert("Action Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .sheet(isPresented: Binding(
            get: { previewURL != nil },
            set: { isPresented in
                if !isPresented { previewURL = nil }
            }
        )) {
            if let previewURL {
                ProofQuickLookPreview(url: previewURL)
            }
        }
        .alert("Delete this bill and all cycle records?", isPresented: $showDeleteBillConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Bill", role: .destructive) {
                Task { await deleteBill() }
            }
        } message: {
            Text("This cannot be undone.")
        }
        .confirmationDialog(
            "Delete this proof?",
            isPresented: Binding(
                get: { proofPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        proofPendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Proof", role: .destructive) {
                deletePendingProof()
            }
            Button("Cancel", role: .cancel) {
                proofPendingDeletion = nil
            }
        } message: {
            Text("The attached file will be removed from this device.")
        }
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            detailLine("Category", bill.category.title)
            detailLine("Provider", bill.providerName)
            detailLine("Due Day", "\(bill.dueDay)")
            if bill.category == .subscriptionDue {
                detailLine("Cadence", bill.billingCadence.title)
                if bill.billingCadence == .yearly {
                    detailLine("Due Month", monthName(for: bill.annualDueMonth))
                }
            }
            if let amount = bill.expectedAmount {
                detailLine("Expected Amount", String(format: "%@ %.2f", bill.currency, amount))
            }
            detailLine("Autopay", bill.autopayEnabled ? "On" : "Off")
            if bill.autopayEnabled, !bill.autopayNote.isEmpty {
                Text(bill.autopayNote)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding(.top, AppTheme.Spacing.xxs)
            }
        }
    }

    private func cycleContent(_ cycle: BillCycle) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            detailLine("Month", cycle.cycleMonth)
            detailLine("Due", cycle.dueDate.formatted(date: .abbreviated, time: .shortened))

            HStack {
                Text("Status")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Spacer()
                StatusPill(
                    label: cycle.paymentState == .paid ? "Paid" : "Unpaid",
                    tone: cycle.paymentState == .paid ? .paid : (cycle.overdueStartedAt != nil ? .overdue : .dueSoon)
                )
            }

            if cycle.paymentState == .paid {
                PrimaryActionButton(title: "Marked Paid", systemImage: "checkmark") {}
                    .disabled(true)
                    .opacity(0.65)
            } else {
                PrimaryActionButton(title: "Mark Paid", systemImage: "checkmark.circle.fill") {
                    markPaid(cycle)
                }
            }
        }
    }

    private func remindersContent(_ cycle: BillCycle) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if cycle.reminderEvents.isEmpty {
                Text("No pending reminders.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(cycle.reminderEvents.sorted(by: { $0.scheduledAt < $1.scheduledAt })) { event in
                    ReminderRowView(event: event)
                }
            }
        }
    }

    private func proofsContent(_ cycle: BillCycle) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Button {
                    showingFileImporter = true
                } label: {
                    Label("Attach PDF", systemImage: "doc.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Attach Photo", systemImage: "photo.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }

            if cycle.proofs.isEmpty {
                Text("No proofs attached.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(cycle.proofs.sorted(by: { $0.uploadedAt > $1.uploadedAt })) { proof in
                        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                Text(proof.fileURL?.lastPathComponent ?? "Proof")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.textPrimary)
                                Text(proof.uploadedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: AppTheme.Spacing.xs) {
                                if let fileURL = proof.fileURL {
                                    Button("Preview") {
                                        previewURL = fileURL
                                    }
                                    .font(.caption.weight(.semibold))
                                    .buttonStyle(.bordered)

                                    ShareLink(item: fileURL) {
                                        Text("Share")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                }

                                Button("Delete") {
                                    proofPendingDeletion = proof
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.bordered)
                                .tint(AppTheme.Colors.overdue)
                            }
                        }
                        .padding(AppTheme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.inner, style: .continuous)
                                .fill(AppTheme.Colors.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.inner, style: .continuous)
                                .stroke(AppTheme.Colors.border, lineWidth: AppTheme.Border.standard)
                        )
                    }
                }
            }
        }
    }

    private var lifecycleContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            detailLine("Tracking", bill.isActive ? "Active" : "Inactive")

            if bill.isActive {
                Button {
                    Task { await setBillActive(false) }
                } label: {
                    actionRow(icon: "pause.circle.fill", title: lifecycleActionInFlight ? "Archiving..." : "Archive Bill")
                }
                .buttonStyle(.bordered)
                .disabled(lifecycleActionInFlight)
            } else {
                Button {
                    Task { await setBillActive(true) }
                } label: {
                    actionRow(icon: "play.circle.fill", title: lifecycleActionInFlight ? "Reactivating..." : "Reactivate Bill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(lifecycleActionInFlight)
            }

            Button(role: .destructive) {
                showDeleteBillConfirmation = true
            } label: {
                actionRow(icon: "trash.fill", title: "Delete Bill")
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.overdue)
            .accessibilityIdentifier("billdetail.deleteBill")
            .disabled(lifecycleActionInFlight)
        }
    }

    private var providerActionContent: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ForEach(providerActions) { action in
                if let url = action.url {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "arrow.up.right.square.fill")
                                .foregroundStyle(AppTheme.Colors.accent)
                            Text(action.actionLabel)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Spacer()
                        }
                        .padding(AppTheme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.inner, style: .continuous)
                                .fill(AppTheme.Colors.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.inner, style: .continuous)
                                .stroke(AppTheme.Colors.border, lineWidth: AppTheme.Border.standard)
                        )
                    }
                }
            }
        }
    }

    private func setBillActive(_ isActive: Bool) async {
        guard !lifecycleActionInFlight else { return }
        lifecycleActionInFlight = true
        defer { lifecycleActionInFlight = false }

        do {
            try await BillOperations.setBillActive(
                bill,
                isActive: isActive,
                context: modelContext,
                notificationService: notificationService,
                now: .now,
                timeZone: .current
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteBill() async {
        guard !lifecycleActionInFlight else { return }
        lifecycleActionInFlight = true
        defer { lifecycleActionInFlight = false }

        do {
            for cycle in bill.cycles {
                for proof in cycle.proofs {
                    if let fileURL = proof.fileURL {
                        try? attachmentStore.removeFileIfExists(at: fileURL)
                    }
                }
            }

            try BillOperations.deleteBill(
                bill,
                context: modelContext,
                notificationService: notificationService
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deletePendingProof() {
        guard let proof = proofPendingDeletion else { return }
        if let fileURL = proof.fileURL {
            do {
                try attachmentStore.removeFileIfExists(at: fileURL)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        modelContext.delete(proof)
        do {
            try modelContext.save()
            proofPendingDeletion = nil
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func actionRow(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
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

    private func markPaid(_ cycle: BillCycle) {
        do {
            try BillOperations.markPaid(
                cycle: cycle,
                context: modelContext,
                notificationService: notificationService,
                now: .now
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func monthName(for value: Int?) -> String {
        guard let value, (1...12).contains(value) else { return "-" }
        return DateFormatter().monthSymbols[value - 1]
    }
}

private struct ProofQuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.url = url
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(
            _ controller: QLPreviewController,
            previewItemAt index: Int
        ) -> QLPreviewItem {
            url as NSURL
        }
    }
}
