import SwiftUI

struct UploadPlayView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var savedPlays: [Models.SavedPlay] = []
    @State private var selectedPlayIndex: Int? = nil
    @State private var isLoading = true
    @State private var showSuccessAlert = false
    
    let teamID: String
    let preselectedPlay: Models.SavedPlay?
    @ObservedObject var authViewModel = AuthViewModel() // Use your existing instance if available

    var body: some View {
        NavigationView {
            Form {
                if let play = preselectedPlay {
                    Section(header: Text("Play to Upload")) {
                        Text(play.name)
                        Text("Last modified: \(play.lastModified, formatter: dateFormatter)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    Section(header: Text("Select a Saved Play")) {
                        if isLoading {
                            ProgressView("Loading saved plays...")
                        } else if savedPlays.isEmpty {
                            Text("No saved plays found.")
                        } else {
                            Picker("Play", selection: $selectedPlayIndex) {
                                ForEach(savedPlays.indices, id: \ .self) { idx in
                                    Text(savedPlays[idx].name).tag(Optional(idx))
                                }
                            }
                        }
                    }
                }
                if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                }
            }
            .navigationTitle("Upload Play")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Upload") {
                        uploadPlay()
                    }
                    .disabled((preselectedPlay == nil && (selectedPlayIndex == nil || isUploading)) || isUploading)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                if preselectedPlay == nil {
                    loadSavedPlays()
                } else {
                    isLoading = false
                }
            }
            .alert(isPresented: $showSuccessAlert) {
                Alert(
                    title: Text("Success"),
                    message: Text("Play uploaded to team!"),
                    dismissButton: .default(Text("OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    func loadSavedPlays() {
        // Use local plays instead of fetching from Firestore
        self.savedPlays = SavedPlayService.shared.loadPlaysLocally()
        self.isLoading = false
    }
    
    func uploadPlay() {
        let play: Models.SavedPlay
        if let preselected = preselectedPlay {
            play = preselected
        } else {
            guard let idx = selectedPlayIndex, savedPlays.indices.contains(idx) else { return }
            play = savedPlays[idx]
        }
        guard let userID = authViewModel.user?.uid else {
            self.errorMessage = "User not logged in."
            return
        }
        isUploading = true
        errorMessage = nil
        let teamPlay = TeamPlay(
            id: nil,
            name: play.name,
            createdBy: userID,
            createdAt: Date(),
            playData: play
        )
        TeamService.shared.uploadPlay(teamID: teamID, play: teamPlay) { success in
            DispatchQueue.main.async {
                isUploading = false
                if success {
                    showSuccessAlert = true
                } else {
                    errorMessage = "Failed to upload play."
                }
            }
        }
    }
} 