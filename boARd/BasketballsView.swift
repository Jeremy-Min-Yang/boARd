import SwiftUI

struct BasketballsView: View {
    let courtType: CourtType
    @Binding var basketballs: [BasketballItem]
    @Binding var draggedBasketballIndex: Int?
    @Binding var currentTouchType: TouchInputType
    @Binding var selectedTool: DrawingTool
    var body: some View {
        ZStack {
            ForEach(basketballs.indices, id: \ .self) { index in
                let basketball = basketballs[index]
                BasketballView(position: basketball.position)
                    .position(basketball.position)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if selectedTool == .move {
                                    draggedBasketballIndex = index
                                    basketballs[index].position = value.location
                                }
                            }
                            .onEnded { value in
                                if selectedTool == .move && draggedBasketballIndex == index {
                                    let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
                                    let normalizedX = value.location.x / boundary.width
                                    let normalizedY = value.location.y / boundary.height
                                    basketballs[index].normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
                                }
                            },
                        including: selectedTool == .move ? .all : .subviews
                    )
            }
        }
    }
}

struct BasketballView: View {
    let position: CGPoint
    var body: some View {
        Image("basketball")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 40, height: 40)
            .contentShape(Circle())
    }
} 