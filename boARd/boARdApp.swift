import SwiftUI
import FirebaseCore

@main
struct boARdApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var isLoading = true
    
    // Initialize the SavedPlayService on app launch
    init() {
        FirebaseApp.configure()
        // Perform any initial setup for saved plays here
        _ = SavedPlayService.shared
        // Set navigation bar appearance for light/dark mode
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white
        appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.user == nil {
                    AuthView()
                        .environmentObject(authViewModel)
                } else if authViewModel.justSignedUp && !authViewModel.hasCompletedOnboarding {
                    OnboardingView()
                        .environmentObject(authViewModel)
                } else {
                    NavigationView {
                        ZStack {
                            HomeScreen()
                                .opacity(isLoading ? 0 : 1)
                            if isLoading {
                                LoadingView()
                                    .onAppear {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            withAnimation {
                                                isLoading = false
                                            }
                                        }
                                    }
                            }
                        }
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .environmentObject(authViewModel)
                }
            }
            .onAppear {
                print("Auth State -- user: \(String(describing: authViewModel.user?.uid)), justSignedUp: \(authViewModel.justSignedUp), hasCompletedOnboarding: \(authViewModel.hasCompletedOnboarding)")
            }
        }
    }
}

struct LoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack {
            Text("boARd")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 20)
            
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Color.blue, lineWidth: 5)
                .frame(width: 50, height: 50)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .edgesIgnoringSafeArea(.all)
    }
} 
