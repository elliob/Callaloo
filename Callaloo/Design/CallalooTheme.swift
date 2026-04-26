//
//  CallalooTheme.swift
//  Callaloo
//

import SwiftUI

enum CallalooTheme {
    static let cornerRadiusLarge: CGFloat = 16
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 10
    static let contentMaxWidth: CGFloat = 400
    static let sectionSpacing: CGFloat = 20
}

extension View {
    /// Soft branded backdrop for full-screen flows (sign-in, onboarding).
    func callalooAuthBackground() -> some View {
        background {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.14),
                    Color(.systemGroupedBackground),
                    Color(.systemGroupedBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    /// Standard chrome behind grouped / inset lists.
    func callalooListBackground() -> some View {
        background {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        }
    }

    /// Elevated surface for cards and bottom bars.
    func callalooCardSurface(cornerRadius: CGFloat = CallalooTheme.cornerRadiusMedium) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
    }
}

struct CallalooPrimaryCTAButtonStyle: ButtonStyle {
    var isLoading: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            }
            configuration.label
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusMedium, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.82)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(configuration.isPressed ? 0.88 : 1)
        }
        .foregroundStyle(.white)
    }
}

struct CallalooSecondaryCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1.5)
                    .background {
                        RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusMedium, style: .continuous)
                            .fill(Color.accentColor.opacity(configuration.isPressed ? 0.12 : 0.06))
                    }
            }
            .foregroundStyle(Color.accentColor)
    }
}
