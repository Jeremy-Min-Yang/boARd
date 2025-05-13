import SwiftUI

struct HomeScreen: View {
    @State private var selectedTab: MainTab = .home
    @State private var showCourtOptions = false
    @State private var selectedCourtType: CourtType?
    @State private var navigateToWhiteboard = false
    @State private var savedPlays: [SavedPlay] = []
    @State private var selectedPlay: SavedPlay?
    @State private var editMode = false
    @State private var viewOnlyMode = false
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
                    VStack(spacing: 0) {
                        Spacer().frame(height: 40)
                        // Logo and welcome
                        Image(systemName: "basketball")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.blue)
                        Text("boARd")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .padding(.top, 8)
                        Text("Welcome back, Coach!")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 24)
                        // Create New Play button
                        Button(action: { showCourtOptions = true }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Create New Play")
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .frame(maxWidth: 260)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .shadow(radius: 4)
                        }
                        .padding(.bottom, 32)
                        // Recent Plays
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Plays")
                                .font(.headline)
                                .padding(.leading)
                            if savedPlays.isEmpty {
                                Text("No recent plays yet.")
                                    .foregroundColor(.gray)
                                    .padding(.leading)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    // Court selection overlay
                    if showCourtOptions {
                        CourtSelectionView(isPresented: $showCourtOptions, onCourtSelected: { courtType in
                            selectedCourtType = courtType
                            selectedPlay = nil
                            editMode = true
                            viewOnlyMode = false
                            navigateToWhiteboard = true
                        })
                    }
                    // Navigation link to whiteboard
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
                    .onAppear {
                        savedPlays = SavedPlayService.shared.getAllSavedPlays()
                            .sorted { $0.lastModified > $1.lastModified }
                    }
                case .team:
                    Text("Team View")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .add:
                    EmptyView()
                case .plays:
                    SavedPlaysScreen()
                case .profile:
                    Text("Profile View")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            MainTabBar(selectedTab: $selectedTab) {
                showCourtOptions = true
            }
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct SavedPlaysScreen: View {
    @State private var showCourtOptions = false
    @State private var selectedCourtType: CourtType?
    @State private var navigateToWhiteboard = false
    @State private var selectedPlay: SavedPlay?
    @State private var editMode = false
    @State private var viewOnlyMode = false
    @State private var savedPlays: [SavedPlay] = []
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    var body: some View {
        NavigationView {
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
                                            onDelete: {
                                                deletePlay(play)
                                            }
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
                if showCourtOptions {
                    CourtSelectionView(isPresented: $showCourtOptions, onCourtSelected: { courtType in
                        selectedCourtType = courtType
                        selectedPlay = nil
                        editMode = true
                        viewOnlyMode = false
                        navigateToWhiteboard = true
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
            }
            .navigationBarHidden(true)
            .onAppear {
                savedPlays = SavedPlayService.shared.getAllSavedPlays()
                    .sorted { $0.lastModified > $1.lastModified }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    private func deletePlay(_ play: SavedPlay) {
        savedPlays.removeAll { $0.id == play.id }
        SavedPlayService.shared.deletePlay(id: play.id)
    }
}

struct SavedPlayRow: View {
    let play: SavedPlay
    let dateFormatter: DateFormatter
    let onEdit: () -> Void
    let onView: () -> Void
    let onDelete: () -> Void
    
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
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
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
                            Image(systemName: tab.iconName)
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
        HomeScreen()
    }
}
