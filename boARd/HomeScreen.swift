import SwiftUI
import FirebaseAuth

struct HomeScreen: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var showARSheet: Bool
    @Binding var arPlay: Models.SavedPlay?
    @State private var selectedTab: MainTab = .home
    @State private var showCourtOptions = false
    @State private var selectedCourtType: CourtType?
    @State private var navigateToWhiteboard = false
    @State private var selectedPlay: Models.SavedPlay?
    @State private var editMode = false
    @State private var viewOnlyMode = false
    @State private var uploadingPlayID: UUID? = nil
    @State private var uploadSuccessPlayID: UUID? = nil
    @State private var showLoginAlert: Bool = false

    // New state for Home Screen Team Plays
    @State private var teamPlaysForHome: [TeamPlay] = []
    @State private var isLoadingTeamPlaysForHome: Bool = false
    @State private var teamPlaysErrorForHome: String? = nil
    @State private var currentTeamIDForHome: String? = UserService.shared.getCurrentUserTeamID()

    // Alert state hoisted from SavedPlaysScreen
    @State private var playToDeleteInHomeScreen: Models.SavedPlay? = nil
    @State private var showDeleteConfirmationInHomeScreen: Bool = false
    // Keep a reference to savedPlays in HomeScreen to pass to SavedPlaysScreen's deletePlay
    @State private var homeScreenSavedPlays: [Models.SavedPlay] = []

    @State private var showSportSelectionSheet = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Tabbed Content with Overlays (Extracted for Compiler Performance)
    private struct TabbedContentWithOverlays: View {
        @Binding var selectedTab: MainTab
        @Binding var showSportSelectionSheet: Bool
        
        // For mainContentView
        @ObservedObject var authViewModel: AuthViewModel // Assuming AuthViewModel is ObservableObject
        @Binding var homeScreenSavedPlays: [Models.SavedPlay]
        @Binding var isLoadingTeamPlaysForHome: Bool
        @Binding var teamPlaysErrorForHome: String?
        @Binding var currentTeamIDForHome: String?
        @Binding var teamPlaysForHome: [TeamPlay]
        let dateFormatter: DateFormatter
        var fetchTeamPlaysForHomeScreen: () -> Void

        // For homeTabView, teamTabView, playsTabView directly or indirectly
        @Binding var showARSheet: Bool
        @Binding var arPlay: Models.SavedPlay?
        @Binding var selectedPlay: Models.SavedPlay?
        @Binding var editMode: Bool
        @Binding var viewOnlyMode: Bool
        @Binding var playToDeleteInHomeScreen: Models.SavedPlay?
        @Binding var showDeleteConfirmationInHomeScreen: Bool
        
        // For overlays section
        @Binding var showCourtOptions: Bool
        @Binding var selectedCourtType: CourtType?
        @Binding var navigateToWhiteboard: Bool

        // Extracted Tab Views (copied here, could be passed in or part of this struct scope)
        @ViewBuilder
        private var homeTabView: some View {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 40)
                Text("boARd")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                HStack {
                    Spacer()
                    Text("Welcome back, \(authViewModel.displayName)!")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.bottom, 24)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Plays")
                        .font(.headline)
                    if homeScreenSavedPlays.isEmpty {
                        Text("No recent plays yet.")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(homeScreenSavedPlays.prefix(3)) { play in
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
                                selectedPlay = play.playData
                                editMode = false
                                viewOnlyMode = true
                                navigateToWhiteboard = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(play.name)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Text("By: \(play.createdBy)")
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
                        if teamPlaysForHome.count > 0 {
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
                .padding(.top, 24)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 20)
            .onAppear {
                homeScreenSavedPlays = SavedPlayService.shared.loadPlaysLocally()
                    .sorted { $0.lastModified > $1.lastModified }
                fetchTeamPlaysForHomeScreen()
            }
        }

        @ViewBuilder
        private var teamTabView: some View {
            TeamPlaysView(teamID: currentTeamIDForHome ?? "")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        @ViewBuilder
        private var playsTabView: some View {
            SavedPlaysScreen(
                selectedPlay: $selectedPlay,
                editMode: $editMode,
                viewOnlyMode: $viewOnlyMode,
                navigateToWhiteboard: $navigateToWhiteboard,
                showARSheet: $showARSheet,
                arPlay: $arPlay,
                playToDeleteFromParent: $playToDeleteInHomeScreen,
                showDeleteConfirmationFromParent: $showDeleteConfirmationInHomeScreen,
                currentSavedPlays: $homeScreenSavedPlays 
            )
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PlaySavedNotification"))) { _ in
                homeScreenSavedPlays = SavedPlayService.shared.loadPlaysLocally().sorted { $0.lastModified > $1.lastModified }
            }
        }

        @ViewBuilder
        private var profileTabView: some View {
            ProfileView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        
        @ViewBuilder
        private var mainContentView: some View {
            Group {
                switch selectedTab {
                case .home:
                    homeTabView
                case .team:
                    teamTabView
                case .add:
                    EmptyView() // This case is handled by the MainTabBar's addAction directly
                case .plays:
                    playsTabView
                case .profile:
                    profileTabView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        var body: some View {
            ZStack { // Outer ZStack for overlays
                VStack(spacing: 0) { // VStack to manage vertical layout of content and TabBar
                    mainContentView // This is the Group { switch ... }.frame(...) - should expand
                    
                    MainTabBar(selectedTab: $selectedTab) {
                        showSportSelectionSheet = true
                    }
                }
                
                // Overlays and NavigationLink remain in the ZStack to appear on top
                if showCourtOptions {
                    CourtSelectionView(isPresented: $showCourtOptions, onCourtSelected: { courtType in
                        selectedCourtType = courtType
                        selectedPlay = nil
                        editMode = true
                        viewOnlyMode = false
                        showCourtOptions = false
                        navigateToWhiteboard = true
                    })
                }
                NavigationLink(
                    destination: Group {
                        if let play = selectedPlay {
                            WhiteboardView(courtType: play.courtTypeEnum, playToLoad: play, isEditable: editMode)
                        } else if let courtType = selectedCourtType {
                            let _ = print("[HomeScreen DEBUG] Navigating to WhiteboardView with selectedCourtType: \(courtType) for a new play.")
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
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabbedContentWithOverlays(
                selectedTab: $selectedTab,
                showSportSelectionSheet: $showSportSelectionSheet,
                authViewModel: authViewModel, // Pass EnvironmentObject
                homeScreenSavedPlays: $homeScreenSavedPlays,
                isLoadingTeamPlaysForHome: $isLoadingTeamPlaysForHome,
                teamPlaysErrorForHome: $teamPlaysErrorForHome,
                currentTeamIDForHome: $currentTeamIDForHome,
                teamPlaysForHome: $teamPlaysForHome,
                dateFormatter: dateFormatter,
                fetchTeamPlaysForHomeScreen: fetchTeamPlaysForHomeScreen,
                showARSheet: $showARSheet,
                arPlay: $arPlay,
                selectedPlay: $selectedPlay,
                editMode: $editMode,
                viewOnlyMode: $viewOnlyMode,
                playToDeleteInHomeScreen: $playToDeleteInHomeScreen,
                showDeleteConfirmationInHomeScreen: $showDeleteConfirmationInHomeScreen,
                showCourtOptions: $showCourtOptions,
                selectedCourtType: $selectedCourtType,
                navigateToWhiteboard: $navigateToWhiteboard
            )
            .sheet(isPresented: $showSportSelectionSheet) {
                SportSelectionView(
                    isPresented: $showSportSelectionSheet,
                    onSportSelected: { sportFromSelection in
                        // If .full or .half is received, it implies basketball was chosen in SportSelectionView
                        // and we want to show the basketball-specific CourtSelectionView.
                        // Otherwise, it's .soccer or .football for direct navigation.
                        if sportFromSelection == .full || sportFromSelection == .half {
                            showCourtOptions = true // This will show the basketball full/half selection view
                        } else {
                            // This handles .soccer or .football directly
                            selectedCourtType = sportFromSelection 
                            selectedPlay = nil
                            editMode = true
                            viewOnlyMode = false
                            navigateToWhiteboard = true
                        }
                    }
                )
            }
            .alert(isPresented: $showLoginAlert) {
                Alert(
                    title: Text("Login Required"),
                    message: Text("You must be logged in to upload plays to the cloud."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(isPresented: $showDeleteConfirmationInHomeScreen) {
                Alert(
                    title: Text("Delete Play"),
                    message: Text("Are you sure you want to delete '\(playToDeleteInHomeScreen?.name ?? "")'? This cannot be undone."),
                    primaryButton: .destructive(Text("Delete")) {
                        if let play = playToDeleteInHomeScreen {
                            deletePlayFromHomeScreen(play: play)
                        }
                        playToDeleteInHomeScreen = nil
                    },
                    secondaryButton: .cancel {
                        playToDeleteInHomeScreen = nil
                    }
                )
            }
        }
        .edgesIgnoringSafeArea(.bottom)
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
        
        TeamService.shared.fetchTeamPlays(teamID: teamID) { plays in
            DispatchQueue.main.async {
                isLoadingTeamPlaysForHome = false
                self.teamPlaysForHome = plays
                print("DEBUG HomeScreen: Successfully fetched \(self.teamPlaysForHome.count) team plays for team ID \(teamID).")
                if self.teamPlaysForHome.isEmpty {
                    print("DEBUG HomeScreen: No plays found for team ID \(teamID) on home screen.")
                }
            }
        }
    }

    func deletePlayFromHomeScreen(play: Models.SavedPlay) {
        SavedPlayService.shared.deletePlayEverywhere(playID: play.id.uuidString) { _ in
            // Refresh homeScreenSavedPlays after deletion
            homeScreenSavedPlays = SavedPlayService.shared.loadPlaysLocally().sorted { $0.lastModified > $1.lastModified }
            // Also ensure the list within SavedPlaysScreen (if it keeps its own copy) is updated
            // This might require a more sophisticated state management or callback if SavedPlaysScreen
            // doesn't directly use homeScreenSavedPlays for its ForEach.
            // For the simplified version, SavedPlaysScreen will also use homeScreenSavedPlays.
        }
    }
}

struct SavedPlaysScreen: View {
    @Binding var selectedPlay: Models.SavedPlay?
    @Binding var editMode: Bool
    @Binding var viewOnlyMode: Bool
    @Binding var navigateToWhiteboard: Bool
    @Binding var showARSheet: Bool
    @Binding var arPlay: Models.SavedPlay?
    
    // Bindings for hoisted alert state & data from HomeScreen
    @Binding var playToDeleteFromParent: Models.SavedPlay?
    @Binding var showDeleteConfirmationFromParent: Bool
    @Binding var currentSavedPlays: [Models.SavedPlay] // This is the source of truth for plays
    @State private var showUploadToTeamSheet = false
    @State private var playToUploadToTeam: Models.SavedPlay? = nil
    @State private var userTeamID: String? = UserService.shared.getCurrentUserTeamID()
    @State private var showNoTeamAlert = false

    // Local state for UI elements within SavedPlaysScreen
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
            Color(.systemBackground).edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                Text("Saved Plays") // Restored title
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 30)
                    .padding(.bottom, 20)

                // Restored Cloud Sync Section
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
                                        // HomeScreen will update currentSavedPlays, which will reflect here
                                        // No need to manually reload here if currentSavedPlays is the source
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

                if currentSavedPlays.isEmpty { // Use currentSavedPlays from binding
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
                            // Group plays by sport
                            let groupedPlays = Dictionary(grouping: currentSavedPlays) { play -> String in
                                switch play.courtType {
                                case "Full Court", "Half Court":
                                    return "Basketball"
                                case "Soccer Pitch":
                                    return "Soccer"
                                case "Football Field":
                                    return "Football"
                                default:
                                    return "Other"
                                }
                            }
                            ForEach(["Basketball", "Soccer", "Football", "Other"], id: \.self) { sport in
                                if let plays = groupedPlays[sport], !plays.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("\(sport) Plays")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .padding(.top, 16)
                                            .padding(.leading, 8)
                                        ForEach(plays) { play in
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
                                                    arPlay = play
                                                    showARSheet = true
                                                },
                                                onDelete: {
                                                    self.playToDeleteFromParent = play
                                                    self.showDeleteConfirmationFromParent = true
                                                },
                                                onUpload: {
                                                    if Auth.auth().currentUser == nil {
                                                        uploadingPlayID = nil
                                                        uploadSuccessPlayID = nil
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
                                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                                    uploadSuccessPlayID = nil
                                                                }
                                                            } else {
                                                                syncStatus = "Upload failed: \(error?.localizedDescription ?? "Unknown error")"
                                                            }
                                                        }
                                                    }
                                                },
                                                isUploading: uploadingPlayID == play.id,
                                                uploadSuccess: uploadSuccessPlayID == play.id
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 60)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            // Data is now primarily driven by currentSavedPlays from HomeScreen
            // Sync status or other local UI can be reset if needed
            // syncStatus = ""
            if currentSavedPlays.isEmpty {
                 print("[DEBUG SavedPlaysScreen] onAppear, no plays from parent initially.")
            } else {
                 print("[DEBUG SavedPlaysScreen] onAppear, received \(currentSavedPlays.count) plays from parent.")
            }
        }
        .alert(isPresented: $showLoginAlert) { // Local alert for login requirement for upload
             Alert(
                 title: Text("Login Required"),
                 message: Text("You must be logged in to upload plays."),
                 dismissButton: .default(Text("OK"))
             )
         }
        .alert(isPresented: $showNoTeamAlert) {
            Alert(
                title: Text("Not in a Team"),
                message: Text("Join or create a team in your profile before uploading plays to a team."),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showUploadToTeamSheet) {
            if let play = playToUploadToTeam, let teamID = userTeamID {
                UploadPlayView(teamID: teamID, preselectedPlay: play)
            }
        }
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
                        onDelete()
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
