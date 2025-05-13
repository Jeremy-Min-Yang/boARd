import SwiftUI

struct OpponentsView: View {
    let courtType: CourtType
    @Binding var opponents: [OpponentCircle]
    @Binding var draggedOpponentIndex: Int?
    @Binding var currentTouchType: TouchInputType
    @Binding var selectedTool: DrawingTool
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(opponents.indices, id: \.self) { index in
                    let opponent = opponents[index]
                    OpponentCircleView(
                        position: virtualToScreen(opponent.position, courtType: courtType, viewSize: geometry.size),
                        number: opponent.number,
                        color: .red,
                        isMoving: opponent.isMoving
                    )
                    .position(virtualToScreen(opponent.position, courtType: courtType, viewSize: geometry.size))
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if selectedTool == .move {
                                    draggedOpponentIndex = index
                                    let virtualPos = screenToVirtual(value.location, courtType: courtType, viewSize: geometry.size)
                                    opponents[index].position = virtualPos
                                }
                            }
                            .onEnded { value in
                                if selectedTool == .move && draggedOpponentIndex == index {
                                    let virtualPos = screenToVirtual(value.location, courtType: courtType, viewSize: geometry.size)
                                    opponents[index].normalizedPosition = CGPoint(x: virtualPos.x / courtType.virtualCourtSize.width, y: virtualPos.y / courtType.virtualCourtSize.height)
                                }
                            },
                        including: selectedTool == .move ? .all : .subviews
                    )
                    .zIndex(opponent.isMoving ? 20 : 1)
                }
            }
        }
    }
}

struct OpponentCircleView: View {
    let position: CGPoint
    let number: Int
    let color: Color
    var isMoving: Bool = false
    var body: some View {
        ZStack {
            if isMoving {
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 54, height: 54)
                    .blur(radius: 4)
            }
            Circle()
                .stroke(Color.black, lineWidth: 2)
                .background(Circle().fill(color))
                .frame(width: 50, height: 50)
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(width: 50, height: 50)
        .contentShape(Circle())
    }
} 