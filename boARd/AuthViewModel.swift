import Foundation
import FirebaseAuth
import Combine
import FirebaseFirestore

class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var hasCompletedOnboarding = false
    @Published var justSignedUp = false
    @Published var displayName: String = "Guest"
    private var handle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    
    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.fetchDisplayNameForUser(user)
            if let user = user {
                // User is signed in or was already signed in
                print("Auth state changed, user: \(user.uid). Fetching team ID.")
                UserService.shared.fetchAndUpdateUserTeamIDFromFirestore()
            } else {
                // User is nil (logged out)
                print("Auth state changed, user is nil (logged out).")
            }
        }
    }
    
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Onboarding Persistence (per user)
    private func onboardingKey(for userId: String) -> String {
        return "onboardingShown_\(userId)"
    }
    
    func getOnboardingCompleted(for userId: String) -> Bool {
        UserDefaults.standard.bool(forKey: onboardingKey(for: userId))
    }
    
    func setOnboardingCompleted(for userId: String) {
        UserDefaults.standard.set(true, forKey: onboardingKey(for: userId))
    }
    
    func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error as NSError? {
                    switch AuthErrorCode(rawValue: error.code) {
                    case .wrongPassword:
                        self?.errorMessage = "Incorrect password. Please try again."
                    case .userNotFound:
                        self?.errorMessage = "No account found with this email."
                    case .invalidEmail:
                        self?.errorMessage = "Invalid email address."
                    case .userDisabled:
                        self?.errorMessage = "This account has been disabled."
                    default:
                        print("Auth error: \(error), code: \(error.code)")
                        self?.errorMessage = "Something went wrong. Please try again later."
                    }
                } else if let user = result?.user {
                    self?.user = user
                    self?.justSignedUp = false
                    self?.checkUserProfile(userId: user.uid) { hasProfile in
                        self?.hasCompletedOnboarding = self?.getOnboardingCompleted(for: user.uid) ?? hasProfile
                        // Fetch team ID after successful sign-in and profile check
                        print("User signed in: \(user.uid). Fetching team ID post profile check.")
                        UserService.shared.fetchAndUpdateUserTeamIDFromFirestore()
                    }
                }
            }
        }
    }
    
    func signUp(email: String, password: String) {
        isLoading = true
        errorMessage = nil
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error as NSError? {
                    switch AuthErrorCode(rawValue: error.code) {
                    case .emailAlreadyInUse:
                        self?.errorMessage = "An account already exists with this email."
                    case .invalidEmail:
                        self?.errorMessage = "Invalid email address."
                    case .weakPassword:
                        self?.errorMessage = "Password is too weak."
                    default:
                        print("Auth error: \(error), code: \(error.code)")
                        self?.errorMessage = "Something went wrong. Please try again later."
                    }
                } else if let user = result?.user {
                    self?.user = user
                    self?.justSignedUp = true
                    // For a new sign-up, teamID would be set during onboarding if provided.
                    // Fetching here ensures if onboarding is somehow skipped or if teamID is set by another means,
                    // UserDefaults gets updated.
                    self?.checkUserProfile(userId: user.uid) { hasProfile in // checkUserProfile might be too early for a brand new user before onboarding
                        self?.hasCompletedOnboarding = self?.getOnboardingCompleted(for: user.uid) ?? hasProfile
                        print("User signed up: \(user.uid). Fetching team ID post profile check (or pre-onboarding).")
                        UserService.shared.fetchAndUpdateUserTeamIDFromFirestore()
                    }
                }
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func signInAnonymously() {
        isLoading = true
        errorMessage = nil
        Auth.auth().signInAnonymously { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    self?.user = result?.user
                    self?.justSignedUp = false
                }
            }
        }
    }
    
    func saveUserProfile(userId: String, profile: [String: Any], completion: @escaping (Error?) -> Void) {
        db.collection("users").document(userId).setData(profile, merge: true) { error in
            completion(error)
        }
    }
    
    func checkUserProfile(userId: String, completion: @escaping (Bool) -> Void) {
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let data = snapshot?.data(),
               let name = data["name"] as? String, !name.isEmpty {
                completion(true)
            } else {
                completion(false)
            }
        }
    }

    private func fetchDisplayNameForUser(_ user: User?) {
        guard let authenticatedUser = user else {
            self.displayName = "Guest"
            return
        }

        if authenticatedUser.isAnonymous {
            self.displayName = "Guest"
        } else {
            // Fetch name from Firestore for non-anonymous users
            db.collection("users").document(authenticatedUser.uid).getDocument { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Error fetching user profile for display name: \(error.localizedDescription)")
                        self?.displayName = "User" // Fallback in case of error
                        return
                    }
                    
                    if let data = snapshot?.data(), let name = data["name"] as? String, !name.isEmpty {
                        self?.displayName = name
                    } else {
                        // Fallback if no name field, or if name is empty, or if document doesn't exist
                        print("User profile name not found or empty for UID: \(authenticatedUser.uid). Defaulting to 'User'.")
                        self?.displayName = "User" 
                    }
                }
            }
        }
    }
} 