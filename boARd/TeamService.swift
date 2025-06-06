import Foundation
import FirebaseFirestore

class TeamService {
    static let shared = TeamService()
    private let db = Firestore.firestore()
    
    // Fetch team info
    func fetchTeam(teamID: String, completion: @escaping (Team?) -> Void) {
        db.collection("teams").document(teamID).getDocument { snapshot, error in
            guard let data = try? snapshot?.data(as: Team.self) else {
                completion(nil)
                return
            }
            completion(data)
        }
    }
    
    // Fetch team plays
    func fetchTeamPlays(teamID: String, completion: @escaping ([TeamPlay]) -> Void) {
        db.collection("teams").document(teamID).collection("plays")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                let plays = snapshot?.documents.compactMap { try? $0.data(as: TeamPlay.self) } ?? []
                completion(plays)
            }
    }
    
    // Upload play to team
    func uploadPlay(teamID: String, play: TeamPlay, completion: @escaping (Bool) -> Void) {
        do {
            _ = try db.collection("teams").document(teamID).collection("plays")
                .addDocument(from: play) { error in
                    completion(error == nil)
                }
        } catch {
            completion(false)
        }
    }
} 