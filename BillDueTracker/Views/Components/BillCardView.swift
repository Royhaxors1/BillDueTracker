import SwiftUI

struct BillCardView: View {
    let bill: BillItem
    let cycle: BillCycle?
    let showContainer: Bool
    @ScaledMetric(relativeTo: .body) private var categoryIconSize: CGFloat = 32

    init(bill: BillItem, cycle: BillCycle?, showContainer: Bool = true) {
        self.bill = bill
        self.cycle = cycle
        self.showContainer = showContainer
    }

    var body: some View {
        Group {
            if showContainer {
                cardContent
                    .padding(AppTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                            .fill(AppTheme.Colors.surface)
                    )
                    .appElevatedCard(cornerRadius: AppTheme.Radius.card, borderWidth: AppTheme.Border.elevated)
            } else {
                cardContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var cardContent: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: bill.category.symbolName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tint(for: tone))
                .frame(width: categoryIconSize, height: categoryIconSize)
                .background(AppTheme.Colors.tint(for: tone).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.inner - 2, style: .continuous))

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(bill.displayName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .lineLimit(1)

                Text(bill.providerName)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)

                if let cycle {
                    Text(dueLine(for: cycle))
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                }
            }

            Spacer(minLength: AppTheme.Spacing.sm)

            VStack(alignment: .trailing, spacing: AppTheme.Spacing.xs) {
                StatusPill(label: statusText, tone: tone)

                if let amount = bill.expectedAmount {
                    Text(String(format: "%@ %.2f", bill.currency, amount))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
        }
    }

    private var statusText: String {
        switch effectiveStatus {
        case .active:
            return "Active"
        case .paidCurrentCycle:
            return "Paid"
        case .overdue:
            return "Overdue"
        case .paused:
            return "Paused"
        }
    }

    private var tone: AppTone {
        switch effectiveStatus {
        case .overdue:
            return .overdue
        case .paidCurrentCycle:
            return .paid
        case .active:
            if let cycle, cycle.dueDate <= Date().addingTimeInterval(7 * 24 * 60 * 60) {
                return .dueSoon
            }
            return .accent
        case .paused:
            return .neutral
        }
    }

    private var effectiveStatus: BillStatus {
        guard bill.isActive else { return .paused }
        guard let cycle else { return bill.currentStatus }
        if cycle.paymentState == .paid { return .paidCurrentCycle }
        if cycle.overdueStartedAt != nil { return .overdue }
        return .active
    }

    private func dueLine(for cycle: BillCycle) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Due \(formatter.string(from: cycle.dueDate))"
    }

    private var accessibilitySummary: String {
        let provider = bill.providerName
        let status = statusText
        if let cycle {
            let dueDate = cycle.dueDate.formatted(date: .abbreviated, time: .omitted)
            return "\(bill.displayName), \(provider), \(status), due \(dueDate)"
        }
        return "\(bill.displayName), \(provider), \(status)"
    }
}
