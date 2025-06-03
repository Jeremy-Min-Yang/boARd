import SwiftUI
import FirebaseAuth

struct HomeScreen: View {
    @Binding var showARSheet: Bool
    @Binding var arPlay: Models.SavedPlay?
    @State private var selectedTab: MainTab = .home
    @State private var showCourtOptions = false
    @State private var selectedCourtType: CourtType?
    @State private var navigateToWhiteboard = false
    @State private var savedPlays: [Models.SavedPlay] = []
    @State private var selectedPlay: Models.SavedPlay?
    @State private var editMode = false
    @State private var viewOnlyMode = false
    @State private var uploadingPlayID: UUID? = nil
    @State private var uploadSuccessPlayID: UUID? = nil
    @State private var showLoginAlert: Bool = false

    // New state for Home Screen Team Plays
    @State private var teamPlaysForHome: [Models.SavedPlay] = []
    @State private var isLoadingTeamPlaysForHome: Bool = false
    @State private var teamPlaysErrorForHome: String? = nil
    @State private var currentTeamIDForHome: String? = nil

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 40)
                        // App name and welcome
                        Text("boARd")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.top, 8)
                        HStack {
                            Spacer()
                            Text("Welcome back, Coach!")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.bottom, 24)
                        // Recent Plays
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Plays")
                                .font(.headline)
                            if savedPlays.isEmpty {
                                Text("No recent plays yet.")
                                    .foregroundColor(.gray)
                            } else {
                                ForEach(savedPlays.prefix(3)) { play in
                                    Button(action: {
                                        selectedPlay = play
                                        editMode = false
                                        viewOnlyMode = true
                                        navigateToWhiteboard = true
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(play.name)
                                                    .font(.subheadline)
                                                    .foregroundColor(.primary)
                                                Text("Last modified: \(dateFormatter.string(from: play.lastModified))")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        .padding(.top, 16)

                        // My Team Plays Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("My Team Plays")
                                .font(.headline)
                            
                            if isLoadingTeamPlaysForHome {
                                ProgressView("Loading team plays...")
                                    .padding(.vertical)
                            } else if let error = teamPlaysErrorForHome {
                                Text("Error loading team plays: \(error)")
                                    .foregroundColor(.red)
                            } else if currentTeamIDForHome == nil {
                                Text("You are not part of a team.")
                                    .foregroundColor(.gray)
                            } else if teamPlaysForHome.isEmpty {
                                Text("No plays found for your team yet.")
                                    .foregroundColor(.gray)
                            } else {
                                ForEach(teamPlaysForHome.prefix(3)) { play in
                                    Button(action: {
                                        selectedPlay = play
                                        editMode = false
                                        viewOnlyMode = true
                                        navigateToWhiteboard = true
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(play.name)
                                                    .font(.subheadline)
                                                    .foregroundColor(.primary)
                                                Text("Team Play - Last modified: \(dateFormatter.string(from: play.lastModified))")
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.vertical, 8)
                                        .padding(.horizontal)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(10)
                                    }
                                }
                                if teamPlaysForHome.count > 0 { // Show "View All" if any team plays exist
                                    Button(action: {
                                        selectedTab = .team
                                    }) {
                                        Text("View All Team Plays")
                                            .font(.callout)
                                            .foregroundColor(.blue)
                                            .padding(.top, 4)
                                    }
                                }
                            }
                        }
                        .padding(.top, 24) // Add some spacing from Recent Plays

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 20)
                    .onAppear {
                        // Load local "Recent Plays"
                        savedPlays = SavedPlayService.shared.loadPlaysLocally()
                            .sorted { $0.lastModified > $1.lastModified }
                        
                        // Load "My Team Plays" for the home screen
                        fetchTeamPlaysForHomeScreen()
                    }
                case .team:
                    TeamPlaysView(
                        showARSheet: $showARSheet, 
                        arPlay: $arPlay,
                        selectedPlayForSheet: $selectedPlay, // For viewing/AR from team context
                        navigateToWhiteboard: $navigateToWhiteboard,
                        editModeForSheet: $editMode, // To set view-only mode
                        viewOnlyModeForSheet: $viewOnlyMode
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .add:
                    EmptyView()
                case .plays:
                    SavedPlaysScreen(
                        selectedPlay: $selectedPlay,
                        editMode: $editMode,
                        viewOnlyMode: $viewOnlyMode,
                        navigateToWhiteboard: $navigateToWhiteboard,
                        showARSheet: $showARSheet,
                        arPlay: $arPlay
                    )
                case .profile:
                    ProfileView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            MainTabBar(selectedTab: $selectedTab) {
                showCourtOptions = true
            }
            // --- Global overlays for court selection and navigation ---
            if showCourtOptions {
                CourtSelectionView(isPresented: $showCourtOptions, onCourtSelected: { courtType in
                    selectedCourtType = courtType
                    selectedPlay = nil
                    editMode = true
                    viewOnlyMode = false
                    showCourtOptions = false
                    navigateToWhiteboard = true
                    print("navigateToWhiteboard set to true")
                })
            }
            NavigationLink(
                destination: Group {
                    if let play = selectedPlay {
                        WhiteboardView(courtType: play.courtTypeEnum, playToLoad: play, isEditable: editMode)
                    } else if let courtType = selectedCourtType {
                        WhiteboardView(courtType: courtType)
                    } else {
                        EmptyView()
                    }
                },
                isActive: $navigateToWhiteboard,
                label: { EmptyView() }
            )
            .hidden()
        }
        .edgesIgnoringSafeArea(.bottom)
        .alert(isPresented: $showLoginAlert) {
            Alert(
                title: Text("Login Required"),
                message: Text("You must be logged in to upload plays to the cloud."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    func fetchTeamPlaysForHomeScreen() {
        self.currentTeamIDForHome = UserService.shared.getCurrentUserTeamID()
        
        guard let teamID = self.currentTeamIDForHome else {
            isLoadingTeamPlaysForHome = false
            teamPlaysForHome = []
            teamPlaysErrorForHome = nil // Not an error, just not in a team
            print("DEBUG HomeScreen: User not in a team, not fetching team plays for home.")
            return
        }
        
        isLoadingTeamPlaysForHome = true
        teamPlaysErrorForHome = nil
        
        SavedPlayService.shared.fetchPlaysForTeam(teamID: teamID) { result in
            DispatchQueue.main.async {
                isLoadingTeamPlaysForHome = false
                switch result {
                case .success(let plays):
                    self.teamPlaysForHome = plays.sorted { $0.lastModified > $1.lastModified }
                    print("DEBUG HomeScreen: Successfully fetched \(self.teamPlaysForHome.count) team plays for team ID \(teamID).")
                    if self.teamPlaysForHome.isEmpty {
                        print("DEBUG HomeScreen: No plays found for team ID \(teamID) on home screen.")
                    }
                case .failure(let error):
                    self.teamPlaysErrorForHome = error.localizedDescription
                    print("DEBUG HomeScreen: Error fetching team plays for home: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct TeamPlaysView: View {
    @Binding var showARSheet: Bool
    @Binding var arPlay: Models.SavedPlay?
    @Binding var selectedPlayForSheet: Models.SavedPlay? // To trigger navigation/sheet
    @Binding var navigateToWhiteboard: Bool
    @Binding var editModeForSheet: Bool
    @Binding var viewOnlyModeForSheet: Bool

    @State private var teamPlays: [Models.SavedPlay] = []
    @State private var isLoading: Bool = true
    @State private var currentTeamID: String?
    @State private var errorMessage: String?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationView { // Added NavigationView for a title
            VStack {
                if isLoading {
                    ProgressView("Loading Team Plays...")
                        .padding()
                } else if let teamID = currentTeamID {
                    if let error = errorMessage {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                    }
                    if teamPlays.isEmpty && errorMessage == nil {
                        VStack {
                            Text("No Plays for Your Team Yet")
                                .font(.headline)
                                .padding(.bottom)
                            Text("Once plays are added to team '\(teamID)', they will appear here.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                    } else if !teamPlays.isEmpty {
                        List {
                            ForEach(teamPlays) { play in
                                SavedPlayRow(
                                    play: play,
                                    dateFormatter: dateFormatter,
                                    onEdit: {
                                        // For team plays, typically view-only or restricted edit
                                        // For now, let's make it view-only
                                        selectedPlayForSheet = play
                                        editModeForSheet = false // Explicitly false for edit
                                        viewOnlyModeForSheet = true // Explicitly true for view
                                        navigateToWhiteboard = true
                                    },
                                    onView: {
                                        selectedPlayForSheet = play
                                        editModeForSheet = false
                                        viewOnlyModeForSheet = true
                                        navigateToWhiteboard = true
                                    },
                                    onAR: {
                                        arPlay = play
                                        showARSheet = true
                                    },
                                    onDelete: {
                                        // Deleting team plays needs permission checks.
                                        // For now, this action can be disabled or show an alert.
                                        print("Attempted to delete team play: \(play.name). Not implemented yet.")
                                        // self.deleteTeamPlay(play) // Placeholder for future
                                    },
                                    onUpload: {
                                        // Uploading is not applicable for plays already in a team context.
                                        print("Upload button pressed for team play: \(play.name). No action taken.")
                                    },
                                    isUploading: false, // Never uploading from team view like this
                                    uploadSuccess: false // Not applicable
                                )
                            }
                        }
                        .listStyle(PlainListStyle()) // Use PlainListStyle for better appearance
                    }
                } else {
                    VStack {
                        Text("Not Part of a Team")
                            .font(.headline)
                            .padding(.bottom)
                        Text("Please join or create a team from your Profile to see shared plays.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        // Optional: Button to navigate to Profile
                        // NavigationLink("Go to Profile", destination: ProfileView()) // Requires ProfileView to be embeddable or use a tab switch
                    }
                    .padding()
                }
                Spacer() // Pushes content to the top if list is short or view is empty
            }
            .navigationTitle("Team Plays") // Set a navigation title
            .onAppear {
                fetchTeamData()
            }
        }
         .navigationViewStyle(StackNavigationViewStyle()) // Use stack style for larger screens if needed
    }

    func fetchTeamData() {
        isLoading = true
        errorMessage = nil
        self.currentTeamID = UserService.shared.getCurrentUserTeamID() // Get current user's team ID

        if let teamID = self.currentTeamID {
            SavedPlayService.shared.fetchPlaysForTeam(teamID: teamID) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success(let plays):
                        self.teamPlays = plays.sorted { $0.lastModified > $1.lastModified }
                        if self.teamPlays.isEmpty {
                            print("No plays found for team ID: \(teamID)")
                        }
                    case .failure(let error):
                        print("Error fetching team plays: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            isLoading = false
            print("User is not part of any team.")
        }
    }
    
    // Placeholder for deleting a team play (would need permissions)
    /*
    private func deleteTeamPlay(_ play: Models.SavedPlay) {
        // 1. Check permissions (e.g., is user creator or team admin?)
        // 2. If permitted, call SavedPlayService.shared.deletePlay(playID: play.id.uuidString) { ... }
        // 3. On success, remove from self.teamPlays and potentially refresh
        teamPlays.removeAll { $0.id == play.id }
        // SavedPlayService.shared.deletePlay(playID: play.id.uuidString) { error in ... }
    }
    */
}

struct SavedPlaysScreen: View {
    @Binding var selectedPlay: Models.SavedPlay?
    @Binding var editMode: Bool
    @Binding var viewOnlyMode: Bool
    @Binding var navigateToWhiteboard: Bool
    @Binding var showARSheet: Bool
    @Binding var arPlay: Models.SavedPlay?
    @State private var savedPlays: [Models.SavedPlay] = []
    @State private var syncStatus: String = ""
    @State private var isSyncing: Bool = false
    @State private var uploadingPlayID: UUID? = nil
    @State private var uploadSuccessPlayID: UUID? = nil
    @State private var showLoginAlert: Bool = false
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                Text("Saved Plays")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 30)
                    .padding(.bottom, 20)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("All Plays")
                            .font(.headline)
                            .padding(.horizontal)
                        Spacer()
                    }
                    // --- Cloud Sync Section ---
                    VStack(alignment: .center, spacing: 8) {
                        Text("Cloud Sync")
                            .font(.headline)
                            .padding(.top, 4)
                        HStack(spacing: 16) {
                            Spacer()
                            Button(action: {
                                isSyncing = true
                                syncStatus = "Syncing..."
                                SavedPlayService.shared.downloadAllCloudPlaysToLocal { error in
                                    DispatchQueue.main.async {
                                        isSyncing = false
                                        if let error = error {
                                            syncStatus = "Download failed: \(error.localizedDescription)"
                                        } else {
                                            syncStatus = "Downloaded from cloud!"
                                            savedPlays = SavedPlayService.shared.loadPlaysLocally().sorted { $0.lastModified > $1.lastModified }
                                        }
                                    }
                                }
                            }) {
                                Label("Sync from Cloud", systemImage: "icloud.and.arrow.down")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green.opacity(0.12))
                                    .foregroundColor(.green)
                                    .cornerRadius(10)
                            }
                            .disabled(isSyncing)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 4)
                        if !syncStatus.isEmpty {
                            Text(syncStatus)
                                .font(.caption)
                                .foregroundColor(syncStatus.contains("failed") ? .red : .green)
                                .padding(.top, 2)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1.5)
                            .background(Color(.systemBackground).opacity(0.8).cornerRadius(16))
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    if savedPlays.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "basketball")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No saved plays yet")
                                .font(.title3)
                                .foregroundColor(.gray)
                            Text("Create a new whiteboard to get started.")
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 50)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(savedPlays) { play in
                                    SavedPlayRow(
                                        play: play,
                                        dateFormatter: dateFormatter,
                                        onEdit: {
                                            selectedPlay = play
                                            editMode = true
                                            viewOnlyMode = false
                                            navigateToWhiteboard = true
                                        },
                                        onView: {
                                            selectedPlay = play
                                            editMode = false
                                            viewOnlyMode = true
                                            navigateToWhiteboard = true
                                        },
                                        onAR: {
                                            print("[DEBUG] onAR closure called for play: \(play.name)")
                                            arPlay = play
                                            showARSheet = true
                                        },
                                        onDelete: {
                                            deletePlay(play)
                                        },
                                        onUpload: {
                                            if Auth.auth().currentUser == nil {
                                                uploadingPlayID = nil
                                                uploadSuccessPlayID = nil
                                                print("DEBUG: Tried to upload as guest. Auth.currentUser is nil.")
                                                showLoginAlert = true
                                                return
                                            }
                                            uploadingPlayID = play.id
                                            uploadSuccessPlayID = nil
                                            SavedPlayService.shared.savePlay(play, forUserID: Auth.auth().currentUser?.uid ?? "") { error in
                                                DispatchQueue.main.async {
                                                    uploadingPlayID = nil
                                                    if error == nil {
                                                        uploadSuccessPlayID = play.id
                                                        // Hide checkmark after 1.5s
                                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                            uploadSuccessPlayID = nil
                                                        }
                                                    }
                                                }
                                            }
                                        },
                                        isUploading: uploadingPlayID == play.id,
                                        uploadSuccess: uploadSuccessPlayID == play.id
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            savedPlays = SavedPlayService.shared.loadPlaysLocally()
                .sorted { $0.lastModified > $1.lastModified }
        }
    }
    private func deletePlay(_ play: Models.SavedPlay) {
        savedPlays.removeAll { $0.id == play.id }
        SavedPlayService.shared.deletePlay(playID: play.id.uuidString) { _ in }
    }
}

struct SavedPlayRow: View {
    let play: Models.SavedPlay
    let dateFormatter: DateFormatter
    let onEdit: () -> Void
    let onView: () -> Void
    let onAR: () -> Void
    let onDelete: () -> Void
    let onUpload: () -> Void
    let isUploading: Bool
    let uploadSuccess: Bool
    @State private var showDeleteConfirmation = false
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // Play details
                VStack(alignment: .leading, spacing: 4) {
                    Text(play.name)
                        .font(.headline)
                    Text("\(play.courtType.capitalized) Court")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Last modified: \(dateFormatter.string(from: play.lastModified))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .foregroundColor(.blue)
                    }
                    Button(action: onView) {
                        Image(systemName: "eye")
                            .foregroundColor(.green)
                    }
                    Button(action: {
                        print("[DEBUG] AR button tapped for play: \(play.name)")
                        onAR()
                    }) {
                        Image(systemName: "cube")
                            .foregroundColor(.purple)
                    }
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    Button(action: onUpload) {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else if uploadSuccess {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "icloud.and.arrow.up")
                                .foregroundColor(.blue)
                        }
                    }
                    .disabled(isUploading)
                    .accessibilityLabel("Upload to Cloud")
                }
                .padding(.trailing, 8)
            }
            .padding(.vertical, 8)
            Divider()
        }
        .padding(.horizontal, 8)
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Play"),
                message: Text("Are you sure you want to delete '\(play.name)'? This cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete()
                },
                secondaryButton: .cancel()
            )
        }
    }
}

struct CourtSelectionView: View {
    @Binding var isPresented: Bool
    var onCourtSelected: (CourtType) -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }
            
            // Court options
            VStack(spacing: 20) {
                Text("Select Court Type")
                    .font(.headline)
                    .padding(.top)
                
                Button(action: {
                    isPresented = false
                    onCourtSelected(.full)
                }) {
                    CourtOptionCard(title: "Full Court", imageName: "fullcourt")
                }
                
                Button(action: {
                    isPresented = false
                    onCourtSelected(.half)
                }) {
                    CourtOptionCard(title: "Half Court", imageName: "halfcourt")
                }
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("Cancel")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .frame(width: 300)
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 10)
        }
    }
}

struct CourtOptionCard: View {
    var title: String
    var imageName: String
    
    var body: some View {
        HStack {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 60)
                .cornerRadius(8)
            
            Text(title)
                .font(.title2)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .frame(width: 280, height: 80)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct MainTabBar: View {
    @Binding var selectedTab: MainTab
    var addAction: () -> Void
    var body: some View {
        HStack {
            ForEach(MainTab.allCases) { tab in
                if tab == .add {
                    Spacer()
                    Button(action: addAction) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 60, height: 60)
                                .shadow(radius: 6)
                            Image(systemName: "plus")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .offset(y: -20)
                    Spacer()
                } else {
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 24, weight: .regular))
                                .foregroundColor(selectedTab == tab ? .blue : .gray)
                            Text(tab.label)
                                .font(.caption)
                                .foregroundColor(selectedTab == tab ? .blue : .gray)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(
            Color(.systemBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: -2)
        )
    }
}

struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreen(showARSheet: .constant(false), arPlay: .constant(nil))
    }
}
