import SwiftUI
import PDFKit
import UIKit

// Enum definition for CourtType
enum CourtType {
    case full
    case half
}

// Touch type enum to differentiate input types
enum TouchInputType {
    case finger
    case pencil
    case unknown
}

// Drawing boundary struct to control exact positioning
struct DrawingBoundary {
    let width: CGFloat
    let height: CGFloat
    let offsetX: CGFloat // Horizontal offset from center
    let offsetY: CGFloat // Vertical offset from center
    
    static let fullCourt = DrawingBoundary(
        width: 1072,
        height: 638,
        offsetX: 0,
        offsetY: -35
    )
    
    static let halfCourt = DrawingBoundary(
        width: 793,  // Keep doubled width
        height: 950,  // Reduced from 1200 to better match court
        offsetX: -46,
        offsetY: 98  // Reduced from 150 to bring drawing area up by 50pts
    )
    
    func getFrameSize() -> CGSize {
        return CGSize(width: width, height: height)
    }
    
    func getOffset() -> CGPoint {
        return CGPoint(x: offsetX, y: offsetY)
    }
}

// CourtImageView implementation
struct CourtImageView: View {
    let courtType: CourtType
    let frame: CGRect // Use a fixed frame passed from parent
    
    var body: some View {
        ZStack {
            // White background
            Color.black
            
            if courtType == .full {
                // Full court without rotation code
                ZStack {
                    // Court image
                    Image("fullcourt")
                        .resizable()
                        .scaledToFit()
                        .overlay(
                            Rectangle()
                                .stroke(Color.black, lineWidth: 3)
                                .allowsHitTesting(false) // The border shouldn't block interaction
                        )
                        .rotationEffect(Angle(degrees: 90))
                    
                    // Border
                    Rectangle()
                        .stroke(Color.red, lineWidth: 3)
                        .allowsHitTesting(false) // The border shouldn't block interaction
                        .rotationEffect(Angle(degrees: 90))
                }
            } else {
                // Half court doesn't rotate
                Image("halfcourt")
                    .resizable()
                    .scaledToFit()
                    .overlay(
                        Rectangle()
                            .stroke(Color.black, lineWidth: 3)
                            .allowsHitTesting(false)
                    )
            }
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
    }
}

struct DrawingLayer: View {
    let courtType: CourtType
    @Binding var drawings: [Drawing]
    @Binding var currentDrawing: Drawing?
    @Binding var basketballs: [BasketballItem]
    @Binding var players: [PlayerCircle]
    @Binding var selectedTool: DrawingTool
    @Binding var selectedPenStyle: PenStyle
    @Binding var draggedBasketballIndex: Int?
    @Binding var draggedPlayerIndex: Int?
    
    var body: some View {
        Canvas { context, size in
            // Draw all existing drawings
            for drawing in drawings {
                let path = drawing.path
                
                if drawing.type == .arrow {
                    // Draw the arrow
                    if drawing.points.count >= 5 {
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
                    if drawing.points.count >= 5 {
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
        }
        .allowsHitTesting(true)
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
}

// Add this enum before the WhiteboardView struct
enum Action {
    case drawing(Drawing)
    case basketball(BasketballItem)
    case player(PlayerCircle)
}

// First, let's add a new component view to extract the court background
struct CourtBackgroundView: View {
    let courtType: CourtType
    let courtWidth: CGFloat
    let courtHeight: CGFloat
    
    var body: some View {
        if courtType == .full {
            Image("fullcourt")
                .resizable()
                .scaledToFit()
                .overlay(
                    Rectangle()
                        .stroke(Color.black, lineWidth: 3)
                        .allowsHitTesting(false)
                )
                .rotationEffect(Angle(degrees: 90))
                .frame(width: courtWidth * 1.65, height: courtHeight * 1.58)
        } else {
            Image("halfcourt")
                .resizable()
                .scaledToFit()
                .overlay(
                    Rectangle()
                        .stroke(Color.black, lineWidth: 3)
                        .allowsHitTesting(false)
                )
                .frame(width: courtWidth * 0.97, height: courtHeight * 0.97)
        }
    }
}

// Create a component for basketballs display
struct BasketballsView: View {
    @Binding var basketballs: [BasketballItem]
    @Binding var draggedBasketballIndex: Int?
    @Binding var currentTouchType: TouchInputType
    
    var body: some View {
        ForEach(basketballs.indices, id: \.self) { index in
            let basketball = basketballs[index]
            BasketballView(position: basketball.position)
                .position(x: basketball.position.x, y: basketball.position.y)
                .gesture(
                    DragGesture(coordinateSpace: .local)
                        .onChanged { value in
                            // Only allow finger drags for basketballs
                            if currentTouchType != .pencil {
                                draggedBasketballIndex = index
                                var updatedBasketball = basketball
                                updatedBasketball.position = value.location
                                
                                // We'll update normalized position in the parent view
                                basketballs[index] = updatedBasketball
                            }
                        }
                        .onEnded { _ in
                            draggedBasketballIndex = nil
                        }
                )
        }
    }
}

// Create a component for players display
struct PlayersView: View {
    @Binding var players: [PlayerCircle]
    @Binding var draggedPlayerIndex: Int?
    @Binding var currentTouchType: TouchInputType
    
    var body: some View {
        ForEach(players.indices, id: \.self) { index in
            let player = players[index]
            PlayerCircleView(position: player.position, number: player.number, color: player.color)
                .position(x: player.position.x, y: player.position.y)
                .gesture(
                    DragGesture(coordinateSpace: .local)
                        .onChanged { value in
                            // Only allow finger drags for players
                            if currentTouchType != .pencil {
                                draggedPlayerIndex = index
                                var updatedPlayer = player
                                updatedPlayer.position = value.location
                                
                                // We'll update normalized position in the parent view
                                players[index] = updatedPlayer
                            }
                        }
                        .onEnded { _ in
                            draggedPlayerIndex = nil
                        }
                )
        }
    }
}

// Now modify the main WhiteboardView to use these components
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
    @State private var currentTouchType: TouchInputType = .unknown
    @State private var showPencilIndicator: Bool = false
    @State private var lastTouchLocation: CGPoint = .zero
    @State private var showPlayerLimitAlert = false
    @State private var showBasketballLimitAlert = false
    
    // Add this new state variable to track all actions
    @State private var actions: [Action] = []
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Toolbar stays the same
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
                    onUndo: {
                        if let lastAction = actions.popLast() {
                            switch lastAction {
                            case .drawing:
                                if !drawings.isEmpty {
                                    drawings.removeLast()
                                }
                            case .basketball:
                                if !basketballs.isEmpty {
                                    basketballs.removeLast()
                                }
                            case .player:
                                if !players.isEmpty {
                                    players.removeLast()
                                }
                            }
                        }
                    },
                    onClear: {
                        drawings.removeAll()
                        players.removeAll()
                        basketballs.removeAll()
                        actions.removeAll()
                    }
                )
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                
                // Main content area
                courtContentView(geometry: geometry)
            }
            .navigationTitle(courtType == .full ? "Full Court" : "Half Court")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Player Limit Reached", isPresented: $showPlayerLimitAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You can only have up to 5 players on the court at once.")
            }
            .alert("Basketball Limit Reached", isPresented: $showBasketballLimitAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You can only have one basketball on the court at a time.")
            }
        }
    }
    
    // Extract content view to a separate method to reduce complexity
    @ViewBuilder
    private func courtContentView(geometry: GeometryProxy) -> some View {
        ZStack {
            // Background color
            Color.white.edgesIgnoringSafeArea(.all)
            
            // Define constants for consistent sizing
            let courtWidth = geometry.size.width * 0.98
            let courtHeight = (geometry.size.height - 48) * 0.98 // Adjust for toolbar height
            
            // Extract drawing dimensions to simplify expressions
            let drawingWidth = courtType == .full ? DrawingBoundary.fullCourt.width : DrawingBoundary.halfCourt.width
            let drawingHeight = courtType == .full ? DrawingBoundary.fullCourt.height : DrawingBoundary.halfCourt.height
            let drawingOffsetX = courtType == .full ? DrawingBoundary.fullCourt.offsetX : DrawingBoundary.halfCourt.offsetX
            let drawingOffsetY = courtType == .full ? DrawingBoundary.fullCourt.offsetY : DrawingBoundary.halfCourt.offsetY
            
            // Main drawing area
            courtAndDrawingContent(
                geometry: geometry,
                courtWidth: courtWidth,
                courtHeight: courtHeight,
                drawingWidth: drawingWidth,
                drawingHeight: drawingHeight,
                drawingOffsetX: drawingOffsetX,
                drawingOffsetY: drawingOffsetY
            )
            .position(x: geometry.size.width / 2, y: (geometry.size.height - 48) / 2)
            
            // Debug info overlay
            debugOverlay(courtWidth: courtWidth, courtHeight: courtHeight, drawingWidth: drawingWidth, drawingHeight: drawingHeight)
            
            // Add player mode overlay
            if isAddingPlayer {
                addPlayerOverlay(drawingWidth: drawingWidth, drawingHeight: drawingHeight, offsetX: drawingOffsetX, offsetY: drawingOffsetY)
            }
            
            // Add basketball mode overlay
            if isAddingBasketball {
                addBasketballOverlay(drawingWidth: drawingWidth, drawingHeight: drawingHeight, offsetX: drawingOffsetX, offsetY: drawingOffsetY)
            }
        }
    }
    
    // Further break down the content
    @ViewBuilder
    private func courtAndDrawingContent(geometry: GeometryProxy, courtWidth: CGFloat, courtHeight: CGFloat, 
                                      drawingWidth: CGFloat, drawingHeight: CGFloat, 
                                      drawingOffsetX: CGFloat, drawingOffsetY: CGFloat) -> some View {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        let containerWidth = courtType == .full ? screenWidth * 0.98 * 1.65 : screenWidth * 0.98 * 0.97
        let containerHeight = courtType == .full ? (screenHeight - 48) * 0.98 * 1.58 : (screenHeight - 48) * 0.98 * 0.97
        
        ZStack {
            // Court image background
            CourtBackgroundView(courtType: courtType, courtWidth: courtWidth, courtHeight: courtHeight)
            
            // Drawing layer
            DrawingLayer(
                courtType: courtType,
                drawings: $drawings,
                currentDrawing: $currentDrawing,
                basketballs: $basketballs,
                players: $players,
                selectedTool: $selectedTool,
                selectedPenStyle: $selectedPenStyle,
                draggedBasketballIndex: $draggedBasketballIndex,
                draggedPlayerIndex: $draggedPlayerIndex
            )
            .frame(width: drawingWidth, height: drawingHeight)
            .offset(x: drawingOffsetX, y: drawingOffsetY)
            
            // Touch detection
            TouchTypeDetectionView(
                onTouchesChanged: { touchType, locations in
                    if !locations.isEmpty {
                        let location = locations.first!
                        handleTouchChanged(touchType: touchType, location: location)
                    }
                },
                onTouchesEnded: { touchType in
                    handleTouchEnded(touchType: touchType)
                }
            )
            .frame(width: drawingWidth, height: drawingHeight)
            .offset(x: drawingOffsetX, y: drawingOffsetY)
            .allowsHitTesting(true)
            
            // Basketballs
            BasketballsView(
                basketballs: $basketballs,
                draggedBasketballIndex: $draggedBasketballIndex,
                currentTouchType: $currentTouchType
            )
            
            // Player circles
            PlayersView(
                players: $players,
                draggedPlayerIndex: $draggedPlayerIndex,
                currentTouchType: $currentTouchType
            )
            
            // Pencil indicator
            if showPencilIndicator {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .position(lastTouchLocation)
            }
        }
        .frame(width: containerWidth, height: containerHeight)
    }
    
    // Debug overlay
    @ViewBuilder
    private func debugOverlay(courtWidth: CGFloat, courtHeight: CGFloat, drawingWidth: CGFloat, drawingHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Court: \(courtType == .full ? "Full" : "Half")")
                .font(.caption)
                .foregroundColor(.black)
            Text("Size: \(Int(drawingWidth))×\(Int(drawingHeight))")
                .font(.caption)
                .foregroundColor(.black)
            Text("Input: \(currentTouchType == .pencil ? "Apple Pencil" : currentTouchType == .finger ? "Finger" : "Unknown")")
                .font(.caption)
                .foregroundColor(currentTouchType == .pencil ? .blue : .black)
        }
        .padding(8)
        .background(Color.white.opacity(0.8))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray, lineWidth: 1)
        )
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    // Add player overlay
    @ViewBuilder
    private func addPlayerOverlay(drawingWidth: CGFloat, drawingHeight: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isAddingPlayer = false
                }
            
            VStack {
                Text("Tap within the court to add player")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .padding(.top, 100)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.clear)
                .frame(width: drawingWidth, height: drawingHeight)
                .offset(x: offsetX, y: offsetY)
                .contentShape(Rectangle())
                .gesture(
                    // Use DragGesture with minimal distance to detect taps
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            // Get the tap location from the gesture value
                            let tapPosition = value.location
                            addPlayerAt(position: tapPosition)
                            isAddingPlayer = false
                        }
                )
        }
    }
    
    // Add basketball overlay
    @ViewBuilder
    private func addBasketballOverlay(drawingWidth: CGFloat, drawingHeight: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isAddingBasketball = false
                }
            
            VStack {
                Text("Tap within the court to add basketball")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .padding(.top, 100)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.clear)
                .frame(width: drawingWidth, height: drawingHeight)
                .offset(x: offsetX, y: offsetY)
                .contentShape(Rectangle())
                .gesture(
                    // Use DragGesture with minimal distance to detect taps
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            // Get the tap location from the gesture value
                            let tapPosition = value.location
                            addBasketballAt(position: tapPosition)
                            isAddingBasketball = false
                        }
                )
        }
    }
    
    private func handleTouchChanged(touchType: TouchInputType, location: CGPoint) {
        // Update current touch type
        currentTouchType = touchType
        
        // If it's a pencil, show the indicator
        showPencilIndicator = (touchType == .pencil)
        
        // If we're in drawing mode with a pencil, handle drawing
        if touchType == .pencil && (selectedTool == .pen || selectedTool == .arrow) {
            // Use custom DragGesture-like handling since we can't construct DragGesture.Value directly
            if currentDrawing == nil {
                // Start a new drawing
                self.startNewDrawing(at: location)
            } else {
                // Continue existing drawing
                self.continueDrawing(at: location)
            }
        }
    }
    
    // Helper function to get dimensions for calculations outside geometry reader
    private func getCourtDimensions() -> (width: CGFloat, height: CGFloat) {
        let screenSize = UIScreen.main.bounds.size
        let courtWidth = screenSize.width * 0.98
        let courtHeight = (screenSize.height - 48) * 0.98
        
        // Return base court dimensions - scaling is applied where needed
        return (courtWidth, courtHeight)
    }
    
    // Helper function to get scaled dimensions based on court type - using DrawingBoundary values
    private func getScaledCourtDimensions() -> (width: CGFloat, height: CGFloat) {
        if courtType == .full {
            return (DrawingBoundary.fullCourt.width, DrawingBoundary.fullCourt.height)
        } else {
            return (DrawingBoundary.halfCourt.width, DrawingBoundary.halfCourt.height)
        }
    }
    
    private func startNewDrawing(at point: CGPoint) {
        // Get screen and court dimensions for normalization
        let screenSize = UIScreen.main.bounds.size
        let (courtWidth, courtHeight) = getCourtDimensions()
        
        // Adjust the point to make sure it's mapped correctly to the court
        let adjustedPoint = adjustTouchLocation(point, in: screenSize, courtWidth: courtWidth, courtHeight: courtHeight)
        
        // Calculate normalized position
        let normalizedX = (adjustedPoint.x - (screenSize.width - courtWidth) / 2) / courtWidth
        let normalizedY = (adjustedPoint.y - (screenSize.height - courtHeight) / 2) / courtHeight
        let normalizedPoint = CGPoint(x: normalizedX, y: normalizedY)
        
        // Start a new drawing
        var newPath = Path()
        newPath.move(to: adjustedPoint)
        
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
            points: [adjustedPoint],
            normalizedPoints: [normalizedPoint]
        )
        
        // Update the indicator position
        lastTouchLocation = adjustedPoint
    }
    
    private func continueDrawing(at point: CGPoint) {
        guard var drawing = currentDrawing else { return }
        
        // Get screen and court dimensions for normalization
        let screenSize = UIScreen.main.bounds.size
        let (courtWidth, courtHeight) = getCourtDimensions()
        
        // Adjust the point to make sure it's mapped correctly to the court
        let adjustedPoint = adjustTouchLocation(point, in: screenSize, courtWidth: courtWidth, courtHeight: courtHeight)
        
        // Calculate normalized position
        let normalizedX = (adjustedPoint.x - (screenSize.width - courtWidth) / 2) / courtWidth
        let normalizedY = (adjustedPoint.y - (screenSize.height - courtHeight) / 2) / courtHeight
        let normalizedPoint = CGPoint(x: normalizedX, y: normalizedY)
        
        // Add the current point to our points array
        drawing.points.append(adjustedPoint)
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
                path.addLine(to: adjustedPoint)
                
            case .squiggly:
                // Create squiggly effect
                let mid = previousPoint.midpoint(to: adjustedPoint)
                let offset = CGPoint(
                    x: (mid.y - previousPoint.y),
                    y: (previousPoint.x - mid.x)
                )
                let controlPoint = CGPoint(
                    x: mid.x + offset.x,
                    y: mid.y + offset.y
                )
                path.addQuadCurve(to: adjustedPoint, control: controlPoint)
                
            case .zigzag:
                // Create zigzag effect
                let distance = previousPoint.distance(to: adjustedPoint)
                let segments = max(Int(distance / 3), 1)
                
                if segments > 1 {
                    // For multiple segments, calculate zigzag points
                    for i in 1...segments {
                        let t = CGFloat(i) / CGFloat(segments)
                        let point = previousPoint.interpolated(to: adjustedPoint, t: t)
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
                    path.addLine(to: adjustedPoint)
                }
            }
        } else if drawingType == .arrow {
            // For arrows, we only update the endpoint in the points array
            // The actual arrow is drawn in the Canvas based on first and last points
        }
        
        // Update the current drawing's path
        drawing.path = path
        currentDrawing = drawing
        
        // Update the indicator position
        lastTouchLocation = adjustedPoint
    }
    
    private func handleTouchEnded(touchType: TouchInputType) {
        // Hide pencil indicator
        showPencilIndicator = false
        
        // If we were drawing, end the drawing
        if touchType == .pencil && currentDrawing != nil {
            // Add the completed drawing to the collection
            if let drawing = currentDrawing {
                drawings.append(drawing)
                // Add to actions array
                actions.append(.drawing(drawing))
                currentDrawing = nil
            }
        }
    }
    
    private func addPlayerAt(position: CGPoint) {
        // Check if we've reached the player limit
        if players.count >= 5 {
            showPlayerLimitAlert = true
            return
        }
        
        // Calculate court dimensions
        let (courtWidth, courtHeight) = getCourtDimensions()
        let screenSize = UIScreen.main.bounds.size
        
        // Adjust the position to make sure it's mapped correctly to the court
        let adjustedPosition = adjustTouchLocation(position, in: screenSize, courtWidth: courtWidth, courtHeight: courtHeight)
        
        // Calculate normalized position
        let normalizedX = (adjustedPosition.x - (screenSize.width - courtWidth) / 2) / courtWidth
        let normalizedY = (adjustedPosition.y - (screenSize.height - courtHeight) / 2) / courtHeight
        
        let newPlayer = PlayerCircle(
            position: adjustedPosition,
            number: players.count + 1,
            color: .blue,
            normalizedPosition: CGPoint(x: normalizedX, y: normalizedY)
        )
        players.append(newPlayer)
        // Add to actions array
        actions.append(.player(newPlayer))
    }
    
    private func addBasketballAt(position: CGPoint) {
        // Check if we've reached the basketball limit (only 1)
        if basketballs.count >= 1 {
            showBasketballLimitAlert = true
            return
        }
        
        // Calculate court dimensions
        let (courtWidth, courtHeight) = getCourtDimensions()
        let screenSize = UIScreen.main.bounds.size
        
        // Adjust the position to make sure it's mapped correctly to the court
        let adjustedPosition = adjustTouchLocation(position, in: screenSize, courtWidth: courtWidth, courtHeight: courtHeight)
        
        // Calculate normalized position
        let normalizedX = (adjustedPosition.x - (screenSize.width - courtWidth) / 2) / courtWidth
        let normalizedY = (adjustedPosition.y - (screenSize.height - courtHeight) / 2) / courtHeight
        
        let newBasketball = BasketballItem(
            position: adjustedPosition,
            normalizedPosition: CGPoint(x: normalizedX, y: normalizedY)
        )
        basketballs.append(newBasketball)
        // Add to actions array
        actions.append(.basketball(newBasketball))
    }
    
    private func getPencilWidth(for touchType: TouchInputType) -> CGFloat {
        // Default widths based on input type
        switch touchType {
        case .pencil:
            return 8.0  // Increased from 2.0 for better visibility
        case .finger:
            return 16.0  // Increased from 5.0 for better visibility
        case .unknown:
            return 12.0  // Increased from 3.0 for better visibility
        }
    }
    
    // Helper function to adjust coordinates for better precision
    private func adjustTouchLocation(_ location: CGPoint, in geometrySize: CGSize, courtWidth: CGFloat, courtHeight: CGFloat) -> CGPoint {
        // Get the drawing area dimensions and offset
        let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
        let (scaledWidth, scaledHeight) = (boundary.width, boundary.height)
        let (offsetX, offsetY) = (boundary.offsetX, boundary.offsetY)
        
        // Calculate the court's position relative to the screen
        let courtOriginX = (geometrySize.width - scaledWidth) / 2 + offsetX
        let courtOriginY = (geometrySize.height - 48 - scaledHeight) / 2 + 48 + offsetY
        
        // If the touch is within the court bounds, use it directly
        if location.x >= courtOriginX && location.x <= courtOriginX + scaledWidth &&
           location.y >= courtOriginY && location.y <= courtOriginY + scaledHeight {
            return location
        }
        
        // Otherwise, clamp the location to the court bounds
        let adjustedX = max(courtOriginX, min(courtOriginX + scaledWidth, location.x))
        let adjustedY = max(courtOriginY, min(courtOriginY + scaledHeight, location.y))
        
        return CGPoint(x: adjustedX, y: adjustedY)
    }
}

struct ToolbarView: View {
    @Binding var selectedTool: DrawingTool
    @Binding var selectedPenStyle: PenStyle
    var onAddPlayer: () -> Void
    var onAddBasketball: () -> Void
    var onUndo: () -> Void
    var onClear: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    Spacer(minLength: 0)
                    
                    // Drawing tool selection
                    ForEach(DrawingTool.allCases, id: \.self) { tool in
                        Button(action: {
                            selectedTool = tool
                        }) {
                            Image(systemName: tool.iconName)
                                .font(.title3)
                                .foregroundColor(selectedTool == tool ? .blue : .gray)
                                .frame(width: 36, height: 36)
                                .background(selectedTool == tool ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                    
                    Divider()
                        .frame(height: 24)
                    
                    // Pen style selection
                    if selectedTool == .pen {
                        ForEach(PenStyle.allCases, id: \.self) { style in
                            Button(action: {
                                selectedPenStyle = style
                            }) {
                                Image(systemName: style.iconName)
                                    .font(.title3)
                                    .foregroundColor(selectedPenStyle == style ? .blue : .gray)
                                    .frame(width: 36, height: 36)
                                    .background(selectedPenStyle == style ? Color.blue.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                            }
                        }
                        
                        Divider()
                            .frame(height: 24)
                    }
                    
                    // Add player button
                    Button(action: onAddPlayer) {
                        Image(systemName: "person.fill.badge.plus")
                            .font(.title3)
                            .foregroundColor(.gray)
                            .frame(width: 36, height: 36)
                    }
                    
                    // Add basketball button
                    Button(action: onAddBasketball) {
                        Image(systemName: "basketball.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                            .frame(width: 36, height: 36)
                    }
                    
                    Divider()
                        .frame(height: 24)
                    
                    // Undo button
                    Button(action: onUndo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 36, height: 36)
                    }
                    
                    // Clear button
                    Button(action: onClear) {
                        Image(systemName: "trash")
                            .font(.title3)
                            .foregroundColor(.red)
                            .frame(width: 36, height: 36)
                    }
                    
                    Spacer(minLength: 0)
                }
                .frame(width: geometry.size.width)
                .padding(.vertical, 4)
            }
        }
        .frame(height: 44)
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
    var normalizedPoints: [CGPoint]?  // Store normalized points for consistent representation
}

struct PlayerCircle {
    var position: CGPoint
    var number: Int
    var color: Color
    var normalizedPosition: CGPoint?
}

struct BasketballItem {
    var position: CGPoint
    var normalizedPosition: CGPoint?
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

// UIViewRepresentable to detect pencil vs finger touches
struct TouchTypeDetectionView: UIViewRepresentable {
    var onTouchesChanged: (TouchInputType, [CGPoint]) -> Void
    var onTouchesEnded: (TouchInputType) -> Void
    
    func makeUIView(context: Context) -> TouchDetectionView {
        let view = TouchDetectionView()
        view.onTouchesChanged = onTouchesChanged
        view.onTouchesEnded = onTouchesEnded
        return view
    }
    
    func updateUIView(_ uiView: TouchDetectionView, context: Context) {
        uiView.onTouchesChanged = onTouchesChanged
        uiView.onTouchesEnded = onTouchesEnded
    }
    
    // Custom UIView subclass to detect touches
    class TouchDetectionView: UIView {
        var onTouchesChanged: ((TouchInputType, [CGPoint]) -> Void)?
        var onTouchesEnded: ((TouchInputType) -> Void)?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            isMultipleTouchEnabled = true
            backgroundColor = .clear
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            processTouches(touches, with: event)
        }
        
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            processTouches(touches, with: event)
        }
        
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            let touchType: TouchInputType
            
            if #available(iOS 14.0, *) {
                switch touch.type {
                case .pencil:
                    touchType = .pencil
                case .direct:
                    touchType = .finger
                default:
                    touchType = .unknown
                }
            } else {
                touchType = touch.type == .stylus ? .pencil : .finger
            }
            
            onTouchesEnded?(touchType)
        }
        
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            let touchType: TouchInputType
            
            if #available(iOS 14.0, *) {
                switch touch.type {
                case .pencil:
                    touchType = .pencil
                case .direct:
                    touchType = .finger
                default:
                    touchType = .unknown
                }
            } else {
                touchType = touch.type == .stylus ? .pencil : .finger
            }
            
            onTouchesEnded?(touchType)
        }
        
        private func processTouches(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            
            let touchType: TouchInputType
            
            if #available(iOS 14.0, *) {
                switch touch.type {
                case .pencil:
                    touchType = .pencil
                case .direct:
                    touchType = .finger
                default:
                    touchType = .unknown
                }
            } else {
                touchType = touch.type == .stylus ? .pencil : .finger
            }
            
            // Important: Use PRECISE location for better accuracy
            let locations = touches.map { 
                // Use precise location if available (for Apple Pencil)
                if #available(iOS 13.4, *), $0.type == .pencil {
                    return $0.preciseLocation(in: self)
                } else {
                    return $0.location(in: self)
                }
            }
            
            // Pass touch type and all locations
            onTouchesChanged?(touchType, locations)
        }
    }
}

// Simplified ScaledCourtContainer
struct ScaledCourtContainer: View {
    let courtType: CourtType
    let content: AnyView
    
    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        let width = courtType == .full ? screenWidth * 0.98 * 1.65 : screenWidth * 0.98 * 0.97
        let height = courtType == .full ? (screenHeight - 48) * 0.98 * 1.58 : (screenHeight - 48) * 0.98 * 0.97
        
        return content
            .frame(width: width, height: height)
    }
} 
