import SwiftUI

// MARK: - Enums

enum CourtType: String, CaseIterable, Identifiable, Codable {
    case full = "Full Court"
    case half = "Half Court"
    case football = "Football Field"
    case soccer = "Soccer Pitch"
    // Add other cases if you have them e.g. custom, etc.

    var id: String { self.rawValue }

    // Provides the name of the image asset for this court type
    var imageName: String {
        switch self {
        case .full:
            return "fullcourt" // Was "full_court"
        case .half:
            return "halfcourt" // Was "half_court"
        case .football:
            return "footballplay" // Was "footballfield", using "footballplay.imageset"
        case .soccer:
            return "soccerfield"   // Correct, using "soccerfield.imageset"
        // Add cases for other court types if necessary
        }
    }

    // Calculates the size of the court for PDF rendering or display,
    // maintaining aspect ratio based on the provided container size.
    func size(for containerSize: CGSize) -> CGSize {
        let aspectRatio: CGFloat
        switch self {
        case .full:
            // Example aspect ratio for a full court (e.g., 94ft long by 50ft wide -> 94/50)
            // Or use the aspect ratio of your actual court image if that's more representative.
            aspectRatio = 94.0 / 50.0 
        case .half:
            // Example aspect ratio for a half court (e.g., 47ft long by 50ft wide -> 47/50)
            aspectRatio = 47.0 / 50.0
        case .football:
            aspectRatio = 300.0 / 160.0 // Standard American Football field (100yd x 53.33yd)
        case .soccer:
            aspectRatio = 105.0 / 68.0  // Common FIFA soccer pitch (105m x 68m)
        // Add cases for other court types if necessary
        }

        // Calculate dimensions to fit within the containerSize while maintaining aspect ratio
        let containerAspectRatio = containerSize.width / containerSize.height
        var newWidth = containerSize.width
        var newHeight = containerSize.height

        if containerAspectRatio > aspectRatio {
            // Container is wider than the court's aspect ratio (letterboxed top/bottom)
            newWidth = newHeight * aspectRatio
        } else {
            // Container is taller or same aspect ratio (pillarboxed left/right)
            newHeight = newWidth / aspectRatio
        }
        return CGSize(width: newWidth, height: newHeight)
    }
    
    // Returns the drawing boundary for this court type
    var drawingBoundary: DrawingBoundary {
        switch self {
        case .full:
            return DrawingBoundary.fullCourt
        case .half:
            return DrawingBoundary.halfCourt
        case .football:
            return DrawingBoundary.footballField
        case .soccer:
            return DrawingBoundary.soccerField
        }
    }

    // This can be removed if no longer used, or updated to use drawingBoundary.
    // For now, let it be, but ensure virtualToScreen/screenToVirtual don't use it directly.
    var virtualCourtSize: CGSize {
        switch self {
        case .full:
            return CGSize(width: 940, height: 500) // Example: 94ft x 50ft scaled up
        case .half:
            return CGSize(width: 470, height: 500) // Example: 47ft x 50ft scaled up
        case .football:
            return CGSize(width: 1000, height: 533) // Based on 300:160 aspect ratio
        case .soccer:
            return CGSize(width: 1000, height: 648) // Based on 105:68 aspect ratio
        }
    }
}

enum TouchInputType {
    case finger
    case pencil
    case unknown
}

enum DrawingTool: String, CaseIterable {
    case pen
    case arrow
    case move
    case addPlayer
    case addBall
    case addOpponent

    var iconName: String {
        switch self {
        case .pen: return "pencil"
        case .arrow: return "arrow.up.right"
        case .move: return "hand.point.up.left.fill"
        case .addPlayer: return "person.fill.badge.plus"
        case .addBall: return "basketball.fill"
        case .addOpponent: return "person.crop.circle.badge.xmark"
        }
    }
}

enum PenStyle: String, CaseIterable {
    case normal
    case squiggly
    case zigzag
    var iconName: String {
        switch self {
        case .normal: return "pencil.line"
        case .squiggly: return "scribble"
        case .zigzag: return "bolt.fill"
        }
    }
}

enum PlaybackState {
    case stopped
    case playing
    case paused
}

enum Action {
    case drawing(Drawing)
    case ball(BallItem)
    case player(PlayerCircle)
    case opponent(OpponentCircle)
}

enum MainTab: Int, CaseIterable, Identifiable {
    case home, team, add, plays, profile
    var id: Int { rawValue }
    var iconName: String {
        switch self {
        case .home: return "house"
        case .team: return "person.3"
        case .add: return "plus.circle.fill"
        case .plays: return "book"
        case .profile: return "person.circle"
        }
    }
    var label: String {
        switch self {
        case .home: return "Home"
        case .team: return "Team"
        case .add: return "Add"
        case .plays: return "Plays"
        case .profile: return "Profile"
        }
    }
}

// MARK: - Structs

struct DrawingBoundary {
    let width: CGFloat
    let height: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat

    static let fullCourt = DrawingBoundary(width: 1072, height: 569, offsetX: 0, offsetY: 0) // Basketball Full Court
    static let halfCourt = DrawingBoundary(width: 700, height: 855, offsetX: 0, offsetY: 98) // Basketball Half Court
    
    // Soccer: PDF is 527.97 (W) x 762.5 (H) [Portrait]. Rotated to Landscape for display.
    // Logical canvas matches rotated PDF: Width from PDF Height, Height from PDF Width.
    static let soccerField = DrawingBoundary(width: 850, height: 585, offsetX: 0, offsetY: 0)
    
    // Football: PDF is 282.24 (W) x 198.06 (H) [Landscape]. Aspect ratio ~1.425.
    // Scaled to width 1000 for drawing canvas: 1000 / (282.24 / 198.06) = 701.747...
    static let footballField = DrawingBoundary(width: 852, height: 590, offsetX: 0, offsetY: 0)

    func getFrameSize() -> CGSize { CGSize(width: width, height: height) }
    func getOffset() -> CGPoint { CGPoint(x: offsetX, y: offsetY) }
}

struct Drawing {
    var id: UUID = UUID()
    var path: Path
    var color: Color
    var lineWidth: CGFloat
    var type: DrawingTool
    var style: PenStyle
    var points: [CGPoint]
    var normalizedPoints: [CGPoint]?
    var isAssignedToPlayer: Bool = false
    var associatedPlayerIndex: Int?
    var isHighlightedDuringAnimation: Bool = false
}

struct PlayerCircle {
    var id = UUID()
    var position: CGPoint
    var number: Int
    var label: String? = nil // Optional label for soccer/football
    var color: Color = .green
    var normalizedPosition: CGPoint?
    var assignedPathId: UUID?
    var isMoving: Bool = false
}

struct BallItem {
    var id: UUID = UUID()
    var position: CGPoint
    var normalizedPosition: CGPoint?
    var assignedPathId: UUID?
    var assignedPlayerId: UUID?
    var ballKind: String
}

struct OpponentCircle {
    var id = UUID()
    var position: CGPoint
    var number: Int
    var color: Color = .red
    var normalizedPosition: CGPoint?
    var isMoving: Bool = false
}

struct PlayerAnimationData {
    let pathPoints: [CGPoint]
    let totalDistance: CGFloat
    let startTime: Date
    let duration: TimeInterval
}

// MARK: - Virtual/Screen Coordinate Mapping

func virtualToScreen(_ point: CGPoint, courtType: CourtType, viewSize: CGSize) -> CGPoint {
    let logicalSize = courtType.drawingBoundary.getFrameSize() // Use DrawingBoundary
    guard logicalSize.width > 0, logicalSize.height > 0 else { return point } // Avoid division by zero

    let scale = min(viewSize.width / logicalSize.width, viewSize.height / logicalSize.height)
    let offsetX = (viewSize.width - logicalSize.width * scale) / 2
    let offsetY = (viewSize.height - logicalSize.height * scale) / 2
    return CGPoint(
        x: point.x * scale + offsetX,
        y: point.y * scale + offsetY
    )
}

func screenToVirtual(_ point: CGPoint, courtType: CourtType, viewSize: CGSize) -> CGPoint {
    let logicalSize = courtType.drawingBoundary.getFrameSize() // Use DrawingBoundary
    guard viewSize.width > 0, viewSize.height > 0, logicalSize.width > 0, logicalSize.height > 0 else { return point }

    let scale = min(viewSize.width / logicalSize.width, viewSize.height / logicalSize.height)
    let offsetX = (viewSize.width - logicalSize.width * scale) / 2
    let offsetY = (viewSize.height - logicalSize.height * scale) / 2
    
    // Avoid division by zero for scale
    guard scale > 0 else { return .zero } // Or handle as an error/default

    return CGPoint(
        x: (point.x - offsetX) / scale,
        y: (point.y - offsetY) / scale
    )
}

// MARK: - Data Models for Persistence

struct Models {
    struct SavedPlay: Codable, Identifiable {
        public var firestoreID: String?
        public var id = UUID()
        public var userID: String?
        public var teamID: String?
        public var name: String
        public var dateCreated: Date
        public var lastModified: Date
        public var courtType: String

        public var drawings: [DrawingData]
        public var players: [PlayerData]
        public var balls: [BallData]
        public var opponents: [OpponentData]

        public var courtTypeEnum: CourtType {
            switch courtType {
            case "Full Court": return .full
            case "Half Court": return .half
            case "Football Field": return .football
            case "Soccer Pitch": return .soccer
            default: return .half // Default or handle error as appropriate
            }
        }
    }

    struct DrawingData: Codable, Identifiable {
        public var id: UUID
        public var color: String
        public var lineWidth: CGFloat
        public var type: String
        public var style: String
        public var points: [PointData]
        public var normalizedPoints: [PointData]?
        public var associatedPlayerIndex: Int?
        public var isHighlightedDuringAnimation: Bool
    }

    struct PlayerData: Codable, Identifiable {
        public var id: UUID
        public var position: PointData
        public var number: Int
        public var normalizedPosition: PointData?
        public var assignedPathId: UUID?
    }

    struct BallData: Codable, Identifiable {
        public var id = UUID()
        public var position: PointData
        public var normalizedPosition: PointData?
        public var assignedPathId: UUID?
        public var assignedPlayerId: UUID?
        public var ballKind: String
    }

    struct OpponentData: Codable, Identifiable {
        public var id: UUID
        public var position: PointData
        public var number: Int
        public var normalizedPosition: PointData?
    }

    struct PointData: Codable {
        public var x: CGFloat
        public var y: CGFloat

        public var cgPoint: CGPoint {
            return CGPoint(x: x, y: y)
        }

        public static func from(cgPoint: CGPoint) -> PointData {
            return PointData(x: cgPoint.x, y: cgPoint.y)
        }
    }
}

// MARK: - Team and TeamPlay Models for Firestore

struct Team: Identifiable, Codable {
    var id: String?
    var teamName: String
    var adminUserID: String
    var members: [String]
}

struct TeamPlay: Identifiable, Codable {
    var id: String?
    var name: String
    var createdBy: String
    var createdAt: Date
    var playData: Models.SavedPlay // Reference to your existing SavedPlay model
} 