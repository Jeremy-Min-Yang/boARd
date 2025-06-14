import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
// We need to access types from Models.swift
// No import needed as they're in the same module

public class SavedPlayService {
    static let shared = SavedPlayService()
    private var db: Firestore {
        Firestore.firestore()
    }
    private var playsCollection: CollectionReference { 
        return db.collection("plays")
    }
    
    private init() {}
    
    func savePlay(_ play: Models.SavedPlay, forUserID userID: String, teamID: String? = nil, completion: @escaping (Error?) -> Void) {
        var mutablePlay = play
        mutablePlay.userID = userID
        mutablePlay.teamID = teamID
        
        let documentID = mutablePlay.id.uuidString
        mutablePlay.firestoreID = documentID

        do {
            var playData: [String: Any] = [
                "id": mutablePlay.id.uuidString,
                "userID": userID,
                "name": mutablePlay.name,
                "dateCreated": mutablePlay.dateCreated,
                "lastModified": mutablePlay.lastModified,
                "courtType": mutablePlay.courtType,
                "drawings": mutablePlay.drawings.map { self.convertDrawingDataToDictionary($0) },
                "players": mutablePlay.players.map { self.convertPlayerDataToDictionary($0) },
                "balls": mutablePlay.balls.map { self.convertBallDataToDictionary($0) },
                "opponents": mutablePlay.opponents.map { self.convertOpponentDataToDictionary($0) }
            ]
            
            if let teamID = teamID {
                playData["teamID"] = teamID
            }
            
            playsCollection.document(documentID).setData(playData) { error in
                completion(error)
            }
        } catch {
            print("Error encoding play to save: \(error)")
            completion(error)
        }
    }

    func fetchPlays(forUserID userID: String, completion: @escaping (Result<[Models.SavedPlay], Error>) -> Void) {
        playsCollection.whereField("userID", isEqualTo: userID)
            .order(by: "lastModified", descending: true) 
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([])) 
                    return
                }
                
                let plays = documents.compactMap { document -> Models.SavedPlay? in
                    do {
                        // Manual conversion from document data to SavedPlay instead of using data(as:)
                        return self.convertDocumentToSavedPlay(document)
                    } catch {
                        print("Error decoding play: \(error) for document \(document.documentID)")
                        return nil
                    }
                }
                completion(.success(plays))
            }
    }
    
    // Helper method to convert document to SavedPlay
    private func convertDocumentToSavedPlay(_ document: QueryDocumentSnapshot) -> Models.SavedPlay? {
        let data = document.data()
        
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let name = data["name"] as? String,
              let dateCreatedTimestamp = data["dateCreated"] as? Timestamp,
              let lastModifiedTimestamp = data["lastModified"] as? Timestamp,
              let courtType = data["courtType"] as? String else {
            return nil
        }
        
        let teamID = data["teamID"] as? String
        
        // Convert timestamps to Date
        let dateCreated = dateCreatedTimestamp.dateValue()
        let lastModified = lastModifiedTimestamp.dateValue()
        
        // Parse drawings, players, basketballs, opponents
        let drawingsData = data["drawings"] as? [[String: Any]] ?? []
        let playersData = data["players"] as? [[String: Any]] ?? []
        let basketballsData = data["balls"] as? [[String: Any]] ?? []
        let opponentsData = data["opponents"] as? [[String: Any]] ?? []
        
        let drawings = drawingsData.compactMap { self.convertDictionaryToDrawingData($0) }
        let players = playersData.compactMap { self.convertDictionaryToPlayerData($0) }
        let balls = basketballsData.compactMap { self.convertDictionaryToBallData($0) }
        let opponents = opponentsData.compactMap { self.convertDictionaryToOpponentData($0) }
        
        return Models.SavedPlay(
            firestoreID: document.documentID,
            id: id,
            userID: data["userID"] as? String,
            teamID: teamID,
            name: name,
            dateCreated: dateCreated,
            lastModified: lastModified,
            courtType: courtType,
            drawings: drawings,
            players: players,
            balls: balls,
            opponents: opponents
        )
    }
    
    // Helper methods for conversion to/from dictionaries
    private func convertDrawingDataToDictionary(_ drawing: Models.DrawingData) -> [String: Any] {
        return [
            "id": drawing.id.uuidString,
            "color": drawing.color,
            "lineWidth": drawing.lineWidth,
            "type": drawing.type,
            "style": drawing.style,
            "points": drawing.points.map { ["x": $0.x, "y": $0.y] },
            "normalizedPoints": drawing.normalizedPoints?.map { ["x": $0.x, "y": $0.y] } ?? [],
            "associatedPlayerIndex": drawing.associatedPlayerIndex as Any,
            "isHighlightedDuringAnimation": drawing.isHighlightedDuringAnimation
        ]
    }
    
    private func convertPlayerDataToDictionary(_ player: Models.PlayerData) -> [String: Any] {
        return [
            "id": player.id.uuidString,
            "position": ["x": player.position.x, "y": player.position.y],
            "number": player.number,
            "normalizedPosition": player.normalizedPosition.map { ["x": $0.x, "y": $0.y] } as Any,
            "assignedPathId": player.assignedPathId?.uuidString as Any
        ]
    }
    
    private func convertBallDataToDictionary(_ ball: Models.BallData) -> [String: Any] {
        return [
            "id": ball.id.uuidString,
            "position": ["x": ball.position.x, "y": ball.position.y],
            "normalizedPosition": ball.normalizedPosition.map { ["x": $0.x, "y": $0.y] } as Any,
            "assignedPathId": ball.assignedPathId?.uuidString as Any,
            "assignedPlayerId": ball.assignedPlayerId?.uuidString as Any,
            "ballKind": ball.ballKind
        ]
    }
    
    private func convertOpponentDataToDictionary(_ opponent: Models.OpponentData) -> [String: Any] {
        return [
            "id": opponent.id.uuidString,
            "position": ["x": opponent.position.x, "y": opponent.position.y],
            "number": opponent.number,
            "normalizedPosition": opponent.normalizedPosition.map { ["x": $0.x, "y": $0.y] } as Any
        ]
    }
    
    private func convertDictionaryToDrawingData(_ dict: [String: Any]) -> Models.DrawingData? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let color = dict["color"] as? String,
              let lineWidth = dict["lineWidth"] as? CGFloat,
              let type = dict["type"] as? String,
              let style = dict["style"] as? String,
              let pointsData = dict["points"] as? [[String: Any]] else {
            return nil
        }
        
        let points = pointsData.compactMap { pointDict -> Models.PointData? in
            guard let x = pointDict["x"] as? CGFloat, 
                  let y = pointDict["y"] as? CGFloat else { 
                return nil 
            }
            return Models.PointData(x: x, y: y)
        }
        
        let normalizedPointsData = dict["normalizedPoints"] as? [[String: Any]] ?? []
        let normalizedPoints = normalizedPointsData.compactMap { pointDict -> Models.PointData? in
            guard let x = pointDict["x"] as? CGFloat, 
                  let y = pointDict["y"] as? CGFloat else { 
                return nil 
            }
            return Models.PointData(x: x, y: y)
        }
        
        return Models.DrawingData(
            id: id,
            color: color,
            lineWidth: lineWidth,
            type: type,
            style: style,
            points: points,
            normalizedPoints: normalizedPoints.isEmpty ? nil : normalizedPoints,
            associatedPlayerIndex: dict["associatedPlayerIndex"] as? Int,
            isHighlightedDuringAnimation: dict["isHighlightedDuringAnimation"] as? Bool ?? false
        )
    }
    
    private func convertDictionaryToPlayerData(_ dict: [String: Any]) -> Models.PlayerData? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let positionDict = dict["position"] as? [String: Any],
              let x = positionDict["x"] as? CGFloat,
              let y = positionDict["y"] as? CGFloat,
              let number = dict["number"] as? Int else {
            return nil
        }
        
        let position = Models.PointData(x: x, y: y)
        
        var normalizedPosition: Models.PointData? = nil
        if let normalizedPositionDict = dict["normalizedPosition"] as? [String: Any],
           let nx = normalizedPositionDict["x"] as? CGFloat,
           let ny = normalizedPositionDict["y"] as? CGFloat {
            normalizedPosition = Models.PointData(x: nx, y: ny)
        }
        
        var assignedPathId: UUID? = nil
        if let assignedPathIdString = dict["assignedPathId"] as? String {
            assignedPathId = UUID(uuidString: assignedPathIdString)
        }
        
        return Models.PlayerData(
            id: id,
            position: position,
            number: number,
            normalizedPosition: normalizedPosition,
            assignedPathId: assignedPathId
        )
    }
    
    private func convertDictionaryToBallData(_ dict: [String: Any]) -> Models.BallData? {
        guard let positionDict = dict["position"] as? [String: Any],
              let x = positionDict["x"] as? CGFloat,
              let y = positionDict["y"] as? CGFloat,
              let ballKind = dict["ballKind"] as? String else {
            return nil
        }
        
        let position = Models.PointData(x: x, y: y)
        
        var normalizedPosition: Models.PointData? = nil
        if let normalizedPositionDict = dict["normalizedPosition"] as? [String: Any],
           let nx = normalizedPositionDict["x"] as? CGFloat,
           let ny = normalizedPositionDict["y"] as? CGFloat {
            normalizedPosition = Models.PointData(x: nx, y: ny)
        }
        
        var assignedPathId: UUID? = nil
        if let assignedPathIdString = dict["assignedPathId"] as? String {
            assignedPathId = UUID(uuidString: assignedPathIdString)
        }
        
        var assignedPlayerId: UUID? = nil
        if let assignedPlayerIdString = dict["assignedPlayerId"] as? String, !assignedPlayerIdString.isEmpty {
            assignedPlayerId = UUID(uuidString: assignedPlayerIdString)
        }
        
        var id = UUID()
        if let idString = dict["id"] as? String,
           let parsedId = UUID(uuidString: idString) {
            id = parsedId
        }
        
        return Models.BallData(
            id: id,
            position: position,
            normalizedPosition: normalizedPosition,
            assignedPathId: assignedPathId,
            assignedPlayerId: assignedPlayerId,
            ballKind: ballKind
        )
    }
    
    private func convertDictionaryToOpponentData(_ dict: [String: Any]) -> Models.OpponentData? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let positionDict = dict["position"] as? [String: Any],
              let x = positionDict["x"] as? CGFloat,
              let y = positionDict["y"] as? CGFloat,
              let number = dict["number"] as? Int else {
            return nil
        }
        
        let position = Models.PointData(x: x, y: y)
        
        var normalizedPosition: Models.PointData? = nil
        if let normalizedPositionDict = dict["normalizedPosition"] as? [String: Any],
           let nx = normalizedPositionDict["x"] as? CGFloat,
           let ny = normalizedPositionDict["y"] as? CGFloat {
            normalizedPosition = Models.PointData(x: nx, y: ny)
        }
        
        return Models.OpponentData(
            id: id,
            position: position,
            number: number,
            normalizedPosition: normalizedPosition
        )
    }
    
    func deletePlay(playID: String, completion: @escaping (Error?) -> Void) {
        playsCollection.document(playID).delete {
            error in
            completion(error)
        }
    }
    
    // Convert to Drawing (UI model)
    static func convertToDrawing(drawingData: Models.DrawingData) -> Drawing {
        let type = DrawingTool(rawValue: drawingData.type) ?? .pen
        let style = PenStyle(rawValue: drawingData.style) ?? .normal
        let color = Color.black // Placeholder: Convert colorString back to Color
        let points = drawingData.points.map { $0.cgPoint }
        let normalizedPoints = drawingData.normalizedPoints?.map { $0.cgPoint }
        var path = Path()
        if !points.isEmpty {
            path.move(to: points[0])
            points.dropFirst().forEach { path.addLine(to: $0) }
        }
        return Drawing(
            id: drawingData.id,
            path: path,
            color: color,
            lineWidth: drawingData.lineWidth,
            type: type,
            style: style,
            points: points,
            normalizedPoints: normalizedPoints,
            isAssignedToPlayer: drawingData.associatedPlayerIndex != nil,
            associatedPlayerIndex: drawingData.associatedPlayerIndex,
            isHighlightedDuringAnimation: drawingData.isHighlightedDuringAnimation
        )
    }
    
    // Convert Drawing (UI model) to DrawingData
    static func convertToDrawingData(drawing: Drawing) -> Models.DrawingData {
        let colorString = "black" // Placeholder: Update if your Drawing model has dynamic color
        return Models.DrawingData(
            id: drawing.id,
            color: colorString,
            lineWidth: drawing.lineWidth,
            type: drawing.type.rawValue,
            style: drawing.style.rawValue,
            points: drawing.points.map { Models.PointData.from(cgPoint: $0) },
            normalizedPoints: drawing.normalizedPoints?.map { Models.PointData.from(cgPoint: $0) },
            associatedPlayerIndex: drawing.associatedPlayerIndex,
            isHighlightedDuringAnimation: drawing.isHighlightedDuringAnimation
        )
    }
    
    static func convertToPlayer(playerData: Models.PlayerData) -> PlayerCircle {
        return PlayerCircle(
            id: playerData.id,
            position: playerData.position.cgPoint,
            number: playerData.number,
            normalizedPosition: playerData.normalizedPosition?.cgPoint,
            assignedPathId: playerData.assignedPathId
        )
    }
    
    static func convertToPlayerData(player: PlayerCircle) -> Models.PlayerData {
        return Models.PlayerData(
            id: player.id,
            position: Models.PointData.from(cgPoint: player.position),
            number: player.number,
            normalizedPosition: player.normalizedPosition.map { Models.PointData.from(cgPoint: $0) },
            assignedPathId: player.assignedPathId
        )
    }
    
    static func convertToBallItem(ballData: Models.BallData) -> BallItem {
        return BallItem(
            id: ballData.id,
            position: ballData.position.cgPoint,
            normalizedPosition: ballData.normalizedPosition?.cgPoint,
            assignedPathId: ballData.assignedPathId,
            assignedPlayerId: ballData.assignedPlayerId,
            ballKind: ballData.ballKind
        )
    }
    
    static func convertToBallData(ball: BallItem) -> Models.BallData {
        return Models.BallData(
            id: ball.id,
            position: Models.PointData.from(cgPoint: ball.position),
            normalizedPosition: ball.normalizedPosition.map { Models.PointData.from(cgPoint: $0) },
            assignedPathId: ball.assignedPathId,
            assignedPlayerId: ball.assignedPlayerId,
            ballKind: ball.ballKind
        )
    }
    
    static func convertToOpponentData(opponent: OpponentCircle) -> Models.OpponentData {
        return Models.OpponentData(
            id: opponent.id,
            position: Models.PointData.from(cgPoint: opponent.position),
            number: opponent.number,
            normalizedPosition: opponent.normalizedPosition.map { Models.PointData.from(cgPoint: $0) }
        )
    }
    
    static func convertToOpponent(opponentData: Models.OpponentData) -> OpponentCircle {
        return OpponentCircle(
            id: opponentData.id,
            position: opponentData.position.cgPoint,
            number: opponentData.number,
            normalizedPosition: opponentData.normalizedPosition?.cgPoint
        )
    }
    
    // MARK: - Convenience methods for backward compatibility
    
    // These methods help existing code work without changes
    func savePlay(_ play: Models.SavedPlay) {
        // For backward compatibility - calls the new method with the current user's ID
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Error: Cannot save play without a signed-in user")
            return
        }
        savePlay(play, forUserID: userID) { error in
            if let error = error {
                print("Error saving play: \(error)")
            } else {
                // Update local storage after successful save
                var localPlays = self.loadPlaysLocally()
                if let idx = localPlays.firstIndex(where: { $0.id == play.id }) {
                    localPlays[idx] = play
                } else {
                    localPlays.append(play)
                }
                self.savePlaysLocally(localPlays)
            }
        }
    }
    
    // MARK: - Local Storage (Offline Mode)
    func savePlaysLocally(_ plays: [Models.SavedPlay]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(plays) {
            UserDefaults.standard.set(encoded, forKey: "savedPlays")
        }
    }

    func loadPlaysLocally() -> [Models.SavedPlay] {
        if let savedData = UserDefaults.standard.data(forKey: "savedPlays") {
            let decoder = JSONDecoder()
            if let loadedPlays = try? decoder.decode([Models.SavedPlay].self, from: savedData) {
                return loadedPlays
            }
        }
        return []
    }

    func uploadAllLocalPlaysToCloud(completion: ((Error?) -> Void)? = nil) {
        let localPlays = loadPlaysLocally()
        guard let userID = Auth.auth().currentUser?.uid else {
            completion?(NSError(domain: "NoUser", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not signed in"]))
            return
        }
        let group = DispatchGroup()
        var lastError: Error?
        for play in localPlays {
            group.enter()
            savePlay(play, forUserID: userID) { error in
                if let error = error {
                    lastError = error
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion?(lastError)
        }
    }

    func downloadAllCloudPlaysToLocal(completion: ((Error?) -> Void)? = nil) {
        guard let userID = Auth.auth().currentUser?.uid else {
            completion?(NSError(domain: "NoUser", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not signed in"]))
            return
        }
        fetchPlays(forUserID: userID) { result in
            switch result {
            case .success(let plays):
                self.savePlaysLocally(plays)
                completion?(nil)
            case .failure(let error):
                completion?(error)
            }
        }
    }

    // New function to fetch plays for a team
    func fetchPlaysForTeam(teamID: String, completion: @escaping (Result<[Models.SavedPlay], Error>) -> Void) {
        playsCollection.whereField("teamID", isEqualTo: teamID)
            .order(by: "lastModified", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                let plays = documents.compactMap { document -> Models.SavedPlay? in
                    // Use the existing conversion helper
                    return self.convertDocumentToSavedPlay(document)
                }
                completion(.success(plays))
            }
    }

    // Delete a play both locally and in the cloud
    func deletePlayEverywhere(playID: String, completion: ((Error?) -> Void)? = nil) {
        // Remove from local storage
        var localPlays = self.loadPlaysLocally()
        localPlays.removeAll { $0.id.uuidString == playID }
        self.savePlaysLocally(localPlays)
        // Remove from Firestore
        self.deletePlay(playID: playID) { error in
            completion?(error)
        }
    }
} 
