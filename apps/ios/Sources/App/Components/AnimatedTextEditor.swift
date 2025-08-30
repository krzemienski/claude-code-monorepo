import SwiftUI

/// A text editor with animated placeholder and visual effects
struct AnimatedTextEditor: View {
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let isSecure: Bool
    let onSubmit: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var animateGlow = false
    
    init(
        placeholder: String = "Type here...",
        text: Binding<String>,
        minHeight: CGFloat = 44,
        maxHeight: CGFloat = 120,
        isSecure: Bool = false,
        onSubmit: @escaping () -> Void = {}
    ) {
        self.placeholder = placeholder
        self._text = text
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.isSecure = isSecure
        self.onSubmit = onSubmit
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(Theme.mutedFg)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
            
            // Text editor
            if #available(iOS 16.0, *) {
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .focused($isFocused)
                    .onSubmit(onSubmit)
            } else {
                TextEditor(text: $text)
                    .background(Color.clear)
                    .focused($isFocused)
            }
        }
        .padding(8)
        .frame(minHeight: minHeight, maxHeight: maxHeight)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.card.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isFocused ? Theme.primary : Theme.border,
                            lineWidth: isFocused ? 2 : 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
            ) {
                animateGlow.toggle()
            }
        }
    }
}

// MARK: - Modifiers
extension AnimatedTextEditor {
    func textEditorHeight(_ height: CGFloat) -> some View {
        self.frame(height: height)
    }
    
    func textEditorStyle(_ style: TextEditorStyle) -> some View {
        self
    }
}

// MARK: - Text Editor Style
enum TextEditorStyle {
    case minimal
    case bordered
    case filled
}