import SwiftUI

struct TeamPlaysView: View {
    let teamID: String
    @State private var plays: [TeamPlay] = []
    @State private var showUploadSheet = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showJoinTeamAlert = false
    @State private var showCreateTeamAlert = false
    @State private var joinTeamID = ""
    @State private var createTeamName = ""
    @State private var joinTeamError: String? = nil
    @State private var createTeamError: String? = nil
    @State private var joinTeamSuccess: Bool = false
    @State private var createTeamSuccess: Bool = false
    @State private var teamName: String? = nil

    var body: some View {
        VStack {
            if teamID.isEmpty {
                HStack(spacing: 20) {
                    Button(action: { showJoinTeamAlert = true }) {
                        Label("Join Team", systemImage: "person.badge.plus")
                    }
                    Button(action: { showCreateTeamAlert = true }) {
                        Label("Create Team", systemImage: "plus.circle")
                    }
                }
                .padding(.top)
            } else {
                if let name = teamName {
                    Text(name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                } else {
                    ProgressView("Loading team info...")
                        .padding(.top)
                }
            }
            if isLoading {
                ProgressView("Loading plays...")
            } else if let errorMessage = errorMessage {
                Text(errorMessage).foregroundColor(.red)
            } else if plays.isEmpty {
                Text("No plays uploaded yet.")
                    .foregroundColor(.gray)
            } else {
                List(plays) { play in
                    VStack(alignment: .leading) {
                        Text(play.name)
                            .font(.headline)
                        Text("By: \(play.createdBy)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(play.createdAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Team Plays")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showUploadSheet = true }) {
                    Image(systemName: "plus")
                }
                .disabled(teamID.isEmpty)
            }
        }
        .onAppear {
            loadPlays()
            if !teamID.isEmpty {
                TeamService.shared.fetchTeam(teamID: teamID) { team in
                    self.teamName = team?.teamName ?? "Team"
                }
            }
        }
        .onChange(of: teamID) { _ in
            loadPlays()
            if !teamID.isEmpty {
                TeamService.shared.fetchTeam(teamID: teamID) { team in
                    self.teamName = team?.teamName ?? "Team"
                }
            } else {
                self.teamName = nil
            }
        }
        .sheet(isPresented: $showUploadSheet, onDismiss: loadPlays) {
            UploadPlayView(teamID: teamID, preselectedPlay: nil)
        }
        .alert("Join a Team", isPresented: $showJoinTeamAlert, actions: {
            TextField("Enter Team ID", text: $joinTeamID)
            Button("Join") {
                joinTeamError = nil
                UserService.shared.joinTeam(teamID: joinTeamID) { error in
                    if let error = error {
                        joinTeamError = error.localizedDescription
                    } else {
                        joinTeamSuccess = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            if let error = joinTeamError {
                Text(error)
            } else if joinTeamSuccess {
                Text("Successfully joined team!")
            }
        })
        .alert("Create a Team", isPresented: $showCreateTeamAlert, actions: {
            TextField("Enter Team Name", text: $createTeamName)
            Button("Create") {
                createTeamError = nil
                UserService.shared.createTeam(teamName: createTeamName) { teamID, error in
                    if let error = error {
                        createTeamError = error.localizedDescription
                    } else {
                        createTeamSuccess = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }, message: {
            if let error = createTeamError {
                Text(error)
            } else if createTeamSuccess {
                Text("Team created successfully!")
            }
        })
    }
    
    func loadPlays() {
        guard !teamID.isEmpty else {
            self.plays = []
            self.isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        TeamService.shared.fetchTeamPlays(teamID: teamID) { fetchedPlays in
            DispatchQueue.main.async {
                self.plays = fetchedPlays
                self.isLoading = false
            }
        }
    }
} 