import SwiftUI

// MARK: - Enums

enum CourtType {
    case full
    case half
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
    case addBasketball

    var iconName: String {
        switch self {
        case .pen: return "pencil"
        case .arrow: return "arrow.up.right"
        case .move: return "hand.point.up.left.fill"
        case .addPlayer: return "person.fill.badge.plus"
        case .addBasketball: return "basketball.fill"
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
    case basketball(BasketballItem)
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
    static let fullCourt = DrawingBoundary(width: 1072, height: 569, offsetX: 0, offsetY: 0)
    static let halfCourt = DrawingBoundary(width: 700, height: 855, offsetX: 0, offsetY: 98)
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
    var color: Color = .green
    var normalizedPosition: CGPoint?
    var assignedPathId: UUID?
    var isMoving: Bool = false
}

struct BasketballItem {
    var position: CGPoint
    var normalizedPosition: CGPoint?
    var assignedPathId: UUID?
    var assignedPlayerId: UUID?
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

extension CourtType {
    var virtualCourtSize: CGSize {
        switch self {
        case .full:
            return CGSize(width: 1072, height: 569)
        case .half:
            return CGSize(width: 700, height: 855)
        }
    }
}

// MARK: - Virtual/Screen Coordinate Mapping

func virtualToScreen(_ point: CGPoint, courtType: CourtType, viewSize: CGSize) -> CGPoint {
    let courtSize = courtType.virtualCourtSize
    let scale = min(viewSize.width / courtSize.width, viewSize.height / courtSize.height)
    let offsetX = (viewSize.width - courtSize.width * scale) / 2
    let offsetY = (viewSize.height - courtSize.height * scale) / 2
    return CGPoint(
        x: point.x * scale + offsetX,
        y: point.y * scale + offsetY
    )
}

func screenToVirtual(_ point: CGPoint, courtType: CourtType, viewSize: CGSize) -> CGPoint {
    let courtSize = courtType.virtualCourtSize
    let scale = min(viewSize.width / courtSize.width, viewSize.height / courtSize.height)
    let offsetX = (viewSize.width - courtSize.width * scale) / 2
    let offsetY = (viewSize.height - courtSize.height * scale) / 2
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
        public var name: String
        public var dateCreated: Date
        public var lastModified: Date
        public var courtType: String

        public var drawings: [DrawingData]
        public var players: [PlayerData]
        public var basketballs: [BasketballData]

        public var courtTypeEnum: CourtType {
            return courtType == "full" ? .full : .half
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

    struct BasketballData: Codable, Identifiable {
        public var id = UUID()
        public var position: PointData
        public var normalizedPosition: PointData?
        public var assignedPathId: UUID?
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