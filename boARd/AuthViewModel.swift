import Foundation
import Combine

class AuthViewModel: ObservableObject {
    // No authentication, just a local stub for onboarding
    @Published var hasCompletedOnboarding = false
    @Published var displayName: String = "Guest"
    
    func getOnboardingCompleted() -> Bool {
        UserDefaults.standard.bool(forKey: "onboardingShown")
    }
    
    func setOnboardingCompleted() {
        UserDefaults.standard.set(true, forKey: "onboardingShown")
    }
} 