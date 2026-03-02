import SwiftUI

struct SectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            content()
        }
        .padding(AppTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.section, style: .continuous)
                .fill(AppTheme.Colors.surface)
        )
        .appElevatedCard(cornerRadius: AppTheme.Radius.section, borderWidth: 1.2)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String
    let tone: AppTone

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.tint(for: tone))

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .contentTransition(.numericText())

            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .fill(AppTheme.Colors.surface)
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .fill(AppTheme.Colors.toneFill(for: tone))
            }
        )
        .appElevatedCard(cornerRadius: AppTheme.Radius.card, borderWidth: 1.25)
    }
}

struct StatusPill: View {
    @Environment(\.colorScheme) private var colorScheme

    let label: String
    let tone: AppTone

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, AppTheme.Spacing.xs)
            .padding(.vertical, AppTheme.Spacing.xxs + 1)
            .foregroundStyle(AppTheme.Colors.tint(for: tone))
            .background(AppTheme.Colors.tint(for: tone).opacity(colorScheme == .dark ? 0.32 : 0.16))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.Colors.tint(for: tone).opacity(colorScheme == .dark ? 0.46 : 0.25), lineWidth: 1)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Status: \(label)")
    }
}

struct EmptyStateCard: View {
    let title: String
    let message: String
    let actionTitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.accent)
                .padding(AppTheme.Spacing.sm)
                .background(AppTheme.Colors.accent.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            PrimaryActionButton(title: actionTitle, systemImage: "plus") {
                action()
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.section, style: .continuous)
                .fill(AppTheme.Colors.surface)
        )
        .appElevatedCard(cornerRadius: AppTheme.Radius.section, borderWidth: 1.2)
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    init(title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .foregroundStyle(.white)
            .background(AppTheme.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct SwipeToDeleteContainer<Content: View>: View {
    let onDelete: () -> Void
    var actionAccessibilityIdentifier: String?
    @ViewBuilder let content: () -> Content

    @State private var contentOffset: CGFloat = 0
    @State private var isOpen = false
    @State private var isHorizontalDrag = false

    private let actionWidth: CGFloat = 92
    private let openThreshold: CGFloat = 36

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive, action: onDelete) {
                VStack(spacing: AppTheme.Spacing.xxs) {
                    Image(systemName: "trash.fill")
                    Text("Delete")
                        .font(.caption.weight(.semibold))
                }
                .frame(width: actionWidth)
                .frame(maxHeight: .infinity)
                .foregroundStyle(.white)
                .background(AppTheme.Colors.overdue)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.leading, AppTheme.Spacing.sm)
            .modifier(ConditionalAccessibilityIdentifier(identifier: actionAccessibilityIdentifier))

            content()
                .contentShape(Rectangle())
                .offset(x: contentOffset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            let horizontalDistance = abs(value.translation.width)
                            let verticalDistance = abs(value.translation.height)
                            if !isHorizontalDrag, horizontalDistance > verticalDistance {
                                isHorizontalDrag = true
                            }
                            guard isHorizontalDrag else { return }

                            let baseline = isOpen ? -actionWidth : 0
                            let nextOffset = baseline + value.translation.width
                            contentOffset = min(0, max(-actionWidth, nextOffset))
                        }
                        .onEnded { value in
                            defer { isHorizontalDrag = false }
                            guard isHorizontalDrag else { return }

                            let predicted = (isOpen ? -actionWidth : 0) + value.predictedEndTranslation.width
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                                if predicted < -openThreshold {
                                    contentOffset = -actionWidth
                                    isOpen = true
                                } else {
                                    contentOffset = 0
                                    isOpen = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    guard isOpen else { return }
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.88)) {
                        contentOffset = 0
                        isOpen = false
                    }
                }
        }
        .clipped()
    }
}

private struct ConditionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier, !identifier.isEmpty {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
