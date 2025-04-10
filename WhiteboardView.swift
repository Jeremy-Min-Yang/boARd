private func handleTouchChanged(touchType: TouchInputType, location: CGPoint) {
    // Update current touch type
    currentTouchType = touchType
    
    // Get screen and court dimensions for normalization
    let screenSize = UIScreen.main.bounds.size
    let (courtWidth, courtHeight) = getCourtDimensions()
    
    // Adjust the location to ensure it's properly positioned on the court
    let adjustedLocation = adjustTouchLocation(location, in: screenSize, courtWidth: courtWidth, courtHeight: courtHeight)
    
    // If it's a pencil, show the indicator at the adjusted position
    showPencilIndicator = (touchType == .pencil)
    lastTouchLocation = adjustedLocation
    
    // If we're in drawing mode with a pencil, handle drawing
    if touchType == .pencil && (selectedTool == .pen || selectedTool == .arrow) {
        // Use custom DragGesture-like handling since we can't construct DragGesture.Value directly
        if currentDrawing == nil {
            // Start a new drawing with the adjusted location
            self.startNewDrawing(at: adjustedLocation)
        } else {
            // Continue existing drawing with the adjusted location
            self.continueDrawing(at: adjustedLocation)
        }
    }
}

private func startNewDrawing(at point: CGPoint) {
    // Get screen and court dimensions for normalization
    let screenSize = UIScreen.main.bounds.size
    let (courtWidth, courtHeight) = getCourtDimensions()
    
    // Calculate normalized position
    let normalizedX = (point.x - (screenSize.width - courtWidth) / 2) / courtWidth
    let normalizedY = (point.y - (screenSize.height - courtHeight) / 2) / courtHeight
    let normalizedPoint = CGPoint(x: normalizedX, y: normalizedY)
    
    // Start a new drawing
    var newPath = Path()
    newPath.move(to: point)
    
    // Determine line width based on input type
    let lineWidth = (selectedTool == .arrow) ? 8 : getPencilWidth(for: currentTouchType)
    let drawingType: DrawingTool = selectedTool
    let penStyle: PenStyle = selectedPenStyle
    
    currentDrawing = Drawing(
        path: newPath,
        color: .blue,
        lineWidth: lineWidth,
        type: drawingType,
        style: penStyle,
        points: [point],
        normalizedPoints: [normalizedPoint]
    )
}

private func continueDrawing(at point: CGPoint) {
    guard var drawing = currentDrawing else { return }
    
    // Get screen and court dimensions for normalization
    let screenSize = UIScreen.main.bounds.size
    let (courtWidth, courtHeight) = getCourtDimensions()
    
    // Calculate normalized position
    let normalizedX = (point.x - (screenSize.width - courtWidth) / 2) / courtWidth
    let normalizedY = (point.y - (screenSize.height - courtHeight) / 2) / courtHeight
    let normalizedPoint = CGPoint(x: normalizedX, y: normalizedY)
    
    // Add the current point to our points array
    drawing.points.append(point)
    drawing.normalizedPoints?.append(normalizedPoint)
    
    // Make sure we have the previous point and the style information
    guard let previousPoint = drawing.points.dropLast().last else { return }
    
    // Get the drawing type and style - create local copies to avoid Optional issues
    let drawingType = drawing.type 
    let penStyle = drawing.style
    
    // Update the path based on tool and style
    var path = drawing.path
    
    if drawingType == .pen {
        switch penStyle {
        case .normal:
            // Just add a line to the path
            path.addLine(to: point)
            
        case .squiggly:
            // Create squiggly effect
            let mid = previousPoint.midpoint(to: point)
            let offset = CGPoint(
                x: (mid.y - previousPoint.y),
                y: (previousPoint.x - mid.x)
            )
            let controlPoint = CGPoint(
                x: mid.x + offset.x,
                y: mid.y + offset.y
            )
            path.addQuadCurve(to: point, control: controlPoint)
            
        case .zigzag:
            // Create zigzag effect
            let distance = previousPoint.distance(to: point)
            let segments = max(Int(distance / 3), 1)
            
            if segments > 1 {
                // For multiple segments, calculate zigzag points
                for i in 1...segments {
                    let t = CGFloat(i) / CGFloat(segments)
                    let point = previousPoint.interpolated(to: point, t: t)
                    let offset: CGFloat = i % 2 == 0 ? 5 : -5
                    
                    let direction = CGVector(dx: point.x - previousPoint.x, dy: point.y - previousPoint.y)
                    let normalizedDirection = direction.normalized
                    let perpendicular = CGVector(dx: -normalizedDirection.dy, dy: normalizedDirection.dx)
                    
                    let zigzagPoint = CGPoint(
                        x: point.x + perpendicular.dx * offset,
                        y: point.y + perpendicular.dy * offset
                    )
                    
                    path.addLine(to: zigzagPoint)
                }
            } else {
                // For short distances, just add a line
                path.addLine(to: point)
            }
        }
    } else if drawingType == .arrow {
        // For arrows, we only update the endpoint in the points array
        // The actual arrow is drawn in the Canvas based on first and last points
    }
    
    // Update the current drawing's path
    drawing.path = path
    currentDrawing = drawing
} 