import SwiftUI

// MARK: - Animated Text Field Component

/// A text field with animated placeholder and border effects
public struct AnimatedTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)?
    
    @FocusState private var isFocused: Bool
    @State private var showPlaceholder = true
    @State private var borderAnimation = false
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    public init(
        placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        submitLabel: SubmitLabel = .done,
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.submitLabel = submitLabel
        self.onSubmit = onSubmit
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.none) {
            ZStack(alignment: .leading) {
                // Animated placeholder
                Text(placeholder)
                    .font(.system(size: Theme.FontSize.scalable(
                        showPlaceholder ? Theme.FontSize.base : Theme.FontSize.xs,
                        for: dynamicTypeSize
                    )))
                    .foregroundStyle(Theme.mutedFg)
                    .offset(y: showPlaceholder ? 0 : -Theme.Spacing.lg)
                    .scaleEffect(showPlaceholder ? 1.0 : 0.85, anchor: .leading)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showPlaceholder)
                
                HStack(spacing: Theme.Spacing.sm) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: Theme.FontSize.md))
                            .foregroundStyle(isFocused ? Theme.primary : Theme.mutedFg)
                            .animation(.easeInOut(duration: 0.2), value: isFocused)
                    }
                    
                    Group {
                        if isSecure {
                            SecureField("", text: $text)
                        } else {
                            TextField("", text: $text)
                                .keyboardType(keyboardType)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
                    .foregroundStyle(Theme.foreground)
                    .focused($isFocused)
                    .submitLabel(submitLabel)
                    .onSubmit {
                        onSubmit?()
                    }
                }
                .padding(.top, showPlaceholder ? Theme.Spacing.none : Theme.Spacing.md)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(isFocused ? Theme.inputFocus : Theme.input)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .strokeBorder(
                        LinearGradient(
                            colors: isFocused ? 
                                [Theme.primary, Theme.primary.opacity(0.5)] : 
                                [Theme.border, Theme.border],
                            startPoint: borderAnimation ? .trailing : .leading,
                            endPoint: borderAnimation ? .leading : .trailing
                        ),
                        lineWidth: isFocused ? Theme.Spacing.xxs : Theme.Spacing.xxs / 2
                    )
                    .animation(
                        isFocused ? 
                            .linear(duration: 2).repeatForever(autoreverses: true) : 
                            .default,
                        value: borderAnimation
                    )
            )
        }
        .accessibilityElement(
            label: placeholder,
            value: text.isEmpty ? "Empty" : text,
            hint: "Text field"
        )
        .onChange(of: text) { newValue in
            showPlaceholder = newValue.isEmpty && !isFocused
        }
        .onChange(of: isFocused) { focused in
            showPlaceholder = text.isEmpty && !focused
            borderAnimation = focused
        }
        .onAppear {
            showPlaceholder = text.isEmpty
        }
    }
}

// MARK: - Search Bar Component

public struct AnimatedSearchBar: View {
    @Binding var searchText: String
    var placeholder: String = "Search..."
    var onSearch: ((String) -> Void)?
    
    @FocusState private var isFocused: Bool
    @State private var isSearching = false
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    public init(
        searchText: Binding<String>,
        placeholder: String = "Search...",
        onSearch: ((String) -> Void)? = nil
    ) {
        self._searchText = searchText
        self.placeholder = placeholder
        self.onSearch = onSearch
    }
    
    public var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Theme.FontSize.md))
                .foregroundStyle(isFocused ? Theme.primary : Theme.mutedFg)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            TextField(placeholder, text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
                .foregroundStyle(Theme.foreground)
                .focused($isFocused)
                .submitLabel(.search)
                .onSubmit {
                    onSearch?(searchText)
                }
            
            if !searchText.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: Theme.FontSize.base))
                        .foregroundStyle(Theme.mutedFg)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            Capsule()
                .fill(isFocused ? Theme.inputFocus : Theme.input)
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    isFocused ? Theme.primary : Theme.border,
                    lineWidth: isFocused ? Theme.Spacing.xxs : Theme.Spacing.xxs / 2
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: !searchText.isEmpty)
        .accessibilityElement(
            label: "Search",
            value: searchText.isEmpty ? "Empty" : searchText,
            hint: placeholder
        )
    }
}

// MARK: - Preview Provider

struct AnimatedTextField_Previews: PreviewProvider {
    struct PreviewWrapper: View {
        @State private var text = ""
        @State private var password = ""
        @State private var email = ""
        @State private var searchText = ""
        
        var body: some View {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    AnimatedTextField(
                        placeholder: "Username",
                        text: $text,
                        icon: "person.fill"
                    )
                    
                    AnimatedTextField(
                        placeholder: "Password",
                        text: $password,
                        icon: "lock.fill",
                        isSecure: true
                    )
                    
                    AnimatedTextField(
                        placeholder: "Email",
                        text: $email,
                        icon: "envelope.fill",
                        keyboardType: .emailAddress
                    )
                    
                    AnimatedSearchBar(
                        searchText: $searchText,
                        placeholder: "Search messages..."
                    )
                }
                .padding()
            }
            .background(Theme.background)
        }
    }
    
    static var previews: some View {
        PreviewWrapper()
            .previewDisplayName("Animated Text Fields")
    }
}