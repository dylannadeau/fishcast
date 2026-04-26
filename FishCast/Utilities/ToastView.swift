import SwiftUI

/// Brief banner overlay used to confirm successful actions ("Changes saved").
/// Apply via `.toast(_:isPresented:)` — the binding flips back to `false`
/// automatically after 2 seconds.
struct ToastView: View {
    let message: String
    let symbol: String

    init(message: String, symbol: String = "checkmark.circle.fill") {
        self.message = message
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentGold)
            Text(message)
                .font(.appCallout)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.secondaryBackground)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let message: String

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if isPresented {
                ToastView(message: message)
                    .padding(.top, Spacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        withAnimation(.appEaseOut) { isPresented = false }
                    }
            }
        }
        .animation(.appSpring, value: isPresented)
    }
}

extension View {
    /// Pin a "Changes saved"-style banner to the top of this view. Auto-
    /// dismisses after 2 seconds by flipping the binding back to `false`.
    func toast(_ message: String, isPresented: Binding<Bool>) -> some View {
        modifier(ToastModifier(isPresented: isPresented, message: message))
    }
}

#Preview {
    ZStack {
        Color.primaryBackground.ignoresSafeArea()
        ToastView(message: "Changes saved")
    }
}
