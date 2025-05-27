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
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 20)
                case .team:
                    Text("Team View")
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
