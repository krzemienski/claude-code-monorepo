import SwiftUI

/// ComponentLibrary - Centralized reusable UI components with consistent styling
public enum ComponentLibrary {
    
    // MARK: - Buttons
    public struct PrimaryButton: View {
        let title: String
        let icon: String?
        let action: () -> Void
        let isLoading: Bool
        
        public init(
            _ title: String,
            icon: String? = nil,
            isLoading: Bool = false,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.icon = icon
            self.isLoading = isLoading
            self.action = action
        }
        
        public var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else if let icon = icon {
                        Image(systemName: icon)
                    }
                    
                    Text(title)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.primary)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(isLoading)
            .buttonStyle(.plain)
        }
    }
    
    public struct SecondaryButton: View {
        let title: String
        let icon: String?
        let action: () -> Void
        
        public init(
            _ title: String,
            icon: String? = nil,
            action: @escaping () -> Void
        ) {
            self.title = title
            self.icon = icon
            self.action = action
        }
        
        public var body: some View {
            Button(action: action) {
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                    }
                    Text(title)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.secondaryBackground)
                .foregroundStyle(Theme.primary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Cards
    public struct Card<Content: View>: View {
        let content: Content
        let padding: CGFloat
        
        public init(
            padding: CGFloat = 16,
            @ViewBuilder content: () -> Content
        ) {
            self.padding = padding
            self.content = content()
        }
        
        public var body: some View {
            content
                .padding(padding)
                .background(Theme.cardBackground)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        }
    }
    
    public struct GlassCard<Content: View>: View {
        let content: Content
        
        public init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }
        
        public var body: some View {
            content
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
    }
    
    // MARK: - Input Fields
    public struct TextField: View {
        let placeholder: String
        @Binding var text: String
        let icon: String?
        let isSecure: Bool
        
        public init(
            _ placeholder: String,
            text: Binding<String>,
            icon: String? = nil,
            isSecure: Bool = false
        ) {
            self.placeholder = placeholder
            self._text = text
            self.icon = icon
            self.isSecure = isSecure
        }
        
        public var body: some View {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }
                
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    SwiftUI.TextField(placeholder, text: $text)
                }
            }
            .padding()
            .background(Theme.inputBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Badges
    public struct Badge: View {
        let text: String
        let color: Color
        let style: BadgeStyle
        
        public enum BadgeStyle {
            case filled
            case outlined
            case subtle
        }
        
        public init(
            _ text: String,
            color: Color = Theme.primary,
            style: BadgeStyle = .filled
        ) {
            self.text = text
            self.color = color
            self.style = style
        }
        
        public var body: some View {
            Text(text)
                .font(.caption2)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(backgroundView)
                .foregroundStyle(foregroundColor)
                .cornerRadius(6)
        }
        
        @ViewBuilder
        private var backgroundView: some View {
            switch style {
            case .filled:
                color
            case .outlined:
                Color.clear
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(color, lineWidth: 1)
                    )
            case .subtle:
                color.opacity(0.1)
            }
        }
        
        private var foregroundColor: Color {
            switch style {
            case .filled:
                return .white
            case .outlined, .subtle:
                return color
            }
        }
    }
    
    // MARK: - Loading States
    public struct LoadingView: View {
        let message: String?
        
        public init(message: String? = nil) {
            self.message = message
        }
        
        public var body: some View {
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                
                if let message = message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.opacity(0.95))
        }
    }
    
    // MARK: - Separators
    public struct Separator: View {
        let orientation: Axis
        let color: Color
        let thickness: CGFloat
        
        public init(
            orientation: Axis = .horizontal,
            color: Color = Theme.border,
            thickness: CGFloat = 1
        ) {
            self.orientation = orientation
            self.color = color
            self.thickness = thickness
        }
        
        public var body: some View {
            Rectangle()
                .fill(color)
                .frame(
                    width: orientation == .vertical ? thickness : nil,
                    height: orientation == .horizontal ? thickness : nil
                )
        }
    }
    
    // MARK: - Avatars
    public struct Avatar: View {
        let image: Image?
        let initials: String?
        let size: CGFloat
        let color: Color
        
        public init(
            image: Image? = nil,
            initials: String? = nil,
            size: CGFloat = 40,
            color: Color = Theme.primary
        ) {
            self.image = image
            self.initials = initials
            self.size = size
            self.color = color
        }
        
        public var body: some View {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: size, height: size)
                
                if let image = image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else if let initials = initials {
                    Text(initials)
                        .font(.system(size: size / 2.5))
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: size / 2))
                        .foregroundStyle(color)
                }
            }
        }
    }
    
    // MARK: - Tooltips
    public struct Tooltip: ViewModifier {
        let text: String
        @State private var isShowing = false
        
        public func body(content: Content) -> some View {
            content
                .onHover { hovering in
                    isShowing = hovering
                }
                .overlay(
                    Group {
                        if isShowing {
                            Text(text)
                                .font(.caption)
                                .padding(8)
                                .background(Color.black.opacity(0.8))
                                .foregroundStyle(.white)
                                .cornerRadius(6)
                                .transition(.opacity)
                                .offset(y: -30)
                        }
                    }
                )
        }
    }
}

// MARK: - View Extensions
public extension View {
    func tooltip(_ text: String) -> some View {
        self.modifier(ComponentLibrary.Tooltip(text: text))
    }
    
    func card(padding: CGFloat = 16) -> some View {
        ComponentLibrary.Card(padding: padding) { self }
    }
    
    func glassCard() -> some View {
        ComponentLibrary.GlassCard { self }
    }
}

// MARK: - Style Guide
public struct StyleGuide: View {
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Typography
                typographySection
                
                // Colors
                colorsSection
                
                // Buttons
                buttonsSection
                
                // Cards
                cardsSection
                
                // Input Fields
                inputSection
                
                // Badges
                badgesSection
                
                // Avatars
                avatarsSection
            }
            .padding()
        }
        .navigationTitle("Component Style Guide")
    }
    
    private var typographySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Typography")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Large Title").font(.largeTitle)
                Text("Title").font(.title)
                Text("Title 2").font(.title2)
                Text("Title 3").font(.title3)
                Text("Headline").font(.headline)
                Text("Subheadline").font(.subheadline)
                Text("Body").font(.body)
                Text("Callout").font(.callout)
                Text("Footnote").font(.footnote)
                Text("Caption").font(.caption)
                Text("Caption 2").font(.caption2)
            }
            .card()
        }
    }
    
    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Colors")
                .font(.title)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                ColorSwatch("Primary", Theme.primary)
                ColorSwatch("Accent", Theme.accent)
                ColorSwatch("Background", Theme.background)
                ColorSwatch("Secondary", Theme.secondaryBackground)
                ColorSwatch("Success", .green)
                ColorSwatch("Warning", .orange)
                ColorSwatch("Error", .red)
                ColorSwatch("Info", .blue)
            }
        }
    }
    
    private var buttonsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Buttons")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                ComponentLibrary.PrimaryButton("Primary Button", icon: "star") {}
                ComponentLibrary.PrimaryButton("Loading", isLoading: true) {}
                ComponentLibrary.SecondaryButton("Secondary Button", icon: "heart") {}
            }
            .card()
        }
    }
    
    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cards")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                Text("Standard Card")
                    .frame(maxWidth: .infinity)
                    .card()
                
                Text("Glass Card")
                    .frame(maxWidth: .infinity)
                    .glassCard()
            }
        }
    }
    
    @State private var textFieldValue = ""
    @State private var secureFieldValue = ""
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Input Fields")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                ComponentLibrary.TextField(
                    "Enter text",
                    text: $textFieldValue,
                    icon: "pencil"
                )
                
                ComponentLibrary.TextField(
                    "Password",
                    text: $secureFieldValue,
                    icon: "lock",
                    isSecure: true
                )
            }
            .card()
        }
    }
    
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Badges")
                .font(.title)
                .fontWeight(.bold)
            
            HStack(spacing: 12) {
                ComponentLibrary.Badge("New", style: .filled)
                ComponentLibrary.Badge("Updated", color: .orange, style: .outlined)
                ComponentLibrary.Badge("Beta", color: .purple, style: .subtle)
            }
            .card()
        }
    }
    
    private var avatarsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Avatars")
                .font(.title)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                ComponentLibrary.Avatar(initials: "JD", size: 40)
                ComponentLibrary.Avatar(initials: "AS", size: 50, color: .orange)
                ComponentLibrary.Avatar(size: 60, color: .purple)
            }
            .card()
        }
    }
}

private struct ColorSwatch: View {
    let name: String
    let color: Color
    
    init(_ name: String, _ color: Color) {
        self.name = name
        self.color = color
    }
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 60)
            
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview Provider
struct ComponentLibrary_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            StyleGuide()
        }
    }
}