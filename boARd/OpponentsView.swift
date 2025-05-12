import SwiftUI

struct OpponentsView: View {
    let courtType: CourtType
    @Binding var opponents: [OpponentCircle]
    @Binding var draggedOpponentIndex: Int?
    @Binding var currentTouchType: TouchInputType
    @Binding var selectedTool: DrawingTool
    var body: some View {
        ZStack {
            ForEach(opponents.indices, id: \ .self) { index in
                let opponent = opponents[index]
                OpponentCircleView(
                    position: opponent.position,
                    number: opponent.number,
                    color: .red,
                    isMoving: opponent.isMoving
                )
                .position(opponent.position)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if selectedTool == .move {
                                draggedOpponentIndex = index
                                opponents[index].position = value.location
                            }
                        }
                        .onEnded { value in
                            if selectedTool == .move && draggedOpponentIndex == index {
                                let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
                                let normalizedX = value.location.x / boundary.width
                                let normalizedY = value.location.y / boundary.height
                                opponents[index].normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
                            }
                        },
                    including: selectedTool == .move ? .all : .subviews
                )
                .zIndex(opponent.isMoving ? 20 : 1)
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