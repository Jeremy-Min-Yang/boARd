import SwiftUI

struct BasketballsView: View {
    let courtType: CourtType
    @Binding var balls: [BallItem]
    @Binding var players: [PlayerCircle]
    @Binding var draggedBasketballIndex: Int?
    @Binding var currentTouchType: TouchInputType
    @Binding var selectedTool: DrawingTool
    var isAssigningBall: Bool = false
    @Binding var selectedBasketballIndex: Int?
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Render unassigned basketballs at their own position
                ForEach(balls.indices, id: \.self) { index in
                    let ball = balls[index]
                    if ball.assignedPlayerId == nil {
                        BasketballView(ballKind: ball.ballKind, position: virtualToScreen(ball.position, courtType: courtType, viewSize: geometry.size))
                            .position(virtualToScreen(ball.position, courtType: courtType, viewSize: geometry.size))
                            .overlay(
                                Group {
                                    if isAssigningBall && selectedBasketballIndex == index {
                                        Circle()
                                            .stroke(Color.blue, lineWidth: 4)
                                            .frame(width: 48, height: 48)
                                    }
                                }
                            )
                            .onTapGesture {
                                if isAssigningBall {
                                    selectedBasketballIndex = index
                                }
                            }
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if selectedTool == .move {
                                            draggedBasketballIndex = index
                                            let virtualPos = screenToVirtual(value.location, courtType: courtType, viewSize: geometry.size)
                                            balls[index].position = virtualPos
                                        }
                                    }
                                    .onEnded { value in
                                        if selectedTool == .move && draggedBasketballIndex == index {
                                            let virtualPos = screenToVirtual(value.location, courtType: courtType, viewSize: geometry.size)
                                            balls[index].normalizedPosition = CGPoint(x: virtualPos.x / courtType.virtualCourtSize.width, y: virtualPos.y / courtType.virtualCourtSize.height)
                                        }
                                    },
                                including: selectedTool == .move ? .all : .subviews
                            )
                    }
                }
                // Render assigned basketballs at the 2 o'clock position of their player
                ForEach(balls.indices, id: \.self) { index in
                    let ball = balls[index]
                    if let assignedId = ball.assignedPlayerId,
                       let player = players.first(where: { $0.id == assignedId }) {
                        // Calculate 2 o'clock offset
                        let offset: CGFloat = 30
                        let angle: CGFloat = .pi / 6 // 30 degrees
                        let dx = offset * cos(angle)
                        let dy = -offset * sin(angle)
                        let playerPos = virtualToScreen(player.position, courtType: courtType, viewSize: geometry.size)
                        let displayPos = CGPoint(x: playerPos.x + dx, y: playerPos.y + dy)
                        BasketballView(ballKind: ball.ballKind, position: displayPos)
                            .position(displayPos)
                            .zIndex(100) // Ensure above player
                    }
                }
            }
        }
    }
}

struct BasketballView: View {
    let ballKind: String
    let position: CGPoint
    var body: some View {
        Image(ballKind)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 40, height: 40)
            .contentShape(Circle())
    }
} 