import SwiftUI

struct PlayersView: View {
    let courtType: CourtType
    @Binding var players: [PlayerCircle]
    @Binding var draggedPlayerIndex: Int?
    @Binding var currentTouchType: TouchInputType
    @Binding var selectedTool: DrawingTool
    @Binding var isPathAssignmentMode: Bool
    @Binding var selectedDrawingId: UUID?
    @Binding var drawings: [Drawing]
    var onAssignPath: (UUID, Int) -> Void
    // For assign ball mode
    var isAssigningBall: Bool = false
    @Binding var selectedBasketballIndex: Int?
    var onAssignBall: ((Int) -> Void)? = nil
    private func getPlayerColor(_ player: PlayerCircle) -> Color { .green }
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(players.indices, id: \.self) { index in
                    let player = players[index]
                    let playerColor = getPlayerColor(player)
                    ZStack {
                        if player.assignedPathId != nil {
                            Circle()
                                .stroke(Color.green, lineWidth: 3)
                                .frame(width: 56, height: 56)
                        }
                        PlayerCircleView(
                            position: virtualToScreen(player.position, courtType: courtType, viewSize: geometry.size),
                            number: player.number,
                            label: player.label,
                            color: playerColor,
                            isMoving: player.isMoving
                        )
                    }
                    .position(virtualToScreen(player.position, courtType: courtType, viewSize: geometry.size))
                    .onTapGesture {
                        if isPathAssignmentMode, let drawingId = selectedDrawingId {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onAssignPath(drawingId, index)
                            }
                        } else if isAssigningBall, let assignBall = onAssignBall {
                            assignBall(index)
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if selectedTool == .move && !isPathAssignmentMode {
                                    draggedPlayerIndex = index
                                    let virtualPos = screenToVirtual(value.location, courtType: courtType, viewSize: geometry.size)
                                    players[index].position = virtualPos
                                }
                            }
                            .onEnded { value in
                                if selectedTool == .move && !isPathAssignmentMode && draggedPlayerIndex == index {
                                    let virtualPos = screenToVirtual(value.location, courtType: courtType, viewSize: geometry.size)
                                    players[index].normalizedPosition = CGPoint(x: virtualPos.x / courtType.virtualCourtSize.width, y: virtualPos.y / courtType.virtualCourtSize.height)
                                }
                            },
                        including: selectedTool == .move ? .all : .subviews
                    )
                    .zIndex(player.isMoving ? 20 : 1)
                }
            }
        }
    }
}

struct PlayerCircleView: View {
    let position: CGPoint
    let number: Int
    let label: String?
    let color: Color
    var isMoving: Bool = false
    var body: some View {
        ZStack {
            if isMoving {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 54, height: 54)
                    .blur(radius: 4)
            }
            Circle()
                .stroke(Color.black, lineWidth: 2)
                .background(Circle().fill(color))
                .frame(width: 50, height: 50)
            Text(label ?? "\(number)")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(width: 50, height: 50)
        .contentShape(Circle())
    }
} 