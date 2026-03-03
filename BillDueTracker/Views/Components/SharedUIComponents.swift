import SwiftUI
import UIKit

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
        .appElevatedCard(cornerRadius: AppTheme.Radius.section, borderWidth: AppTheme.Border.elevated)
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
        .appElevatedCard(cornerRadius: AppTheme.Radius.card, borderWidth: AppTheme.Border.emphasis)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
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
                    .stroke(
                        AppTheme.Colors.tint(for: tone).opacity(colorScheme == .dark ? 0.46 : 0.25),
                        lineWidth: AppTheme.Border.standard
                    )
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
    @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 34

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .semibold))
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
        .appElevatedCard(cornerRadius: AppTheme.Radius.section, borderWidth: AppTheme.Border.elevated)
    }
}

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var minButtonHeight: CGFloat = 44

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
            .frame(minHeight: minButtonHeight)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .foregroundStyle(.white)
            .background(AppTheme.Colors.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct SwipeToDeleteContainer<Content: View>: View {
    let onDelete: () -> Void
    var actionAccessibilityIdentifier: String?
    @ViewBuilder let content: () -> Content

    @State private var contentOffset: CGFloat = 0
    @State private var isOpen = false
    @State private var isHorizontalDrag = false
    @State private var crossedOpenThreshold = false

    private let actionWidth: CGFloat = 96
    private let openThreshold: CGFloat = 38
    private let closeThreshold: CGFloat = 58
    private let dragDamping: CGFloat = 0.28
    private let revealStartThreshold: CGFloat = 0.12
    private let settleAnimation = Animation.spring(response: 0.26, dampingFraction: 0.86)

    private var revealProgress: CGFloat {
        min(1, max(0, -contentOffset / actionWidth))
    }

    private var visibleRevealProgress: CGFloat {
        guard revealProgress > revealStartThreshold else { return 0 }
        return min(1, (revealProgress - revealStartThreshold) / (1 - revealStartThreshold))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive, action: onDelete) {
                VStack(spacing: AppTheme.Spacing.xs) {
                    Image(systemName: "trash.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.14 * visibleRevealProgress))
                        .clipShape(Circle())
                    Text("Delete")
                        .font(.caption.weight(.bold))
                }
                .frame(width: actionWidth)
                .frame(maxHeight: .infinity)
                .foregroundStyle(.white.opacity(visibleRevealProgress))
                .background(AppTheme.Colors.overdue.opacity(visibleRevealProgress))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
                .scaleEffect(0.92 + (0.08 * visibleRevealProgress))
                .animation(.easeOut(duration: 0.16), value: visibleRevealProgress)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(isOpen)
            .modifier(ConditionalAccessibilityIdentifier(identifier: actionAccessibilityIdentifier))
            .accessibilitySortPriority(0)

            content()
                .contentShape(Rectangle())
                .offset(x: contentOffset)
                .accessibilitySortPriority(1)
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
                            let rawOffset = baseline + value.translation.width
                            contentOffset = dampedOffset(rawOffset)
                            updateThresholdFeedback()
                        }
                        .onEnded { value in
                            defer { isHorizontalDrag = false }
                            guard isHorizontalDrag else { return }

                            let baseline = isOpen ? -actionWidth : 0
                            let predicted = dampedOffset(baseline + value.predictedEndTranslation.width)
                            settle(toOpen: shouldSettleOpen(for: predicted))
                        }
                )
                .onTapGesture {
                    guard isOpen else { return }
                    settle(toOpen: false)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private func shouldSettleOpen(for predictedOffset: CGFloat) -> Bool {
        if isOpen {
            return predictedOffset < -closeThreshold
        }
        return predictedOffset < -openThreshold
    }

    private func settle(toOpen shouldOpen: Bool) {
        crossedOpenThreshold = false
        withAnimation(settleAnimation) {
            contentOffset = shouldOpen ? -actionWidth : 0
            isOpen = shouldOpen
        }
    }

    private func dampedOffset(_ rawOffset: CGFloat) -> CGFloat {
        if rawOffset > 0 {
            return rawOffset * dragDamping
        }
        if rawOffset < -actionWidth {
            let overDrag = rawOffset + actionWidth
            return -actionWidth + (overDrag * dragDamping)
        }
        return rawOffset
    }

    private func updateThresholdFeedback() {
        let hasCrossed = contentOffset <= -openThreshold
        if hasCrossed, !crossedOpenThreshold {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.8)
        }
        crossedOpenThreshold = hasCrossed
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
