import SwiftUI

struct ReminderRowView: View {
    let event: ReminderEvent

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(event.stage.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(event.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()
            StatusPill(label: deliveryLabel, tone: deliveryTone)
        }
        .padding(AppTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.inner, style: .continuous)
                .fill(AppTheme.Colors.surface)
        )
        .appElevatedCard(cornerRadius: AppTheme.Radius.inner, borderWidth: AppTheme.Border.elevated)
    }

    private var deliveryTone: AppTone {
        switch event.deliveryStatus {
        case .sent:
            return .paid
        case .failed:
            return .overdue
        case .cancelled:
            return .neutral
        case .pending:
            if event.stage == .overdue {
                return .overdue
            }
            return .dueSoon
        }
    }

    private var deliveryLabel: String {
        switch event.deliveryStatus {
        case .pending:
            return "Scheduled"
        case .sent:
            return "Sent"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }
}
