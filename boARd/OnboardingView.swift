import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var name = ""
    @State private var position = ""
    @State private var sport = ""
    @State private var teamID = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Set Up Your Profile")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            TextField("Name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            TextField("Position", text: $position)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            TextField("Sport", text: $sport)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            TextField("Team ID", text: $teamID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            Button(action: saveProfile) {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Save and Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }
            }
            .disabled(name.isEmpty || position.isEmpty || sport.isEmpty || teamID.isEmpty)
            Spacer()
        }
        .padding()
    }
    
    private func saveProfile() {
        guard let user = authViewModel.user else { return }
        isSaving = true
        errorMessage = nil
        let profile: [String: Any] = [
            "name": name,
            "position": position,
            "sport": sport,
            "teamID": teamID,
            "email": user.email ?? "",
            "uid": user.uid
        ]
        authViewModel.saveUserProfile(userId: user.uid, profile: profile) { error in
            DispatchQueue.main.async {
                isSaving = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    authViewModel.hasCompletedOnboarding = true
                    authViewModel.justSignedUp = false
                }
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView().environmentObject(AuthViewModel())
    }
} 