import Foundation
import SwiftUI

// Model that represents a saved play
struct SavedPlay: Codable, Identifiable {
    var id = UUID()
    var name: String
    var dateCreated: Date
    var lastModified: Date
    var courtType: String // "full" or "half"
    
    // Drawing data
    var drawings: [DrawingData]
    var players: [PlayerData]
    var basketballs: [BasketballData]
    
    // Convenience computed property to convert string to CourtType enum
    var courtTypeEnum: CourtType {
        return courtType == "full" ? .full : .half
    }
}

// Codable versions of our drawing models
struct DrawingData: Codable, Identifiable {
    var id: UUID
    var color: String // Store color as a string like "black"
    var lineWidth: CGFloat
    var type: String // "pen" or "arrow"
    var style: String // "normal", "squiggly", or "zigzag"
    var points: [PointData] // Array of points
    var normalizedPoints: [PointData]?
    var associatedPlayerIndex: Int?
    var isHighlightedDuringAnimation: Bool
}

struct PlayerData: Codable, Identifiable {
    var id: UUID
    var position: PointData
    var number: Int
    var normalizedPosition: PointData?
    var assignedPathId: UUID?
}

struct BasketballData: Codable {
    var position: PointData
    var normalizedPosition: PointData?
    var assignedPathId: UUID?
}

struct PointData: Codable {
    var x: CGFloat
    var y: CGFloat
    
    // Convert to CGPoint
    var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }
    
    // Create from CGPoint
    static func from(cgPoint: CGPoint) -> PointData {
        return PointData(x: cgPoint.x, y: cgPoint.y)
    }
}

// Service for managing saved plays
class SavedPlayService {
    static let shared = SavedPlayService()
    
    private let savedPlaysKey = "savedPlays"
    
    private init() {}
    
    // Retrieve all saved plays
    func getAllSavedPlays() -> [SavedPlay] {
        guard let data = UserDefaults.standard.data(forKey: savedPlaysKey) else {
            return []
        }
        
        do {
            let plays = try JSONDecoder().decode([SavedPlay].self, from: data)
            return plays
        } catch {
            print("Error loading saved plays: \(error)")
            return []
        }
    }
    
    // Save a new play or update an existing one
    func savePlay(_ play: SavedPlay) {
        var plays = getAllSavedPlays()
        
        // Check if we're updating an existing play
        if let index = plays.firstIndex(where: { $0.id == play.id }) {
            plays[index] = play
        } else {
            // It's a new play, so add it
            plays.append(play)
        }
        
        do {
            let data = try JSONEncoder().encode(plays)
            UserDefaults.standard.set(data, forKey: savedPlaysKey)
        } catch {
            print("Error saving plays: \(error)")
        }
    }
    
    // Delete a play
    func deletePlay(id: UUID) {
        var plays = getAllSavedPlays()
        plays.removeAll { $0.id == id }
        
        do {
            let data = try JSONEncoder().encode(plays)
            UserDefaults.standard.set(data, forKey: savedPlaysKey)
        } catch {
            print("Error deleting play: \(error)")
        }
    }
    
    // Convert between app models and storage models
    
    // Convert Drawing to DrawingData
    static func convertToDrawingData(drawing: Drawing) -> DrawingData {
        let colorString = "black" // For now, hardcoded to black as that's what the app uses
        
        return DrawingData(
            id: drawing.id,
            color: colorString,
            lineWidth: drawing.lineWidth,
            type: drawing.type.rawValue,
            style: drawing.style.rawValue,
            points: drawing.points.map { PointData.from(cgPoint: $0) },
            normalizedPoints: drawing.normalizedPoints?.map { PointData.from(cgPoint: $0) },
            associatedPlayerIndex: drawing.associatedPlayerIndex,
            isHighlightedDuringAnimation: drawing.isHighlightedDuringAnimation
        )
    }
    
    // Convert PlayerCircle to PlayerData
    static func convertToPlayerData(player: PlayerCircle) -> PlayerData {
        return PlayerData(
            id: player.id,
            position: PointData.from(cgPoint: player.position),
            number: player.number,
            normalizedPosition: player.normalizedPosition.map { PointData.from(cgPoint: $0) },
            assignedPathId: player.assignedPathId
        )
    }
    
    // Convert BasketballItem to BasketballData
    static func convertToBasketballData(basketball: BasketballItem) -> BasketballData {
        return BasketballData(
            position: PointData.from(cgPoint: basketball.position),
            normalizedPosition: basketball.normalizedPosition.map { PointData.from(cgPoint: $0) },
            assignedPathId: basketball.assignedPathId
        )
    }
    
    // Convert DrawingData to Drawing
    static func convertToDrawing(drawingData: DrawingData) -> Drawing {
        let type = DrawingTool(rawValue: drawingData.type) ?? .pen
        let style = PenStyle(rawValue: drawingData.style) ?? .normal
        let color = Color.black // For now, hardcoded
        
        let points = drawingData.points.map { $0.cgPoint }
        let normalizedPoints = drawingData.normalizedPoints?.map { $0.cgPoint }
        
        // Create path from points
        var path = Path()
        if !points.isEmpty {
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
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
    
    // Convert PlayerData to PlayerCircle
    static func convertToPlayer(playerData: PlayerData) -> PlayerCircle {
        var player = PlayerCircle(
            id: playerData.id,
            position: playerData.position.cgPoint,
            number: playerData.number,
            normalizedPosition: playerData.normalizedPosition?.cgPoint,
            assignedPathId: playerData.assignedPathId
        )
        return player
    }
    
    // Convert BasketballData to BasketballItem
    static func convertToBasketball(basketballData: BasketballData) -> BasketballItem {
        return BasketballItem(
            position: basketballData.position.cgPoint,
            normalizedPosition: basketballData.normalizedPosition?.cgPoint,
            assignedPathId: basketballData.assignedPathId
        )
    }
} 