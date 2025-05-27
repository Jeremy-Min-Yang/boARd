import SwiftUI
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var name: String = ""
    @State private var teamID: String = ""
    @State private var selectedSport: String = "Basketball"
    @State private var selectedPosition: String = "Point Guard"
    @State private var errorMessage: String?
    @State private var didLoadProfile = false
    @State private var showEditSheet = false
    @State private var isSaving = false

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
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.crop.circle")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            if let user = authViewModel.user {
                if user.isAnonymous {
                    Text("Guest")
                        .font(.title2)
                        .foregroundColor(.gray)
                } else {
                    Text(user.email ?? "Unknown")
                        .font(.title2)
                }
                Text("User ID: \(user.uid)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Name:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(name)
                }
                HStack {
                    Text("Sport:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(selectedSport)
                }
                HStack {
                    Text("Position:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(selectedPosition)
                }
                HStack {
                    Text("Team ID:")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(teamID.isEmpty ? "-" : teamID)
                }
            }
            .frame(width: 280)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: { showEditSheet = true }) {
                Text("Edit")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            Button(action: {
                authViewModel.signOut()
            }) {
                Text("Sign Out")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Profile")
        .onAppear(perform: loadProfile)
        .sheet(isPresented: $showEditSheet) {
            EditProfileSheet(
                name: $name,
                teamID: $teamID,
                selectedSport: $selectedSport,
                selectedPosition: $selectedPosition,
                sports: sports,
                positionsBySport: positionsBySport,
                isSaving: $isSaving,
                errorMessage: $errorMessage,
                onSave: saveProfile
            )
        }
    }

    private func loadProfile() {
        guard !didLoadProfile, let user = authViewModel.user else { return }
        let db = FirebaseFirestore.Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { snapshot, error in
            DispatchQueue.main.async {
                didLoadProfile = true
                if let data = snapshot?.data() {
                    name = data["name"] as? String ?? ""
                    teamID = data["teamID"] as? String ?? ""
                    selectedSport = data["sport"] as? String ?? "Basketball"
                    selectedPosition = data["position"] as? String ?? "Point Guard"
                }
            }
        }
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
                    showEditSheet = false
                }
            }
        }
    }
}

struct EditProfileSheet: View {
    @Binding var name: String
    @Binding var teamID: String
    @Binding var selectedSport: String
    @Binding var selectedPosition: String
    let sports: [String]
    let positionsBySport: [String: [String]]
    @Binding var isSaving: Bool
    @Binding var errorMessage: String?
    var onSave: () -> Void

    var currentPositions: [String] {
        positionsBySport[selectedSport] ?? ["Coach"]
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Info")) {
                    TextField("Name", text: $name)
                    Picker("Sport", selection: $selectedSport) {
                        ForEach(sports, id: \.self) { sport in
                            Text(sport)
                        }
                    }
                    Picker("Position", selection: $selectedPosition) {
                        ForEach(currentPositions, id: \.self) { position in
                            Text(position)
                        }
                    }
                    TextField("Team ID (Optional)", text: $teamID)
                }
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationBarTitle("Edit Profile", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }, trailing: Button(isSaving ? "Saving..." : "Save") {
                if !isSaving { onSave() }
            }.disabled(isSaving || name.isEmpty))
        }
        .onChange(of: selectedSport) { newSport in
            if !currentPositions.contains(selectedPosition) {
                selectedPosition = currentPositions.first ?? "Coach"
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView().environmentObject(AuthViewModel())
    }
} 
