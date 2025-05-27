import SwiftUI
import FirebaseCore

@main
struct boARdApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var isLoading = true
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // AR state at app level
    @State private var showARSheet = false
    @State private var arPlay: Models.SavedPlay? = nil
    @State private var triggerARAnimation = false
    
    // Initialize the SavedPlayService on app launch
    init() {
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
                            HomeScreen(
                                showARSheet: $showARSheet,
                                arPlay: $arPlay
                            )
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
            .fullScreenCover(isPresented: $showARSheet) {
                // Content for the sheet
                if let currentPlay = arPlay {
                    ZStack(alignment: .bottom) {
                        ARPlayView(play: currentPlay, shouldStartAnimationBinding: $triggerARAnimation)
                            .edgesIgnoringSafeArea(.all)
                            .onAppear {
                                print("[DEBUG] ARPlayView .onAppear triggered (App level) for play: \(currentPlay.name)")
                                triggerARAnimation = false
                            }
                        
                        // Play Button
                        Button(action: {
                            print("[boARdApp] Play button tapped. Setting triggerARAnimation to true.")
                            triggerARAnimation = true
                        }) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(.bottom, 30)

                        // Close Button (Top Right)
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: {
                                    print("[boARdApp] Close AR View button tapped.")
                                    showARSheet = false
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Circle())
                                }
                                .padding([.top, .trailing], 20)
                            }
                            Spacer()
                        }
                        .edgesIgnoringSafeArea(.all) // Allow button to be in safe area

                    }
                } else {
                    VStack {
                        Text("AR Play data is not available.")
                            .onAppear {
                                print("[boARdApp] fullScreenCover: arPlay was nil when attempting to show AR content.")
                            }
                        Button("Dismiss") {
                            showARSheet = false
                        }
                        .padding()
                    }
                }
            }
            .onChange(of: showARSheet) { newValue in
                if newValue {
                    print("[boARdApp] fullScreenCover attempting to present (showARSheet is true). arPlay is: \(arPlay == nil ? "nil" : "not nil, play name: \(arPlay?.name ?? "Unknown Play")")")
                    if arPlay == nil {
                        // If arPlay is nil when sheet is supposed to show, maybe auto-dismiss or handle error.
                        // For now, the else branch in fullScreenCover will show the error text.
                    }
                } else {
                    triggerARAnimation = false
                    print("[boARdApp] fullScreenCover dismissed. triggerARAnimation reset to false.")
                }
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
