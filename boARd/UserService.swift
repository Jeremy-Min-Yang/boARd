import Foundation
import FirebaseFirestore
import FirebaseAuth

class UserService {
    static let shared = UserService()
    private var db: Firestore {
        Firestore.firestore()
    }
    private var usersCollection: CollectionReference {
        db.collection("users")
    }
    private var teamsCollection: CollectionReference {
        db.collection("teams")
    }

    private let userDefaultsTeamKey = "currentUserTeamID"

    private init() {}

    // MARK: - Team Management

    func joinTeam(teamID: String, completion: @escaping (Error?) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated."]))
            return
        }

        let teamDocRef = teamsCollection.document(teamID)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let teamDocument: DocumentSnapshot
            do {
                try teamDocument = transaction.getDocument(teamDocRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard teamDocument.exists else {
                let noTeamError = NSError(domain: "UserService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Team ID not found."])
                errorPointer?.pointee = noTeamError
                return nil
            }

            // Add user to the team's member list
            transaction.updateData(["members": FieldValue.arrayUnion([userID])], forDocument: teamDocRef)

            // Update user's profile with the teamID
            let userDocRef = self.usersCollection.document(userID)
            transaction.setData(["currentTeamID": teamID], forDocument: userDocRef, merge: true)
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("Transaction failed: \(error)")
                completion(error)
            } else {
                print("Successfully joined team \(teamID) and updated user profile.")
                // Store in UserDefaults for easy access
                UserDefaults.standard.set(teamID, forKey: self.userDefaultsTeamKey)
                completion(nil)
            }
        }
    }

    func getCurrentUserTeamID() -> String? {
        // Prioritize Firestore for canonical source if implementing fetch, but UserDefaults is quick
        return UserDefaults.standard.string(forKey: userDefaultsTeamKey)
    }
    
    func fetchAndUpdateUserTeamIDFromFirestore(completion: (() -> Void)? = nil) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion?()
            return
        }
        usersCollection.document(userID).getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            if let document = document, document.exists, let teamID = document.data()?["currentTeamID"] as? String {
                UserDefaults.standard.set(teamID, forKey: self.userDefaultsTeamKey)
                print("Fetched and updated UserDefaults teamID from Firestore: \(teamID)")
            } else if let error = error {
                print("Error fetching user's teamID: \(error.localizedDescription)")
            } else {
                 print("User document does not exist or no teamID found, clearing from UserDefaults.")
                 UserDefaults.standard.removeObject(forKey: self.userDefaultsTeamKey)
            }
            completion?()
        }
    }


    func leaveTeam(completion: @escaping (Error?) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated."]))
            return
        }

        guard let teamID = getCurrentUserTeamID() else {
            completion(NSError(domain: "UserService", code: 400, userInfo: [NSLocalizedDescriptionKey: "User is not part of any team."]))
            return
        }

        let teamDocRef = teamsCollection.document(teamID)
        let userDocRef = usersCollection.document(userID)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            // Remove user from the team's member list
            transaction.updateData(["members": FieldValue.arrayRemove([userID])], forDocument: teamDocRef)
            
            // Remove teamID from user's profile
            transaction.updateData(["currentTeamID": FieldValue.delete()], forDocument: userDocRef)
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("Transaction failed while leaving team: \(error)")
                completion(error)
            } else {
                print("Successfully left team \(teamID).")
                UserDefaults.standard.removeObject(forKey: self.userDefaultsTeamKey)
                completion(nil)
            }
        }
    }
    
    // You might also want a function to create a team
    func createTeam(teamName: String, completion: @escaping (String?, Error?) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion(nil, NSError(domain: "UserService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated."]))
            return
        }

        // Generate a new team document reference with an auto-generated ID
        let newTeamRef = teamsCollection.document()
        let newTeamID = newTeamRef.documentID

        let teamData: [String: Any] = [
            "teamName": teamName,
            "adminUserID": userID,
            "members": [userID] // Creator is the first member
            // You can add a 'createdDate': FieldValue.serverTimestamp() if needed
        ]
        
        let userDocRef = self.usersCollection.document(userID)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            // Create the new team
            transaction.setData(teamData, forDocument: newTeamRef)
            
            // Update the user's currentTeamID to this new team
            transaction.setData(["currentTeamID": newTeamID], forDocument: userDocRef, merge: true)
            
            return nil
        }) { (object, error) in
            if let error = error {
                print("Transaction failed while creating team: \(error)")
                completion(nil, error)
            } else {
                print("Successfully created team '\(teamName)' with ID \(newTeamID) and updated user profile.")
                UserDefaults.standard.set(newTeamID, forKey: self.userDefaultsTeamKey)
                completion(newTeamID, nil)
            }
        }
    }
} 