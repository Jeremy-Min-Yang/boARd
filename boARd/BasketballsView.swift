import SwiftUI

struct BasketballsView: View {
    let courtType: CourtType
    @Binding var basketballs: [BasketballItem]
    @Binding var draggedBasketballIndex: Int?
    @Binding var currentTouchType: TouchInputType
    @Binding var selectedTool: DrawingTool
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(basketballs.indices, id: \.self) { index in
                    let basketball = basketballs[index]
                    BasketballView(position: virtualToScreen(basketball.position, courtType: courtType, viewSize: geometry.size))
                        .position(virtualToScreen(basketball.position, courtType: courtType, viewSize: geometry.size))
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if selectedTool == .move {
                                        draggedBasketballIndex = index
                                        let virtualPos = screenToVirtual(value.location, courtType: courtType, viewSize: geometry.size)
                                        basketballs[index].position = virtualPos
                                    }
                                }
                                .onEnded { value in
                                    if selectedTool == .move && draggedBasketballIndex == index {
                                        let virtualPos = screenToVirtual(value.location, courtType: courtType, viewSize: geometry.size)
                                        basketballs[index].normalizedPosition = CGPoint(x: virtualPos.x / courtType.virtualCourtSize.width, y: virtualPos.y / courtType.virtualCourtSize.height)
                                    }
                                },
                            including: selectedTool == .move ? .all : .subviews
                        )
                }
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