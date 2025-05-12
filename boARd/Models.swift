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