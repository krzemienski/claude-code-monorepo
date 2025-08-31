import SwiftUI
import Combine

// MARK: - Reactive Search Bar

public struct ReactiveSearchBar: View {
    @StateObject private var viewModel: ReactiveSearchViewModel
    let placeholder: String
    let onResultSelected: (SearchResult) -> Void
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @FocusState private var isFocused: Bool
    
    public init(
        searchService: SearchServiceProtocol,
        placeholder: String = "Search...",
        onResultSelected: @escaping (SearchResult) -> Void
    ) {
        self._viewModel = StateObject(wrappedValue: ReactiveSearchViewModel(searchService: searchService))
        self.placeholder = placeholder
        self.onResultSelected = onResultSelected
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search input
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.mutedFg)
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
                
                TextField(placeholder, text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
                    .foregroundStyle(Theme.foreground)
                    .focused($isFocused)
                    .accessibilityLabel("Search field")
                    .accessibilityHint("Enter search terms")
                
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.clearSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.mutedFg)
                    }
                    .accessibilityLabel("Clear search")
                }
                
                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.card)
            .cornerRadius(Theme.CornerRadius.md)
            
            // Search results
            if !viewModel.searchResults.isEmpty && isFocused {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.searchResults) { result in
                            Button {
                                onResultSelected(result)
                                viewModel.clearSearch()
                                isFocused = false
                            } label: {
                                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                    Text(result.title)
                                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
                                        .fontWeight(.medium)
                                        .foregroundStyle(Theme.foreground)
                                    
                                    Text(result.description)
                                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.sm, for: dynamicTypeSize)))
                                        .foregroundStyle(Theme.mutedFg)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(Theme.Spacing.md)
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                                .background(Theme.border)
                        }
                    }
                }
                .frame(maxHeight: 300)
                .background(Theme.card)
                .cornerRadius(Theme.CornerRadius.md)
                .shadow(color: Theme.cardShadow, radius: 8)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
            
            // Error state
            if let error = viewModel.error {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Theme.error)
                    
                    Text(error.localizedDescription)
                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.sm, for: dynamicTypeSize)))
                        .foregroundStyle(Theme.error)
                }
                .padding(Theme.Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(Theme.error.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.sm)
            }
        }
        .animation(.spring(response: 0.3), value: viewModel.searchResults.isEmpty)
        .animation(.spring(response: 0.3), value: viewModel.isSearching)
    }
}

// MARK: - Reactive Form Field

public struct ReactiveFormField: View {
    let title: String
    @Binding var text: String
    let error: String?
    let isSecure: Bool
    let rules: [ValidationRule]
    
    @State private var isValidating = false
    @State private var localError: String?
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    
    public init(
        title: String,
        text: Binding<String>,
        error: String? = nil,
        isSecure: Bool = false,
        rules: [ValidationRule] = []
    ) {
        self.title = title
        self._text = text
        self.error = error
        self.isSecure = isSecure
        self.rules = rules
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Label
            Text(title)
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.sm, for: dynamicTypeSize)))
                .fontWeight(.medium)
                .foregroundStyle(Theme.foreground)
            
            // Input field
            HStack {
                if isSecure {
                    SecureField("", text: $text)
                        .textFieldStyle(.plain)
                } else {
                    TextField("", text: $text)
                        .textFieldStyle(.plain)
                }
                
                if isValidating {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                if error == nil && localError == nil && !text.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.success)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(errorColor, lineWidth: 1)
            )
            .cornerRadius(Theme.CornerRadius.md)
            
            // Error message
            if let errorMessage = error ?? localError {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.xs, for: dynamicTypeSize)))
                    .foregroundStyle(Theme.error)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .onChange(of: text) { newValue in
            validateField(newValue)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) field")
        .accessibilityValue(text.isEmpty ? "Empty" : "Filled")
        .accessibilityHint(error ?? localError ?? "Enter \(title.lowercased())")
    }
    
    private var errorColor: Color {
        if error != nil || localError != nil {
            return Theme.error
        }
        return Theme.border
    }
    
    private func validateField(_ value: String) {
        guard !rules.isEmpty else { return }
        
        isValidating = true
        
        // Simulate async validation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            localError = rules.compactMap { $0.validate(value) }.first
            isValidating = false
        }
    }
}

// MARK: - Reactive Toggle

public struct ReactiveToggle: View {
    let title: String
    @Binding var isOn: Bool
    let onChange: ((Bool) -> Void)?
    
    @State private var isAnimating = false
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    public init(
        title: String,
        isOn: Binding<Bool>,
        onChange: ((Bool) -> Void)? = nil
    ) {
        self.title = title
        self._isOn = isOn
        self.onChange = onChange
    }
    
    public var body: some View {
        HStack {
            Text(title)
                .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
                .foregroundStyle(Theme.foreground)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.primary)
                .onChange(of: isOn) { newValue in
                    if !reduceMotion {
                        withAnimation(.spring(response: 0.3)) {
                            isAnimating = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isAnimating = false
                        }
                    }
                    
                    onChange?(newValue)
                }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.card)
        .cornerRadius(Theme.CornerRadius.md)
        .scaleEffect(isAnimating ? 1.02 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint("Double tap to toggle")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Reactive Loading Button

public struct ReactiveLoadingButton: View {
    let title: String
    let action: () async -> Void
    @State private var isLoading = false
    @State private var isSuccess = false
    @State private var isError = false
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.isEnabled) var isEnabled
    
    public init(
        title: String,
        action: @escaping () async -> Void
    ) {
        self.title = title
        self.action = action
    }
    
    public var body: some View {
        Button {
            Task {
                await performAction()
            }
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else if isSuccess {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                } else if isError {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
                
                Text(buttonTitle)
                    .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.base, for: dynamicTypeSize)))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Spacing.lg)
            .background(buttonBackground)
            .cornerRadius(Theme.CornerRadius.md)
        }
        .disabled(isLoading || !isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? "Loading" : "Tap to \(title.lowercased())")
        .accessibilityAddTraits(isLoading ? [.isButton, .updatesFrequently] : .isButton)
    }
    
    private var buttonTitle: String {
        if isLoading {
            return "Loading..."
        } else if isSuccess {
            return "Success!"
        } else if isError {
            return "Try Again"
        }
        return title
    }
    
    private var buttonBackground: Color {
        if !isEnabled || isLoading {
            return Theme.mutedFg.opacity(0.5)
        } else if isSuccess {
            return Theme.success
        } else if isError {
            return Theme.error
        }
        return Theme.primary
    }
    
    private func performAction() async {
        isLoading = true
        isSuccess = false
        isError = false
        
        do {
            await action()
            isLoading = false
            isSuccess = true
            
            // Reset after delay
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            isSuccess = false
        } catch {
            isLoading = false
            isError = true
            
            // Reset after delay
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            isError = false
        }
    }
}

// MARK: - Reactive Progress Indicator

public struct ReactiveProgressIndicator: View {
    let progress: Double
    let title: String?
    let showPercentage: Bool
    
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @State private var animatedProgress: Double = 0
    
    public init(
        progress: Double,
        title: String? = nil,
        showPercentage: Bool = true
    ) {
        self.progress = min(max(progress, 0), 1) // Clamp between 0 and 1
        self.title = title
        self.showPercentage = showPercentage
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if let title = title {
                HStack {
                    Text(title)
                        .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.sm, for: dynamicTypeSize)))
                        .foregroundStyle(Theme.foreground)
                    
                    Spacer()
                    
                    if showPercentage {
                        Text("\(Int(animatedProgress * 100))%")
                            .font(.system(size: Theme.FontSize.scalable(Theme.FontSize.sm, for: dynamicTypeSize)))
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.primary)
                    }
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(Theme.border.opacity(0.3))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                        .fill(
                            LinearGradient(
                                colors: [Theme.primary, Theme.neonCyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * animatedProgress, height: 8)
                        .animation(.spring(response: 0.5), value: animatedProgress)
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            animatedProgress = progress
        }
        .onChange(of: progress) { newValue in
            animatedProgress = newValue
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title ?? "Progress indicator")
        .accessibilityValue("\(Int(progress * 100)) percent complete")
    }
}