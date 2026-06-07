import SwiftUI

// MARK: - GAGAAvatar

struct GAGAAvatar: View {
    let url: String?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                CachedAsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(GAGATheme.accentGradient, lineWidth: GAGATheme.avatarRingWidth)
        }
    }

    private var placeholder: some View {
        Circle()
            .fill(.gray.opacity(0.2))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.gray)
            }
    }
}

// MARK: - GAGAButton

struct GAGAButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(GAGATheme.headlineFont)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(GAGATheme.accentGradient, in: RoundedRectangle(cornerRadius: GAGATheme.buttonRadius))
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - GAGACard Modifier

struct GAGACardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: GAGATheme.cardRadius)
                    .fill(colorScheme == .dark ? Color(white: 0.12) : .white)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            }
    }
}

extension View {
    func gagaCard() -> some View {
        modifier(GAGACardModifier())
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Gradient Ring Modifier

struct GradientRingModifier: ViewModifier {
    var lineWidth: CGFloat = 2.5

    func body(content: Content) -> some View {
        content
            .overlay {
                Circle()
                    .stroke(GAGATheme.accentGradient, lineWidth: lineWidth)
            }
    }
}

// MARK: - GAGATextField

struct GAGATextField: View {
    let label: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var lineLimit: ClosedRange<Int> = 1...1

    var body: some View {
        VStack(alignment: .leading, spacing: GAGATheme.spacingSM) {
            Text(label)
                .font(GAGATheme.captionFont)
                .foregroundStyle(.secondary)
            TextField(label, text: $text, axis: axis)
                .lineLimit(lineLimit)
                .font(GAGATheme.bodyFont)
                .padding(12)
                .background(.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Skeleton Modifier

struct GAGASkeletonModifier: ViewModifier {
    var isLoading: Bool
    @State private var shimmerOffset: CGFloat = -1

    func body(content: Content) -> some View {
        if isLoading {
            content
                .redacted(reason: .placeholder)
                .overlay {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: shimmerOffset * geo.size.width)
                        .onAppear {
                            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                shimmerOffset = 1.5
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: GAGATheme.cardRadius))
                }
        } else {
            content
        }
    }
}

extension View {
    func gagaSkeleton(_ isLoading: Bool) -> some View {
        modifier(GAGASkeletonModifier(isLoading: isLoading))
    }
}

// MARK: - Toast

struct GAGAToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let msg = message {
                Text(msg)
                    .font(GAGATheme.captionFont)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, GAGATheme.spacingMD)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay { Capsule().stroke(GAGATheme.accentGradient, lineWidth: 1) }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, GAGATheme.spacingSM)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { message = nil }
                        }
                    }
            }
        }
        .animation(GAGATheme.springSnappy, value: message)
    }
}

extension View {
    func gagaToast(_ message: Binding<String?>) -> some View {
        modifier(GAGAToastModifier(message: message))
    }
}

// MARK: - Stagger Animation

struct StaggerAnimationModifier: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(GAGATheme.springBounce.delay(Double(index) * 0.08)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func gagaStagger(index: Int) -> some View {
        modifier(StaggerAnimationModifier(index: index))
    }
}

// MARK: - Heart Bounce

struct HeartBounceView: View {
    let isLiked: Bool
    let count: Int
    let action: () -> Void

    @State private var bouncing = false

    var body: some View {
        Button(action: {
            bouncing.toggle()
            action()
        }) {
            HStack(spacing: GAGATheme.spacingXS) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .foregroundStyle(isLiked ? GAGATheme.coral : .secondary)
                    .symbolEffect(.bounce, value: bouncing)
                if count > 0 {
                    Text("\(count)")
                        .font(GAGATheme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct GAGAEmptyState: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    var ctaTitle: LocalizedStringKey? = nil
    var ctaAction: (() -> Void)? = nil

    @State private var floating = false

    var body: some View {
        VStack(spacing: GAGATheme.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(GAGATheme.accentGradient)
                .offset(y: floating ? -6 : 6)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: floating)
                .onAppear { floating = true }

            Text(title)
                .font(GAGATheme.headlineFont)

            Text(description)
                .font(GAGATheme.captionFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let ctaTitle, let ctaAction {
                GAGAButton(title: ctaTitle, action: ctaAction)
                    .padding(.horizontal, GAGATheme.spacingXL)
                    .padding(.top, GAGATheme.spacingSM)
            }
        }
        .padding(GAGATheme.spacingXL)
    }
}
