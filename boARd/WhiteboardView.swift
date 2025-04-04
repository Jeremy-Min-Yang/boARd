import SwiftUI
import PDFKit

// Enum definition for CourtType
enum CourtType {
    case full
    case half
}

// CourtImageView implementation
struct CourtImageView: View {
    let courtType: CourtType
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                // White background
                Color.white.edgesIgnoringSafeArea(.all)
                
                if courtType == .full {
                    // Full court rotates based on orientation
                    ZStack {
                        // Court image
                        Image("fullcourt")
                            .resizable()
                            .scaledToFit()
                            .rotationEffect(isLandscape ? Angle(degrees: 90) : Angle(degrees: 0))
                        
                        // Border rotates with the court
                        Rectangle()
                            .stroke(Color.black, lineWidth: 2)
                            .allowsHitTesting(false) // The border shouldn't block interaction
                            .rotationEffect(isLandscape ? Angle(degrees: 90) : Angle(degrees: 0))
                    }
                    .frame(width: geometry.size.width * 0.95, height: geometry.size.height * 0.95)
                    // Tag this view for coordinate space transformation
                    .id("courtView-\(isLandscape ? "landscape" : "portrait")")
                } else {
                    // Half court doesn't rotate
                    Image("halfcourt")
                        .resizable()
                        .scaledToFit()
                        .overlay(
                            Rectangle()
                                .stroke(Color.black, lineWidth: 2)
                                .allowsHitTesting(false) // The border shouldn't block interaction
                        )
                        .frame(width: geometry.size.width * 0.95, height: geometry.size.height * 0.95)
                }
            }
        }
    }
}

struct WhiteboardView: View {
    let courtType: CourtType
    
    @State private var selectedTool: DrawingTool = .pen
    @State private var selectedPenStyle: PenStyle = .normal
    @State private var drawings: [Drawing] = []
    @State private var currentDrawing: Drawing?
    @State private var players: [PlayerCircle] = []
    @State private var basketballs: [BasketballItem] = []
    @State private var draggedPlayerIndex: Int?
    @State private var draggedBasketballIndex: Int?
    @State private var isAddingPlayer = false
    @State private var isAddingBasketball = false
    @State private var courtBounds: CGRect = .zero // Store the court bounds
    @State private var isLandscape: Bool = false // Track orientation
    
    var body: some View {
        GeometryReader { geometry in
            let newIsLandscape = geometry.size.width > geometry.size.height
            
            // Detect orientation changes
            Color.clear.onAppear {
                self.isLandscape = newIsLandscape
            }
            .onChange(of: geometry.size) { newValue in
                if self.isLandscape != newIsLandscape {
                    self.isLandscape = newIsLandscape
                    
                    // Transform coordinates for drawings and objects if this is a full court
                    if courtType == .full {
                        transformDrawingsForRotation()
                        transformObjectsForRotation(players: &players)
                        transformObjectsForRotation(basketballs: &basketballs)
                    }
                }
            }
            
            ZStack {
                // Background (court)
                CourtImageView(courtType: courtType)
                    .edgesIgnoringSafeArea(.all)
                    .background(
                        GeometryReader { geo in
                            // Invisible view to capture the bounds
                            Color.clear
                                .onAppear {
                                    // Use the exact same calculation as in CourtImageView
                                    updateCourtBoundsFromGeometry(geo)
                                }
                                .onChange(of: geo.size) { _ in
                                    // Update bounds whenever geometry changes
                                    updateCourtBoundsFromGeometry(geo)
                                }
                        }
                    )
                
                // Drawing canvas
                Canvas { context, size in
                    // Draw all existing drawings
                    for drawing in drawings {
                        let path = drawing.path
                        
                        if drawing.type == .arrow {
                            // Draw the arrow
                            if drawing.points.count >= 2 {
                                let lastPoint = drawing.points.last!
                                let firstPoint = drawing.points.first!
                                let arrowPath = createArrowPath(from: firstPoint, to: lastPoint)
                                context.stroke(arrowPath, with: .color(drawing.color), lineWidth: drawing.lineWidth)
                            }
                        } else {
                            // Draw pen strokes
                            context.stroke(
                                path,
                                with: .color(drawing.color),
                                style: StrokeStyle(lineWidth: drawing.lineWidth, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                    
                    // Draw current drawing in progress
                    if let drawing = currentDrawing {
                        let path = drawing.path
                        
                        if drawing.type == .arrow {
                            if drawing.points.count >= 2 {
                                let lastPoint = drawing.points.last!
                                let firstPoint = drawing.points.first!
                                let arrowPath = createArrowPath(from: firstPoint, to: lastPoint)
                                context.stroke(arrowPath, with: .color(drawing.color), lineWidth: drawing.lineWidth)
                            }
                        } else {
                            context.stroke(
                                path,
                                with: .color(drawing.color),
                                style: StrokeStyle(lineWidth: drawing.lineWidth, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                    
                    // Draw the court border directly on the canvas
                    drawCourtBorder(in: context, bounds: courtBounds)
                }
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            // Only allow drawing within court bounds
                            if isPointWithinCourtBounds(value.location) {
                                handleDragChanged(value)
                            }
                        }
                        .onEnded { _ in
                            handleDragEnded()
                        }
                )
                
                // Basketballs
                ForEach(basketballs.indices, id: \.self) { index in
                    let basketball = basketballs[index]
                    BasketballView(position: basketball.position)
                        .position(basketball.position)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // Only allow dragging within court bounds
                                    if isPointWithinCourtBounds(value.location) {
                                        draggedBasketballIndex = index
                                        var updatedBasketball = basketball
                                        updatedBasketball.position = value.location
                                        basketballs[index] = updatedBasketball
                                    }
                                }
                                .onEnded { _ in
                                    draggedBasketballIndex = nil
                                }
                        )
                }
                
                // Player circles
                ForEach(players.indices, id: \.self) { index in
                    let player = players[index]
                    PlayerCircleView(position: player.position, number: player.number, color: player.color)
                        .position(player.position)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // Only allow dragging within court bounds
                                    if isPointWithinCourtBounds(value.location) {
                                        draggedPlayerIndex = index
                                        var updatedPlayer = player
                                        updatedPlayer.position = value.location
                                        players[index] = updatedPlayer
                                    }
                                }
                                .onEnded { _ in
                                    draggedPlayerIndex = nil
                                }
                        )
                }
                
                // Add player button (shows when isAddingPlayer is true)
                if isAddingPlayer {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            isAddingPlayer = false
                        }
                    
                    VStack {
                        Text("Tap anywhere to add player")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .padding(.top, 100)
                        
                        Spacer()
                    }
                    
                    // Capture the tap gesture with location
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    // Only add player within court bounds
                                    if isPointWithinCourtBounds(value.location) {
                                        addPlayerAt(position: value.location)
                                        isAddingPlayer = false
                                    }
                                }
                        )
                }
                
                // Add basketball (shows when isAddingBasketball is true)
                if isAddingBasketball {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            isAddingBasketball = false
                        }
                    
                    VStack {
                        Text("Tap anywhere to add basketball")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .padding(.top, 100)
                        
                        Spacer()
                    }
                    
                    // Capture the tap gesture with location
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    // Only add basketball within court bounds
                                    if isPointWithinCourtBounds(value.location) {
                                        addBasketballAt(position: value.location)
                                        isAddingBasketball = false
                                    }
                                }
                        )
                }
                
                // Toolbar
                VStack {
                    ToolbarView(
                        selectedTool: $selectedTool,
                        selectedPenStyle: $selectedPenStyle,
                        onAddPlayer: {
                            isAddingPlayer = true
                            isAddingBasketball = false
                        },
                        onAddBasketball: {
                            isAddingBasketball = true
                            isAddingPlayer = false
                        },
                        onClear: {
                            drawings.removeAll()
                            players.removeAll()
                            basketballs.removeAll()
                        }
                    )
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(10)
                    .padding()
                    
                    Spacer()
                }
            }
            .navigationTitle(courtType == .full ? "Full Court" : "Half Court")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.white)
        }
    }
    
    // Helper function to update court bounds consistently
    private func updateCourtBounds(geometry: GeometryProxy, isLandscape: Bool) {
        // No inset - we want to match the exact border
        
        if courtType == .half {
            // For half court, we need to match the exact bounds of the image within its container
            let containerWidth = geometry.size.width * 0.95
            let containerHeight = geometry.size.height * 0.95
            
            if isLandscape {
                // In landscape, the half court image fills the width
                let aspectRatio: CGFloat = 1.78 // Approximate aspect ratio of the half court image
                let imageWidth = containerWidth
                let imageHeight = min(containerHeight, imageWidth / aspectRatio)
                
                // Calculate the origin to center the image in the container
                let x = (geometry.size.width - imageWidth) / 2
                let y = (geometry.size.height - imageHeight) / 2
                
                courtBounds = CGRect(x: x, y: y, width: imageWidth, height: imageHeight)
            } else {
                // In portrait, the half court image fills the height
                let aspectRatio: CGFloat = 1.78 // Approximate aspect ratio of the half court image
                let imageHeight = containerHeight
                let imageWidth = min(containerWidth, imageHeight * aspectRatio)
                
                // Calculate the origin to center the image in the container
                let x = (geometry.size.width - imageWidth) / 2
                let y = (geometry.size.height - imageHeight) / 2
                
                courtBounds = CGRect(x: x, y: y, width: imageWidth, height: imageHeight)
            }
        } else {
            // For full court
            if isLandscape {
                // In landscape, the full court rotates and fills the height
                let containerWidth = geometry.size.width * 0.95
                let containerHeight = geometry.size.height * 0.95
                
                // When rotated, the court's width becomes its height and vice versa
                // The aspect ratio is inverted when rotated
                let aspectRatio: CGFloat = 1.0/2.1 // Approximate inverted aspect ratio of rotated full court
                
                let imageHeight = containerHeight
                let imageWidth = min(containerWidth, imageHeight * aspectRatio)
                
                // Center the image
                let x = (geometry.size.width - imageWidth) / 2
                let y = (geometry.size.height - imageHeight) / 2
                
                courtBounds = CGRect(x: x, y: y, width: imageWidth, height: imageHeight)
            } else {
                // In portrait, the full court fills the width
                let containerWidth = geometry.size.width * 0.95
                let containerHeight = geometry.size.height * 0.95
                
                let aspectRatio: CGFloat = 2.1 // Approximate aspect ratio of the full court
                
                let imageWidth = containerWidth
                let imageHeight = min(containerHeight, imageWidth / aspectRatio)
                
                // Center the image
                let x = (geometry.size.width - imageWidth) / 2
                let y = (geometry.size.height - imageHeight) / 2
                
                courtBounds = CGRect(x: x, y: y, width: imageWidth, height: imageHeight)
            }
        }
    }
    
    // Helper function to check if a point is within court bounds with a small safety margin
    private func isPointWithinCourtBounds(_ point: CGPoint) -> Bool {
        // For debugging purposes, uncomment this line to see coordinates
        // print("Point: \(point), Bounds: \(courtBounds), Contains: \(courtBounds.contains(point))")
        
        // Apply a small safety margin to ensure we're not at the very edge
        let margin: CGFloat = 2
        let adjustedBounds = CGRect(
            x: courtBounds.minX + margin,
            y: courtBounds.minY + margin,
            width: courtBounds.width - (margin * 2),
            height: courtBounds.height - (margin * 2)
        )
        
        return adjustedBounds.contains(point)
    }
    
    // Transform drawings when rotating
    private func transformDrawingsForRotation() {
        // Only transform for full court
        if courtType != .full {
            return
        }
        
        // Transform all existing drawings
        for i in 0..<drawings.count {
            var newPath = Path()
            var newPoints: [CGPoint] = []
            
            for point in drawings[i].points {
                let transformedPoint = transformPointForRotation(point)
                newPoints.append(transformedPoint)
                
                if newPath.isEmpty {
                    newPath.move(to: transformedPoint)
                } else {
                    newPath.addLine(to: transformedPoint)
                }
            }
            
            drawings[i].points = newPoints
            drawings[i].path = newPath
        }
    }
    
    // Transform player circles when rotating
    private func transformObjectsForRotation(players: inout [PlayerCircle]) {
        // Only transform for full court
        if courtType != .full {
            return
        }
        
        // Transform all player positions
        for i in 0..<players.count {
            let transformedPosition = transformPointForRotation(players[i].position)
            players[i].position = transformedPosition
        }
    }
    
    // Transform basketballs when rotating
    private func transformObjectsForRotation(basketballs: inout [BasketballItem]) {
        // Only transform for full court
        if courtType != .full {
            return
        }
        
        // Transform all basketball positions
        for i in 0..<basketballs.count {
            let transformedPosition = transformPointForRotation(basketballs[i].position)
            basketballs[i].position = transformedPosition
        }
    }
    
    // Helper to transform a point when rotating
    private func transformPointForRotation(_ point: CGPoint) -> CGPoint {
        guard courtBounds.width > 0 && courtBounds.height > 0 else {
            return point
        }
        
        // Calculate relative position within the court (0-1 range)
        let relativeX = (point.x - courtBounds.minX) / courtBounds.width
        let relativeY = (point.y - courtBounds.minY) / courtBounds.height
        
        // Swap coordinates for rotation
        let newRelativeX = relativeY
        let newRelativeY = 1 - relativeX
        
        // Convert back to absolute coordinates
        return CGPoint(
            x: courtBounds.minX + newRelativeX * courtBounds.width,
            y: courtBounds.minY + newRelativeY * courtBounds.height
        )
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        if isAddingPlayer || isAddingBasketball {
            return
        }
        
        let currentPoint = value.location
        
        if currentDrawing == nil {
            // Start a new drawing
            var newPath = Path()
            newPath.move(to: currentPoint) // Start at the current point
            
            currentDrawing = Drawing(
                path: newPath,
                color: .blue,
                lineWidth: selectedTool == .arrow ? 5 : 3,
                type: selectedTool,
                style: selectedPenStyle,
                points: [currentPoint] // Add the current point to points array
            )
            return
        }
        
        // Add the current point to our points array
        currentDrawing?.points.append(currentPoint)
        
        // Get the previous point
        guard let previousPoint = currentDrawing?.points.dropLast().last,
              let penStyle = currentDrawing?.style,
              let drawingType = currentDrawing?.type else {
            return
        }
        
        // Update the path based on tool and style
        var path = currentDrawing!.path
        
        if drawingType == .pen {
            switch penStyle {
            case .normal:
                // Just add a line to the path
                path.addLine(to: currentPoint)
                
            case .squiggly:
                // Create squiggly effect
                let mid = previousPoint.midpoint(to: currentPoint)
                let offset = CGPoint(
                    x: (mid.y - previousPoint.y) * 0.3,
                    y: (previousPoint.x - mid.x) * 0.3
                )
                let controlPoint = CGPoint(
                    x: mid.x + offset.x,
                    y: mid.y + offset.y
                )
                path.addQuadCurve(to: currentPoint, control: controlPoint)
                
            case .zigzag:
                // Create zigzag effect
                let distance = previousPoint.distance(to: currentPoint)
                let segments = max(Int(distance / 10), 1)
                
                if segments > 1 {
                    // For multiple segments, calculate zigzag points
                    for i in 1...segments {
                        let t = CGFloat(i) / CGFloat(segments)
                        let point = previousPoint.interpolated(to: currentPoint, t: t)
                        let offset: CGFloat = i % 2 == 0 ? 5 : -5
                        
                        let direction = CGVector(dx: currentPoint.x - previousPoint.x, dy: currentPoint.y - previousPoint.y)
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
                    path.addLine(to: currentPoint)
                }
            }
        } else if drawingType == .arrow {
            // For arrows, we only update the endpoint in the points array
            // The actual arrow is drawn in the Canvas based on first and last points
        }
        
        // Update the current drawing's path
        currentDrawing?.path = path
    }
    
    private func handleDragEnded() {
        if let drawing = currentDrawing {
            // Add the completed drawing to the collection
            drawings.append(drawing)
            currentDrawing = nil
        }
    }
    
    private func addPlayerAt(position: CGPoint) {
        let newPlayer = PlayerCircle(
            position: position,
            number: players.count + 1,
            color: .blue
        )
        players.append(newPlayer)
    }
    
    private func addBasketballAt(position: CGPoint) {
        let newBasketball = BasketballItem(position: position)
        basketballs.append(newBasketball)
    }
    
    private func createArrowPath(from start: CGPoint, to end: CGPoint) -> Path {
        var path = Path()
        
        // Line from start to end
        path.move(to: start)
        path.addLine(to: end)
        
        // Calculate the arrowhead points
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 20
        let arrowAngle: CGFloat = .pi / 6 // 30 degrees
        
        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        // Draw the arrowhead
        path.move(to: end)
        path.addLine(to: point1)
        path.move(to: end)
        path.addLine(to: point2)
        
        return path
    }
    
    // Remove the red debug border when ready for production
    private func removeBorderForProduction() {
        // To remove the red debug border, simply comment out the Rectangle() view
        // marked as "Debugging visualization of bounds" in the body of WhiteboardView
    }
    
    private func updateCourtBoundsFromGeometry(_ geometry: GeometryProxy) {
        let isLandscape = geometry.size.width > geometry.size.height
        
        // Always start with the base calculation for the container frame
        let width = geometry.size.width * 0.95
        let height = geometry.size.height * 0.95
        let x = (geometry.size.width - width) / 2
        let y = (geometry.size.height - height) / 2
        
        // Store the base frame that matches the visible container
        courtBounds = CGRect(x: x, y: y, width: width, height: height)
        
        // Update the isLandscape state variable to match the current orientation
        self.isLandscape = isLandscape
    }
    
    private func drawCourtBorder(in context: GraphicsContext, bounds: CGRect) {
        // Draw a red rectangle border at the exact bounds of the court
        let rect = Path(bounds)
        context.stroke(
            rect,
            with: .color(.red),
            lineWidth: 1
        )
    }
    
    // UIKit-style drawing method (for reference)
    private func drawUsingUIKit(_ rect: CGRect) {
        if let ctx = UIGraphicsGetCurrentContext() {
            drawCourtBorderUIKit(in: ctx, bounds: rect)
        }
    }
    
    // UIKit version of border drawing
    private func drawCourtBorderUIKit(in ctx: CGContext, bounds: CGRect) {
        ctx.setStrokeColor(UIColor.red.cgColor)
        ctx.setLineWidth(1)
        ctx.stroke(bounds.insetBy(dx: 1, dy: 1))
    }
}

struct ToolbarView: View {
    @Binding var selectedTool: DrawingTool
    @Binding var selectedPenStyle: PenStyle
    var onAddPlayer: () -> Void
    var onAddBasketball: () -> Void
    var onClear: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // Drawing tool selection
            ForEach(DrawingTool.allCases, id: \.self) { tool in
                Button(action: {
                    selectedTool = tool
                }) {
                    Image(systemName: tool.iconName)
                        .font(.title2)
                        .foregroundColor(selectedTool == tool ? .blue : .gray)
                        .frame(width: 40, height: 40)
                        .background(selectedTool == tool ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                }
            }
            
            Divider()
                .frame(height: 30)
            
            // Pen style selection (only show when pen is selected)
            if selectedTool == .pen {
                ForEach(PenStyle.allCases, id: \.self) { style in
                    Button(action: {
                        selectedPenStyle = style
                    }) {
                        Image(systemName: style.iconName)
                            .font(.title2)
                            .foregroundColor(selectedPenStyle == style ? .blue : .gray)
                            .frame(width: 40, height: 40)
                            .background(selectedPenStyle == style ? Color.blue.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                    }
                }
                
                Divider()
                    .frame(height: 30)
            }
            
            // Add player button
            Button(action: onAddPlayer) {
                Image(systemName: "person.fill.badge.plus")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 40)
            }
            
            // Add basketball button
            Button(action: onAddBasketball) {
                Image(systemName: "basketball.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                    .frame(width: 40, height: 40)
            }
            
            // Clear button
            Button(action: onClear) {
                Image(systemName: "trash")
                    .font(.title2)
                    .foregroundColor(.red)
                    .frame(width: 40, height: 40)
            }
        }
        .padding()
    }
}

struct PlayerCircleView: View {
    let position: CGPoint
    let number: Int
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black, lineWidth: 2)
                .background(Circle().fill(color))
                .frame(width: 50, height: 50)
            
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(width: 50, height: 50)
    }
}

struct BasketballView: View {
    let position: CGPoint
    
    var body: some View {
        Image("basketball")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 40, height: 40)
    }
}

struct Drawing {
    var path: Path
    var color: Color
    var lineWidth: CGFloat
    var type: DrawingTool
    var style: PenStyle
    var points: [CGPoint]  // Track points manually
}

struct PlayerCircle {
    var position: CGPoint
    var number: Int
    var color: Color
}

struct BasketballItem {
    var position: CGPoint
}

enum DrawingTool: String, CaseIterable {
    case pen
    case arrow
    
    var iconName: String {
        switch self {
        case .pen: return "pencil"
        case .arrow: return "arrow.up.right"
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

// Helper extensions
extension CGPoint {
    func midpoint(to point: CGPoint) -> CGPoint {
        return CGPoint(x: (self.x + point.x) / 2, y: (self.y + point.y) / 2)
    }
    
    func distance(to point: CGPoint) -> CGFloat {
        let dx = point.x - self.x
        let dy = point.y - self.y
        return sqrt(dx*dx + dy*dy)
    }
    
    func interpolated(to point: CGPoint, t: CGFloat) -> CGPoint {
        return CGPoint(
            x: self.x + (point.x - self.x) * t,
            y: self.y + (point.y - self.y) * t
        )
    }
}

extension CGVector {
    var length: CGFloat {
        return sqrt(dx*dx + dy*dy)
    }
    
    var normalized: CGVector {
        let len = length
        return len > 0 ? CGVector(dx: dx/len, dy: dy/len) : CGVector(dx: 0, dy: 0)
    }
} 