import SwiftUI

struct UpgradeBanner: View {
    let title: String
    let message: String
    let ctaTitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Label("Pro", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.accent)

            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Button(action: action) {
                HStack {
                    Text(ctaTitle)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.accent)
            .controlSize(.large)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .fill(AppTheme.Colors.surfaceElevated)
        )
        .appElevatedCard(cornerRadius: AppTheme.Radius.card, borderWidth: 1.2)
    }
}
