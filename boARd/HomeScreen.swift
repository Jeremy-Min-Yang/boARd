import SwiftUI

struct HomeScreen: View {
    @State private var showCourtOptions = false
    @State private var selectedCourtType: CourtType?
    @State private var navigateToWhiteboard = false
    @State private var selectedPlay: SavedPlay?
    @State private var editMode = false
    @State private var viewOnlyMode = false
    
    // State to keep track of saved plays
    @State private var savedPlays: [SavedPlay] = []
    
    // Format date objects
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                // Main content
                VStack(spacing: 0) {
                    // App title
                    Text("boARd")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 30)
                        .padding(.bottom, 20)
                    
                    // Saved plays section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Saved Plays")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Spacer()
                        }
                        
                        if savedPlays.isEmpty {
                            // Empty state message
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
                            // List of saved plays
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
                
                // Floating action button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showCourtOptions.toggle()
                        }) {
                            Image(systemName: "plus")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding(25)
                    }
                }
                
                // Court selection overlay
                if showCourtOptions {
                    CourtSelectionView(isPresented: $showCourtOptions, onCourtSelected: { courtType in
                        selectedCourtType = courtType
                        selectedPlay = nil // Make sure we're not editing an existing play
                        editMode = true  // New plays are always editable
                        viewOnlyMode = false
                        navigateToWhiteboard = true
                    })
                }
                
                // Navigation link to whiteboard
                NavigationLink(
                    destination: Group {
                        if let play = selectedPlay {
                            // Pass the play and editMode directly
                            WhiteboardView(courtType: play.courtTypeEnum, playToLoad: play, isEditable: editMode)
                        } else if let courtType = selectedCourtType {
                            // New whiteboard (default editable)
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
                // Load saved plays each time the view appears
                savedPlays = SavedPlayService.shared.getAllSavedPlays()
                    .sorted { $0.lastModified > $1.lastModified } // Sort by most recent
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func deletePlay(_ play: SavedPlay) {
        // Remove from local state first for immediate UI update
        savedPlays.removeAll { $0.id == play.id }
        
        // Delete from storage
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

struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreen()
    }
}
