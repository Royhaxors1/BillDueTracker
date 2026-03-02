import SwiftUI

enum AppTheme {
    enum Colors {
        static let canvas = Color(uiColor: .systemGroupedBackground)
        static let surface = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? .secondarySystemGroupedBackground
                : .systemBackground
        })
        static let surfaceElevated = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? .tertiarySystemBackground
                : .secondarySystemBackground
        })
        static let accent = Color(uiColor: .systemBlue)

        static let textPrimary = Color(uiColor: .label)
        static let textSecondary = Color(uiColor: .secondaryLabel)
        static let textMuted = Color(uiColor: .tertiaryLabel)

        static let border = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.18)
                : UIColor.separator.withAlphaComponent(0.22)
        })
        static let hairline = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.10)
                : UIColor.separator.withAlphaComponent(0.14)
        })

        static let overdue = Color(uiColor: .systemRed)
        static let dueSoon = Color(uiColor: .systemOrange)
        static let paid = Color(uiColor: .systemGreen)
        static let neutral = Color(uiColor: .systemGray)

        static func tint(for tone: AppTone) -> Color {
            switch tone {
            case .overdue:
                return overdue
            case .dueSoon:
                return dueSoon
            case .paid:
                return paid
            case .neutral:
                return neutral
            case .accent:
                return accent
            }
        }

        static func toneFill(for tone: AppTone) -> Color {
            Color(uiColor: UIColor { trait in
                let alpha: CGFloat = trait.userInterfaceStyle == .dark ? 0.22 : 0.10
                return tintUIColor(for: tone).withAlphaComponent(alpha)
            })
        }

        private static func tintUIColor(for tone: AppTone) -> UIColor {
            switch tone {
            case .overdue:
                return .systemRed
            case .dueSoon:
                return .systemOrange
            case .paid:
                return .systemGreen
            case .neutral:
                return .systemGray
            case .accent:
                return .systemBlue
            }
        }
    }

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let pill: CGFloat = 999
        static let inner: CGFloat = 12
        static let card: CGFloat = 16
        static let section: CGFloat = 20
        static let sheet: CGFloat = 24
    }

    enum Border {
        static let standard: CGFloat = 1
        static let elevated: CGFloat = 1.2
        static let emphasis: CGFloat = 1.25
    }
}

enum AppTone {
    case overdue
    case dueSoon
    case paid
    case neutral
    case accent
}

extension View {
    func appScreenBackground() -> some View {
        modifier(AppScreenBackgroundModifier())
    }

    func appElevatedCard(cornerRadius: CGFloat, borderWidth: CGFloat = AppTheme.Border.elevated) -> some View {
        modifier(AppElevatedCardModifier(cornerRadius: cornerRadius, borderWidth: borderWidth))
    }
}

private struct AppScreenBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.background(
            ZStack {
                AppTheme.Colors.canvas
                if colorScheme == .dark {
                    LinearGradient(
                        colors: [
                            AppTheme.Colors.accent.opacity(0.14),
                            AppTheme.Colors.canvas.opacity(0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(0.28)
                }
            }
            .ignoresSafeArea()
        )
    }
}

private struct AppElevatedCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat
    let borderWidth: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.46) : Color.black.opacity(0.08),
                radius: colorScheme == .dark ? 14 : 10,
                x: 0,
                y: colorScheme == .dark ? 8 : 4
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.Colors.border, lineWidth: borderWidth)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(colorScheme == .dark ? AppTheme.Colors.hairline : Color.clear, lineWidth: 0.9)
            )
    }
}
