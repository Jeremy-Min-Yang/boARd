import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var name = ""
    @State private var teamID = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var selectedSport = "Basketball"
    @State private var selectedPosition = "Point Guard"
    
    private let sports = ["Basketball", "Football", "Soccer"]
    private let positionsBySport: [String: [String]] = [
        "Basketball": ["Point Guard", "Shooting Guard", "Small Forward", "Power Forward", "Center", "Coach"],
        "Football": ["Quarterback", "Running Back", "Wide Receiver", "Tight End", "Defensive Tackle","Defensive End", "Guard", "Linebacker", "Cornerback", "Safety", "Kicker", "Punter", "Coach"],
        "Soccer": ["Goalkeeper", "Defender", "Midfielder", "Forward", "Striker", "Winger", "Coach"]
    ]
    
    var currentPositions: [String] {
        positionsBySport[selectedSport] ?? ["Coach"]
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Set Up Your Profile")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 40)
            VStack(spacing: 16) {
                TextField("Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 250)
                    .multilineTextAlignment(.center)
                Picker("Sport", selection: $selectedSport) {
                    ForEach(sports, id: \.self) { sport in
                        Text(sport)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 250)
                Picker("Position", selection: $selectedPosition) {
                    ForEach(currentPositions, id: \.self) { position in
                        Text(position)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 250)
                TextField("Team ID (Optional)", text: $teamID)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 250)
                    .multilineTextAlignment(.center)
            }
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
            .disabled(name.isEmpty || teamID.isEmpty)
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
            "position": selectedPosition,
            "sport": selectedSport,
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
                    if let user = authViewModel.user {
                        authViewModel.setOnboardingCompleted(for: user.uid)
                    }
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
