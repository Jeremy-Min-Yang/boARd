import SwiftUI

struct DrawingLayer: View {
    let courtType: CourtType
    @Binding var drawings: [Drawing]
    @Binding var currentDrawing: Drawing?
    @Binding var balls: [BallItem]
    @Binding var players: [PlayerCircle]
    @Binding var selectedTool: DrawingTool
    @Binding var selectedPenStyle: PenStyle
    @Binding var draggedBallIndex: Int?
    @Binding var draggedPlayerIndex: Int?
    @Binding var isPathAssignmentMode: Bool
    @Binding var selectedDrawingId: UUID?
    
    @State private var canvasActualSize: CGSize = .zero // To store the Canvas render size
    
    var body: some View {
        Canvas { context, size in
            // Update canvasActualSize whenever size changes
            // Use DispatchQueue.main.async to avoid modifying state during view update cycle
            if self.canvasActualSize != size { // Only update if different to reduce dispatches
                DispatchQueue.main.async {
                    self.canvasActualSize = size
                }
            }

            for drawing in drawings {
                let screenPoints = drawing.points.map { virtualToScreen($0, courtType: courtType, viewSize: size) }
                var drawingColor = drawing.color
                var lineWidth = drawing.lineWidth
                if isPathAssignmentMode && selectedDrawingId == drawing.id {
                    drawingColor = .green
                    lineWidth += 4
                } else if drawing.isHighlightedDuringAnimation {
                    drawingColor = .green.opacity(0.6)
                    lineWidth += 2
                }
                if drawing.type == .arrow {
                    if screenPoints.count >= 5 {
                        let lastPoint = screenPoints.last!
                        let firstPoint = screenPoints.first!
                        let arrowPath = createArrowPath(from: firstPoint, to: lastPoint)
                        context.stroke(arrowPath, with: .color(drawingColor), lineWidth: lineWidth)
                    }
                } else {
                    var path = Path()
                    if let first = screenPoints.first {
                        path.move(to: first)
                        for pt in screenPoints.dropFirst() {
                            path.addLine(to: pt)
                        }
                    }
                    context.stroke(
                        path,
                        with: .color(drawingColor),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            if let drawing = currentDrawing {
                let screenPoints = drawing.points.map { virtualToScreen($0, courtType: courtType, viewSize: size) }
                if drawing.type == .arrow {
                    if screenPoints.count >= 5 {
                        let lastPoint = screenPoints.last!
                        let firstPoint = screenPoints.first!
                        let arrowPath = createArrowPath(from: firstPoint, to: lastPoint)
                        context.stroke(arrowPath, with: .color(drawing.color), lineWidth: drawing.lineWidth)
                    }
                } else {
                    var path = Path()
                    if let first = screenPoints.first {
                        path.move(to: first)
                        for pt in screenPoints.dropFirst() {
                            path.addLine(to: pt)
                        }
                    }
                    context.stroke(
                        path,
                        with: .color(drawing.color),
                        style: StrokeStyle(lineWidth: drawing.lineWidth, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onEnded { value in
                    if isPathAssignmentMode {
                        let location = value.location
                        // Use the stored canvasActualSize for viewSize
                        handlePathSelection(at: location, currentCanvasSize: self.canvasActualSize)
                    }
                }
        )
        .allowsHitTesting(true)
    }
    
    private func handlePathSelection(at location: CGPoint, currentCanvasSize: CGSize) {
        // Ensure currentCanvasSize is valid before using it
        guard currentCanvasSize.width > 0, currentCanvasSize.height > 0 else {
            // Optionally, handle the case where size is not yet available or invalid
            print("Warning: handlePathSelection called with invalid currentCanvasSize: \(currentCanvasSize)")
            selectedDrawingId = nil // Or some other default behavior
            return
        }

        let virtualLocation = screenToVirtual(location, courtType: courtType, viewSize: currentCanvasSize)
        var tappedDrawingId: UUID? = nil
        let tapTolerance: CGFloat = 50.0
        var minDistanceFound = Double.infinity
        var closestDrawingId: UUID? = nil
        guard !drawings.isEmpty else {
            selectedDrawingId = nil
            return
        }
        for drawing in drawings {
            guard drawing.points.count > 1 else { continue }
            var minDistanceForThisDrawing = Double.infinity
            if drawing.type == .pen {
                for i in 0..<(drawing.points.count - 1) {
                    let start = drawing.points[i]
                    let end = drawing.points[i+1]
                    let distanceToSegment = location.minimumDistance(toLineSegment: start, end: end)
                    if distanceToSegment < minDistanceForThisDrawing {
                        minDistanceForThisDrawing = distanceToSegment
                    }
                }
            } else if drawing.type == .arrow {
                let start = drawing.points.first!
                let end = drawing.points.last!
                let distanceToSegment = location.minimumDistance(toLineSegment: start, end: end)
                if distanceToSegment < minDistanceForThisDrawing {
                    minDistanceForThisDrawing = distanceToSegment
                }
            }
            if minDistanceForThisDrawing < minDistanceFound {
                minDistanceFound = minDistanceForThisDrawing
                closestDrawingId = drawing.id
            }
            if minDistanceForThisDrawing < tapTolerance {
                if tappedDrawingId == nil || minDistanceForThisDrawing < minDistanceFound {
                    tappedDrawingId = drawing.id
                }
            }
        }
        if tappedDrawingId != nil {
            selectedDrawingId = tappedDrawingId
        } else {
            selectedDrawingId = closestDrawingId
        }
    }
    
    private func createArrowPath(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 20
        let arrowAngle: CGFloat = .pi / 6
        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        path.move(to: end)
        path.addLine(to: point1)
        path.move(to: end)
        path.addLine(to: point2)
        return path
    }
} 