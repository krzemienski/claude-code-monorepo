import SwiftUI

/// Features module initialization
public struct FeaturesModule {
    public static let shared = FeaturesModule()
    
    private init() {}
    
    public func initialize() {
        print("FeaturesModule initialized")
    }
}

// Re-export feature components
// These will be the actual feature views from the existing codebase