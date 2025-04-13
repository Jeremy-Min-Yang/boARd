import SwiftUI
import PDFKit
import UIKit
import boARd // Add this line to import the module containing SavedPlayService
import SavedPlay

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
        height: 569,
        offsetX: 0,
        offsetY: 0
    )
    
    static let halfCourt = DrawingBoundary(
        width: 700,  // Keep doubled width
        height: 855,  // Restored from original value
        offsetX: 0,
        offsetY: 98   // Restored from original value
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
    @Binding var isPathAssignmentMode: Bool
    @Binding var selectedDrawingId: UUID?
    
    var body: some View {
        Canvas { context, size in
            // Draw all existing drawings
            for drawing in drawings {
                let path = drawing.path
                
                // Determine drawing color
                var drawingColor = drawing.color
                var lineWidth = drawing.lineWidth
                
                // Highlight selected path when in assignment mode
                if isPathAssignmentMode && selectedDrawingId == drawing.id {
                    // Selected path in assignment mode gets highlighted in green with thicker lines
                    drawingColor = .green
                    lineWidth += 4  // Make selected path thicker for better visibility
                }
                // Highlight paths that are assigned during animation
                else if drawing.isHighlightedDuringAnimation {
                    drawingColor = .green.opacity(0.6)
                    lineWidth += 2  // Make animated paths slightly thicker
                }
                // All other paths use their default color (black)
                
                if drawing.type == .arrow {
                    // Draw the arrow
                    if drawing.points.count >= 5 {
                        let lastPoint = drawing.points.last!
                        let firstPoint = drawing.points.first!
                        let arrowPath = createArrowPath(from: firstPoint, to: lastPoint)
                        context.stroke(arrowPath, with: .color(drawingColor), lineWidth: lineWidth)
                    }
                } else {
                    // Draw pen strokes
                    context.stroke(
                        path,
                        with: .color(drawingColor),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
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
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onEnded { value in
                    // Only handle taps in path assignment mode
                    if isPathAssignmentMode {
                        let location = value.location
                        print("DrawingLayer - Tap detected at: \(location)")
                        print("DrawingLayer - Number of drawings: \(drawings.count)")
                        handlePathSelection(at: location)
                    }
                }
        )
        .allowsHitTesting(true) // Explicitly allow hit testing
    }
    
    private func handlePathSelection(at location: CGPoint) {
        print("DrawingLayer - Handle Path Selection - Tap Location: \(location)") // Log tap location
        var tappedDrawingId: UUID? = nil
        let tapTolerance: CGFloat = 50.0 // Significantly increased tolerance for easier selection
        var minDistanceFound = Double.infinity // Initialize with infinity to always find the closest regardless of distance
        var closestDrawingId: UUID? = nil // Track closest drawing regardless of tolerance
    
        guard !drawings.isEmpty else {
            print("DrawingLayer - No drawings available.")
            selectedDrawingId = nil // Ensure selection is cleared if no drawings
            return
        }
    
        print("DrawingLayer - Checking \(drawings.count) drawings against tolerance \(tapTolerance)")
    
        for (drawingIndex, drawing) in drawings.enumerated() {
            guard drawing.points.count > 1 else {
                print("DrawingLayer - Drawing \(drawingIndex) (ID: \(drawing.id)) has < 2 points, skipping.")
                continue
            }
    
            // Log the first point for coordinate comparison
            if let firstPoint = drawing.points.first {
                 print("DrawingLayer - Drawing \(drawingIndex) (ID: \(drawing.id)) - First Point: \(firstPoint)")
            }
    
            var minDistanceForThisDrawing = Double.infinity // Use Double.infinity to always find the minimum
    
            // --- Check Pen/Zigzag/Squiggly Segments ---
            if drawing.type == .pen { // Only check segments for non-arrows here initially
                for i in 0..<(drawing.points.count - 1) {
                    let start = drawing.points[i]
                    let end = drawing.points[i+1]
                    let distanceToSegment = location.minimumDistance(toLineSegment: start, end: end)
                    // Log distance for every segment checked
                     print("DrawingLayer - Drawing \(drawingIndex) Segment \(i) (\(start) -> \(end)): Distance = \(distanceToSegment)")
    
                    if distanceToSegment < minDistanceForThisDrawing {
                        minDistanceForThisDrawing = distanceToSegment
                    }
                }
            }
            // --- Check Arrows (based on first/last points) ---
            else if drawing.type == .arrow {
                let start = drawing.points.first!
                let end = drawing.points.last!
                let distanceToSegment = location.minimumDistance(toLineSegment: start, end: end)
                print("DrawingLayer - Drawing \(drawingIndex) Arrow (\(start) -> \(end)): Distance = \(distanceToSegment)")
                if distanceToSegment < minDistanceForThisDrawing {
                    minDistanceForThisDrawing = distanceToSegment
                }
            }
    
            // --- Always track the closest drawing regardless of tolerance ---
            if minDistanceForThisDrawing < minDistanceFound {
                 minDistanceFound = minDistanceForThisDrawing
                 closestDrawingId = drawing.id
                 print("DrawingLayer - New closest drawing found: \(drawing.id) at distance \(minDistanceFound)")
            }
    
            // --- Check if this drawing is within tolerance (for standard selection logic) ---
            if minDistanceForThisDrawing < tapTolerance {
                if tappedDrawingId == nil || minDistanceForThisDrawing < minDistanceFound {
                    tappedDrawingId = drawing.id
                }
            }
        } // End of drawings loop
    
        // --- Final Decision ---
        print("DrawingLayer - Final decision: min distance \(minDistanceFound), tolerance \(tapTolerance)")
        
        // Always select the closest drawing if it's within tolerance
        if tappedDrawingId != nil {
            selectedDrawingId = tappedDrawingId
            print("DrawingLayer - >>> Selected Path: \(tappedDrawingId?.uuidString ?? "nil") <<<")
        } else {
            print("DrawingLayer - >>> Tap missed all paths, using closest drawing as fallback <<<")
            // FORCE select the closest drawing regardless of distance for testing
            selectedDrawingId = closestDrawingId
            if closestDrawingId != nil {
                print("DrawingLayer - >>> Forced selection of closest path: \(closestDrawingId!.uuidString) at distance \(minDistanceFound) <<<")
            } else {
                print("DrawingLayer - >>> No paths found at all <<<")
            }
        }
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
                .frame(width: courtWidth * 1.8, height: courtHeight * 1.7) // Restored to original values
        } else {
            Image("halfcourt")
                .resizable()
                .scaledToFit()  
                .overlay(
                    Rectangle()
                        .stroke(Color.black, lineWidth: 3)
                        .allowsHitTesting(false)
                )
                .frame(width: courtWidth * 1.05, height: courtHeight * 1.05) // Reduced from 1.15 to a more moderate value
                .clipped()
        }
    }
}

// Create a component for basketballs display
struct BasketballsView: View {
    let courtType: CourtType
    @Binding var basketballs: [BasketballItem]
    @Binding var draggedBasketballIndex: Int?
    @Binding var currentTouchType: TouchInputType
    @Binding var selectedTool: DrawingTool
    
    var body: some View {
        ZStack {
            ForEach(basketballs.indices, id: \.self) { index in
                let basketball = basketballs[index]
                
                BasketballView(position: basketball.position)
                    .position(basketball.position)
                    // Additional gesture recognizer specifically for move tool
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if selectedTool == .move {
                                    print("Direct basketball drag detected: \(index)")
                                    draggedBasketballIndex = index
                                    basketballs[index].position = value.location
                                }
                            }
                            .onEnded { value in
                                if selectedTool == .move && draggedBasketballIndex == index {
                                    // Update normalized position too
                                    let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
                                    let normalizedX = value.location.x / boundary.width
                                    let normalizedY = value.location.y / boundary.height
                                    basketballs[index].normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
                                    print("Direct basketball drag ended: \(index)")
                                }
                            },
                        including: selectedTool == .move ? .all : .subviews
                    )
            }
        }
    }
}

// Create a component for players display with improved touch handling
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
    
    // Helper function to get color for player - simplified to a single color
    private func getPlayerColor(_ player: PlayerCircle) -> Color {
        return .blue
    }
    
    var body: some View {
        ZStack {
            ForEach(players.indices, id: \.self) { index in
                let player = players[index]
                let playerColor = getPlayerColor(player)
                
                ZStack {
                    // Visual indicator for assigned paths - now more visible
                    if player.assignedPathId != nil {
                        // Outer ring indicating path assignment
                        Circle()
                            .stroke(Color.green, lineWidth: 3)
                            .frame(width: 56, height: 56)
                        
                        // Remove the connecting dashed line here
                    }
                    
                    // The actual player view
                    PlayerCircleView(
                        position: player.position,
                        number: player.number,
                        color: playerColor,
                        isMoving: player.isMoving
                    )
                }
                .position(player.position)
                .onTapGesture {
                    print("Player tapped directly: \(index)")
                    
                    // Handle in assignment mode
                    if isPathAssignmentMode, let drawingId = selectedDrawingId {
                        print("In assignment mode with selected path: \(drawingId)")
                        
                        // Add visual feedback when assigning path
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onAssignPath(drawingId, index)
                        }
                    } else if isPathAssignmentMode {
                        print("In assignment mode but NO drawing selected!")
                    } else {
                        print("Tap not in assignment mode")
                    }
                }
                // Additional gesture recognizer specifically for move tool
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if selectedTool == .move && !isPathAssignmentMode {
                                print("Direct player drag detected: \(index)")
                                draggedPlayerIndex = index
                                players[index].position = value.location
                            }
                        }
                        .onEnded { value in
                            if selectedTool == .move && !isPathAssignmentMode && draggedPlayerIndex == index {
                                // Update normalized position too
                                let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
                                let normalizedX = value.location.x / boundary.width
                                let normalizedY = value.location.y / boundary.height
                                players[index].normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
                                print("Direct player drag ended: \(index)")
                            }
                        },
                    including: selectedTool == .move ? .all : .subviews
                )
                // Increase zIndex when the player is moving during animation
                .zIndex(player.isMoving ? 20 : 1)
            }
        }
    }
}

// Add this struct definition within WhiteboardView or outside if preferred
struct PlayerAnimationData {
    let pathPoints: [CGPoint]
    let totalDistance: CGFloat
    let startTime: Date
    let duration: TimeInterval
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
    @State private var showClearConfirmation = false
    
    // Debug mode
    @State private var debugMode: Bool = true
    
    // Animation/Playback state
    @State private var playbackState: PlaybackState = .stopped
    @State private var isPathAssignmentMode: Bool = false
    @State private var selectedDrawingId: UUID?
    @State private var originalPlayerPositions: [UUID: CGPoint] = [:] // Use UUID as key
    @State private var originalBasketballPositions: [CGPoint] = [] // Keep as is for now
    
    // New state variables for centralized animation
    @State private var animationTimer: Timer?
    @State private var playerAnimationData: [UUID: PlayerAnimationData] = [:]
    
    // Add this new state variable to track all actions
    @State private var actions: [Action] = []
    
    // Add this new state variable to track the previous tool
    @State private var previousTool: DrawingTool?
    
    // Computed property to count assigned paths
    private var pathConnectionCount: Int {
        return players.filter { $0.assignedPathId != nil }.count
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) { // Changed to ZStack with top alignment
                // Main content area first (will be positioned below toolbar)
                courtContentView(geometry: geometry)
                    .padding(.top, 60) // Add padding to position below toolbar
                
                // Toolbar on top
                VStack(spacing: 0) {
                    ToolbarView(
                        selectedTool: $selectedTool,
                        selectedPenStyle: $selectedPenStyle,
                        playbackState: $playbackState,
                        isPathAssignmentMode: $isPathAssignmentMode,
                        pathCount: pathConnectionCount,
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
                            // Set the state to show the confirmation alert
                            showClearConfirmation = true
                        },
                        onPlayAnimation: {
                            startAnimation()
                        },
                        onStopAnimation: {
                            stopAnimation()
                        },
                        onAssignPath: {
                            togglePathAssignmentMode()
                        },
                        onToolChange: { tool in
                            // Handle tool change
                            handleToolChange(tool)
                        }
                    )
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                }
                
                // Remove the persistent path counter here
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
            // Add the confirmation alert modifier
            .alert("Clear Whiteboard?", isPresented: $showClearConfirmation) {
                Button("Clear", role: .destructive) {
                    // Perform the clear action
                    drawings.removeAll()
                    players.removeAll()
                    basketballs.removeAll()
                    actions.removeAll()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to clear the whiteboard? This action cannot be undone.")
            }
            .ignoresSafeArea(edges: .bottom) // Ensure content can use the full screen
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
            let courtHeight = geometry.size.height * 0.85 // Changed from (geometry.size.height - 48) * 0.98
            
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
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2 - 30) // Adjust Y position to account for toolbar
            
            // Path assignment mode overlay
            if isPathAssignmentMode {
                pathAssignmentOverlay()
            }
            
            // Add player mode overlay
            if isAddingPlayer {
                addPlayerOverlay(geometry: geometry)
            }
            
            // Add basketball mode overlay
            if isAddingBasketball {
                addBasketballOverlay(geometry: geometry)
            }
        }
    }
    
    // Further break down the content
    @ViewBuilder
    private func courtAndDrawingContent(geometry: GeometryProxy, courtWidth: CGFloat, courtHeight: CGFloat, 
                                      drawingWidth: CGFloat, drawingHeight: CGFloat, 
                                      drawingOffsetX: CGFloat, drawingOffsetY: CGFloat) -> some View {
        ZStack { // Outer ZStack containing background and the drawing area
            // Court image background
            CourtBackgroundView(courtType: courtType, courtWidth: courtWidth, courtHeight: courtHeight)
            
            // Inner ZStack for all drawing-related content
            ZStack {
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
                    draggedPlayerIndex: $draggedPlayerIndex,
                    isPathAssignmentMode: $isPathAssignmentMode,
                    selectedDrawingId: $selectedDrawingId
                )
                .zIndex(isPathAssignmentMode ? 50 : 0) // Increase zIndex when in path assignment mode

                // Touch detection - Sized to match drawing area
                TouchTypeDetectionView(
                    onTouchesChanged: { touchType, locations in
                        handleTouchChanged(touchType: touchType, locations: locations)
                    },
                    onTouchesEnded: { touchType in
                        handleTouchEnded(touchType: touchType)
                        // Hide indicator when touch ends
                        if selectedTool == .move {
                            showPencilIndicator = false
                        }
                    },
                    onMove: { location in
                        // Show touch location for debugging
                        lastTouchLocation = location
                        showPencilIndicator = true
                        
                        // Handle the move
                        handleMove(location: location)
                    },
                    selectedTool: selectedTool
                )
                // Set zIndex to ensure it's always on top for catching touches
                .zIndex(isPathAssignmentMode ? 0 : 5) // Lower zIndex when in path assignment mode
                // Always detect touches now
                .allowsHitTesting(!isPathAssignmentMode) // Disable touch detection in path assignment mode

                // Basketballs - Positioned within this ZStack's coordinate space
                BasketballsView(
                    courtType: courtType,
                    basketballs: $basketballs,
                    draggedBasketballIndex: $draggedBasketballIndex,
                    currentTouchType: $currentTouchType,
                    selectedTool: $selectedTool
                )
                .zIndex(selectedTool == .move || playbackState == .playing ? 10 : 2) // Higher z-index when in move mode or during playback

                // Player circles - Positioned within this ZStack's coordinate space
                PlayersView(
                    courtType: courtType,
                    players: $players,
                    draggedPlayerIndex: $draggedPlayerIndex,
                    currentTouchType: $currentTouchType,
                    selectedTool: $selectedTool,
                    isPathAssignmentMode: $isPathAssignmentMode,
                    selectedDrawingId: $selectedDrawingId,
                    drawings: $drawings,
                    onAssignPath: assignPathToPlayer
                )
                .zIndex(selectedTool == .move || playbackState == .playing ? 10 : 3) // Higher z-index when in move mode or during playback

                // Pencil indicator - Positioned within this ZStack's coordinate space
                if showPencilIndicator {
                    ZStack {
                        if selectedTool == .move {
                            // Red crosshair for move tool
                            Circle()
                                .fill(Color.red.opacity(0.7))
                                .frame(width: 16, height: 16)
                            
                            Circle()
                                .stroke(Color.red, lineWidth: 2)
                                .frame(width: 40, height: 40)
                            
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 20, height: 2)
                            
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: 2, height: 20)
                        } else {
                            // Blue circle for drawing tools
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 16, height: 16)
                            
                            Circle()
                                .stroke(Color.blue, lineWidth: 1)
                                .frame(width: 24, height: 24)
                        }
                    }
                    .position(lastTouchLocation)
                    .allowsHitTesting(false) // Don't let indicator block touches
                    .zIndex(100) // Make sure it's visible on top
                }
                
                // Add a global tap gesture recognizer that checks if a player was tapped
                if isPathAssignmentMode, let selectedPath = selectedDrawingId {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            // Use DragGesture with minimumDistance of 0 to simulate a tap
                            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                .onEnded { value in
                                    let location = value.location
                                    print("Global tap at location: \(location)")
                                    
                                    // Check if any player was tapped
                                    for (index, player) in players.enumerated() {
                                        // Make the hit area larger for easier selection
                                        // Reduce the hit area size (from 70x70 to 60x60)
                                        let playerFrame = CGRect(
                                            x: player.position.x - 30, 
                                            y: player.position.y - 30,
                                            width: 60, 
                                            height: 60
                                        )
                                        
                                        if playerFrame.contains(location) {
                                            print("Player tapped via global recognizer: \(index)")
                                            assignPathToPlayer(drawingId: selectedPath, playerIndex: index)
                                            break
                                        }
                                    }
                                    
                                    // The following block attempting path selection is removed.
                                    // Path selection is now solely handled by DrawingLayer.
                                    
                                }
                        )
                        .zIndex(100) // Ensure this is on top
                }
            }
            .frame(width: drawingWidth, height: drawingHeight) // Apply frame to inner ZStack
            .offset(x: drawingOffsetX, y: drawingOffsetY) // Apply offset to inner ZStack
            .clipped() // Prevent drawing outside the bounds
            .contentShape(Rectangle()) // Define hit area for gestures if needed directly on ZStack
            
            // Add debug overlay when in debug mode
            if debugMode && selectedTool == .move {
                VStack {
                    Text("DEBUG INFO")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Last Touch: \(String(format: "%.1f,%.1f", lastTouchLocation.x, lastTouchLocation.y))")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    
                    if let index = draggedPlayerIndex {
                        Text("Dragging Player: \(index)")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    } else if let index = draggedBasketballIndex {
                        Text("Dragging Ball: \(index)")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    } else {
                        Text("Nothing being dragged")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    
                    Text("Drawing Area: \(Int(drawingWidth))×\(Int(drawingHeight))")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                    
                    Text("Offset: \(String(format: "%.1f,%.1f", drawingOffsetX, drawingOffsetY))")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .padding(8)
                .position(x: geometry.size.width - 100, y: 100)
                .zIndex(200)
            }
        }
    }
    
    // Add a helper method to exit path assignment mode
    private func exitPathAssignmentMode() {
        isPathAssignmentMode = false
        selectedDrawingId = nil
        
        // Restore previous tool when exiting assignment mode
        if let prevTool = previousTool {
            selectedTool = prevTool
        }
    }
    
    // Add a clear visual indicator for path assignment mode
    @ViewBuilder
    private func pathAssignmentOverlay() -> some View {
        VStack {
            // Status banner at top
            HStack {
                Image(systemName: "arrow.triangle.pull")
                    .foregroundColor(.white)
                
                Text("PATH ASSIGNMENT MODE")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if selectedDrawingId != nil {
                    Text("• PATH SELECTED")
                        .font(.headline)
                        .foregroundColor(.green)
                } else {
                    Text("• TAP A PATH")
                        .font(.headline)
                        .foregroundColor(.yellow)
                }
                
                Spacer()
                
                Button(action: {
                    exitPathAssignmentMode()
                }) {
                    Text("Done")
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding()
            .background(Color.black.opacity(0.7))
            
            Spacer()

            // Remove the diagnostic tap button here

            // Show assigned path count in the middle of the screen
            // Update to use playerAnimationData
            if playerAnimationData.count > 0 {
                Text("\(playerAnimationData.count) paths assigned")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
            }
            
            Spacer()
            
            // Instructions at the bottom
            if selectedDrawingId != nil {
                Text("Now tap a player to assign this path")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
            } else {
                Text("Tap on a drawing to select it")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
            }
        }
        .padding(.bottom, 20)
    }
    
    // Add player overlay
    @ViewBuilder
    private func addPlayerOverlay(geometry: GeometryProxy) -> some View {
        // Retrieve necessary dimensions and offsets based on courtType and geometry
        let parentWidth = geometry.size.width
        let parentHeight = geometry.size.height

        let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
        let drawingWidth = boundary.width
        let drawingHeight = boundary.height
        let drawingOffsetX = boundary.offsetX
        let drawingOffsetY = boundary.offsetY

        // Calculate the origin of the drawing area relative to the parent overlay's coordinate system
        // Take into account the padding and position adjustments
        let drawingAreaOriginX = parentWidth / 2 + drawingOffsetX - drawingWidth / 2
        
        // Fix for half court asset placement - use a dynamic yAdjustment
        // Removed unused yAdjustment: let yAdjustment: CGFloat = 60
        let drawingAreaOriginY = (parentHeight / 2 - 30) + drawingOffsetY - drawingHeight / 2

        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { // Tap outside the gesture area to cancel
                    isAddingPlayer = false
                }
            
            // Informational text
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
            .allowsHitTesting(false) // Let taps pass through the text area
            
            // Gesture capturing area (fills the parent - the inner ZStack)
            Color.clear
                .contentShape(Rectangle()) // Makes the clear color tappable
                .gesture(
                    // Use DragGesture with minimal distance to detect taps
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            // Get the tap location relative to this view (which is the inner ZStack)
                            let tapPosition = value.location
                            print("Overlay Tap Position: \(tapPosition)")
                            print("Calculated Drawing Area Origin: (\(drawingAreaOriginX), \(drawingAreaOriginY))")

                            // Convert tap position to be relative to the drawing area's origin
                            let relativeX = tapPosition.x - drawingAreaOriginX
                            let relativeY = tapPosition.y - drawingAreaOriginY
                            let adjustedPosition = CGPoint(x: relativeX, y: relativeY)

                            // Check if the tap is within the drawing bounds before adding
                            if relativeX >= 0 && relativeX <= drawingWidth && relativeY >= 0 && relativeY <= drawingHeight {
                                print("Adjusted Position (Relative to Drawing Area): \(adjustedPosition)")
                                addPlayerAt(position: adjustedPosition)
                            } else {
                                print("Tap outside drawing bounds.")
                            }
                            isAddingPlayer = false
                        }
                )
        }
    }
    
    // Add basketball overlay
    @ViewBuilder
    private func addBasketballOverlay(geometry: GeometryProxy) -> some View {
        // Retrieve necessary dimensions and offsets (same logic as addPlayerOverlay)
        let parentWidth = geometry.size.width
        let parentHeight = geometry.size.height

        let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
        let drawingWidth = boundary.width
        let drawingHeight = boundary.height
        let drawingOffsetX = boundary.offsetX
        let drawingOffsetY = boundary.offsetY

        // Calculate with the same adjustment as the player overlay
        let drawingAreaOriginX = parentWidth / 2 + drawingOffsetX - drawingWidth / 2
        
        // Fix for half court asset placement - use a dynamic yAdjustment
        // Removed unused yAdjustment: let yAdjustment: CGFloat = 60
        let drawingAreaOriginY = (parentHeight / 2 - 30) + drawingOffsetY - drawingHeight / 2

        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { // Tap outside the gesture area to cancel
                    isAddingBasketball = false
                }
            
            // Informational text
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
            .allowsHitTesting(false) // Let taps pass through the text area
            
            // Gesture capturing area
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let tapPosition = value.location
                            
                            // Convert tap position to drawing area coordinates
                            let relativeX = tapPosition.x - drawingAreaOriginX
                            let relativeY = tapPosition.y - drawingAreaOriginY
                            let adjustedPosition = CGPoint(x: relativeX, y: relativeY)

                            // Check if the tap is within bounds
                            if relativeX >= 0 && relativeX <= drawingWidth && relativeY >= 0 && relativeY <= drawingHeight {
                                addBasketballAt(position: adjustedPosition)
                            }
                            isAddingBasketball = false
                        }
                )
        }
    }
    
    private func handleTouchChanged(touchType: TouchInputType, locations: [CGPoint]) {
        // Update current touch type
        currentTouchType = touchType
        
        // Only show pencil indicator when using a pencil with drawing tools
        if touchType == .pencil {
            showPencilIndicator = (selectedTool == .pen || selectedTool == .arrow)
        } else {
            showPencilIndicator = false
        }
        
        // If we're in drawing mode with a pencil, and not currently dragging something, handle drawing
        if touchType == .pencil && 
           (selectedTool == .pen || selectedTool == .arrow) && 
           draggedPlayerIndex == nil && 
           draggedBasketballIndex == nil &&
           !isPathAssignmentMode { // Prevent drawing in path assignment mode
            
            // Process each location received (includes coalesced touches)
            if !locations.isEmpty {
                // Use the last location for visual indicator
                lastTouchLocation = locations.last!
                
                // Process each location for drawing
                for location in locations {
                    if currentDrawing == nil {
                        // Start a new drawing with the first point
                        self.startNewDrawing(at: location)
                    } else {
                        // Continue existing drawing with subsequent points
                        self.continueDrawing(at: location)
                    }
                }
                
                // Debug info for drawing
                if debugMode {
                    print("Drawing at \(lastTouchLocation)")
                }
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
        // Get the drawing boundary for normalization
        let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
        
        // The 'point' is now relative to the inner drawing ZStack. Use it directly.
        let currentPoint = point
        
        // Calculate normalized position relative to the drawing area dimensions
        let normalizedX = currentPoint.x / boundary.width
        let normalizedY = currentPoint.y / boundary.height
        let normalizedPoint = CGPoint(x: normalizedX, y: normalizedY)
        
        // Start a new drawing path
        var newPath = Path()
        newPath.move(to: currentPoint)
        
        // Determine line width based on input type
        let lineWidth = (selectedTool == .arrow) ? 8 : getPencilWidth(for: currentTouchType)
        let drawingType: DrawingTool = selectedTool
        let penStyle: PenStyle = selectedPenStyle
        
        currentDrawing = Drawing(
            path: newPath,
            color: .black,
            lineWidth: lineWidth,
            type: drawingType,
            style: penStyle,
            points: [currentPoint], // Use direct point
            normalizedPoints: [normalizedPoint]
        )
        
        // Update the indicator position
        lastTouchLocation = currentPoint
    }
    
    private func continueDrawing(at point: CGPoint) {
        guard var drawing = currentDrawing else { return }
        
        // Get the drawing boundary for normalization
        let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
        
        // The 'point' is now relative to the inner drawing ZStack. Use it directly.
        let currentPoint = point

        // Calculate normalized position relative to the drawing area dimensions
        let normalizedX = currentPoint.x / boundary.width
        let normalizedY = currentPoint.y / boundary.height
        let normalizedPoint = CGPoint(x: normalizedX, y: normalizedY)
        
        // Add the current point to our points array
        drawing.points.append(currentPoint) // Use direct point
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
                path.addLine(to: currentPoint)
                
            case .squiggly:
                // Create squiggly effect
                let mid = previousPoint.midpoint(to: currentPoint)
                let offset = CGPoint(
                    x: (mid.y - previousPoint.y),
                    y: (previousPoint.x - mid.x)
                )
                let controlPoint = CGPoint(
                    x: mid.x + offset.x,
                    y: mid.y + offset.y
                )
                path.addQuadCurve(to: currentPoint, control: controlPoint)
                
            case .zigzag:
                // Create zigzag effect
                let distance = previousPoint.distance(to: currentPoint)
                let segments = max(Int(distance / 3), 1)
                
                if segments > 1 {
                    // For multiple segments, calculate zigzag points
                    for i in 1...segments {
                        let t = CGFloat(i) / CGFloat(segments)
                        let point = previousPoint.interpolated(to: currentPoint, t: t)
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
                    path.addLine(to: currentPoint)
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
        lastTouchLocation = currentPoint // Use direct point
    }
    
    private func handleTouchEnded(touchType: TouchInputType) {
        print("WhiteboardView handleTouchEnded - TouchType: \(touchType), CurrentDrawing Exists: \(currentDrawing != nil)")

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
        
        // Reset any dragged indices to finish movement
        if selectedTool == .move {
            // Safety check before resetting indices
            if let index = draggedPlayerIndex {
                if index >= 0 && index < players.count {
                    print("Finalizing player movement at index \(index)")
                    // Normalize the position before resetting
                    let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
                    let normalizedX = players[index].position.x / boundary.width
                    let normalizedY = players[index].position.y / boundary.height
                    players[index].normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
                } else {
                    print("Ignoring invalid player index: \(index)")
                }
            }
            
            if let index = draggedBasketballIndex {
                if index >= 0 && index < basketballs.count {
                    print("Finalizing basketball movement at index \(index)")
                    // Normalize the position before resetting
                    let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
                    let normalizedX = basketballs[index].position.x / boundary.width
                    let normalizedY = basketballs[index].position.y / boundary.height
                    basketballs[index].normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
                } else {
                    print("Ignoring invalid basketball index: \(index)")
                }
            }
            
            // Clear both indices
            draggedPlayerIndex = nil
            draggedBasketballIndex = nil
            print("Touch ended, cleared dragged indices")
        }
    }
    
    private func addPlayerAt(position: CGPoint) {
        // Check if we've reached the player limit
        if players.count >= 5 {
            showPlayerLimitAlert = true
            return
        }
        
        // Get the boundary for normalization
        let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
        
        // The 'position' received is now already adjusted relative to the drawing area.
        // Use the position directly.
        let adjustedPosition = position
        
        // Calculate normalized position relative to the drawing area dimensions
        let normalizedX = adjustedPosition.x / boundary.width
        let normalizedY = adjustedPosition.y / boundary.height
        
        let newPlayer = PlayerCircle(
            position: adjustedPosition, 
            number: players.count + 1, 
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
        
        // Get the boundary for normalization
        let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
        
        // The 'position' received is now already adjusted relative to the drawing area.
        // Use the position directly.
        let adjustedPosition = position
        
        // Calculate normalized position relative to the drawing area dimensions
        let normalizedX = adjustedPosition.x / boundary.width
        let normalizedY = adjustedPosition.y / boundary.height
        
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
    
    // Add these functions for animation control
    private func togglePathAssignmentMode() {
        // Toggle the path assignment mode
        isPathAssignmentMode.toggle()
        
        // When entering path assignment mode
        if isPathAssignmentMode {
            // Store the previous tool to restore later
            previousTool = selectedTool
            selectedTool = .move
            
            // Log debug info
            print("=========================================")
            print("ENTERING PATH ASSIGNMENT MODE")
            print("Current drawings count: \(drawings.count)")
            print("Current players count: \(players.count)")
            
            // Print details about each drawing for debugging
            if !drawings.isEmpty {
                print("Drawing details:")
                for (index, drawing) in drawings.enumerated() {
                    let firstPoint = drawing.points.first ?? CGPoint.zero
                    let lastPoint = drawing.points.last ?? CGPoint.zero
                    print("Drawing \(index): ID=\(drawing.id), Type=\(drawing.type), Points=\(drawing.points.count), First=\(firstPoint), Last=\(lastPoint)")
                }
            } else {
                print("WARNING: No drawings available to select")
            }
            
            print("=========================================")
        } else {
            // Exiting path assignment mode
            // Reset the selection
            selectedDrawingId = nil
            
            // Restore previous tool when exiting assignment mode
            if let prevTool = previousTool {
                selectedTool = prevTool
            }
            
            print("=========================================")
            print("EXITING PATH ASSIGNMENT MODE")
            print("=========================================")
        }
    }
    
    private func assignPathToPlayer(drawingId: UUID, playerIndex: Int) {
        print("Assigning drawing \(drawingId) to player at index \(playerIndex)")
        
        // Validate player index
        guard playerIndex >= 0, playerIndex < players.count else {
            print("Invalid player index: \(playerIndex), players count: \(players.count)")
            return
        }
        
        // Find the drawing
        guard let drawingIndex = drawings.firstIndex(where: { $0.id == drawingId }) else {
            print("Drawing with ID \(drawingId) not found")
            return
        }
        
        // Remove the assignment from any other player that might have this path
        for i in players.indices {
            if players[i].assignedPathId == drawingId {
                print("Removing existing assignment from player \(i)")
                players[i].assignedPathId = nil
            }
        }
        
        // Assign this path to the player
        print("Setting player \(playerIndex) assigned path to \(drawingId)")
        
        // Add visual feedback with a small delay
        withAnimation(.easeInOut(duration: 0.3)) {
            players[playerIndex].assignedPathId = drawingId
        }
        
        // Update the drawing's associated player ID (Optional, but can be kept)
        print("Setting drawing \(drawingId) associated player index to \(playerIndex)")
        drawings[drawingIndex].associatedPlayerIndex = playerIndex
        
        // Keep the selected drawing ID for further assignments
        selectedDrawingId = drawingId
        
        // Reset selection after successful assignment to allow selecting a new path
        print("Path assigned successfully, resetting selection.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            selectedDrawingId = nil
        }
    }

    // Add the new update function here
    private func updateAnimations(timer: Timer) {
        let currentTime = Date()
        var allAnimationsComplete = true

        for (playerId, animData) in playerAnimationData {
            // Find the player index using the ID
            guard let playerIndex = players.firstIndex(where: { $0.id == playerId }) else {
                print("Warning: Could not find player with ID \(playerId) during animation update.")
                // Potentially remove this entry from playerAnimationData if player no longer exists
                continue
            }

            let elapsedTime = currentTime.timeIntervalSince(animData.startTime)
            var progress = elapsedTime / animData.duration

            // Clamp progress between 0 and 1
            progress = max(0, min(1, progress))

            // Get the new position based on progress
            if let newPosition = getPointOnPath(points: animData.pathPoints, progress: progress) {
                // Update player position directly - NO withAnimation here!
                players[playerIndex].position = newPosition
                players[playerIndex].isMoving = progress < 1.0 // Update isMoving based on progress
            } else {
                print("Warning: Could not get point on path for player \(playerId) at progress \(progress)")
            }

            // Check if this animation is still ongoing
            if progress < 1.0 {
                allAnimationsComplete = false
            } else {
                 // Ensure player is marked as not moving if their animation is done
                 if players[playerIndex].isMoving {
                    players[playerIndex].isMoving = false
                 }
            }
        }

        // If all animations are done, stop the timer
        if allAnimationsComplete {
            print("All animations completed.")
            stopAnimation() // Call stop to clean up state
        }
    }

    private func startAnimation() {
        guard playbackState != .playing else {
            print("Animation already in progress")
            return
        }

        print("Preparing animation...")
        playbackState = .playing // Set state early

        // 1. Clear previous animation data and store original positions
        animationTimer?.invalidate() // Stop any existing timer
        playerAnimationData.removeAll()
        originalPlayerPositions.removeAll()

        let pixelsPerSecond: CGFloat = 275 // Increased speed for more realistic basketball movements
        var playersToAnimate = 0
        let startTime = Date() // Use a single start time for all animations starting now

        // Highlight all paths being followed during animation
        for i in drawings.indices {
            if players.contains(where: { $0.assignedPathId == drawings[i].id }) {
                // This drawing has an assigned player - highlight it during animation
                drawings[i].isHighlightedDuringAnimation = true
            }
        }

        // 2. Iterate through players and prepare animation data
        for playerIndex in players.indices {
            guard let pathId = players[playerIndex].assignedPathId,
                  let drawing = drawings.first(where: { $0.id == pathId }),
                  !drawing.points.isEmpty else {
                // Skip players without a valid assigned path
                continue
            }

            let playerId = players[playerIndex].id
            let pathPoints = drawing.points

            // Store original position
            originalPlayerPositions[playerId] = players[playerIndex].position

            // Calculate path length and duration
            let totalDistance = calculatePathLength(points: pathPoints)
            let duration = totalDistance / pixelsPerSecond

            // Ensure minimum duration to avoid division by zero or instant animations
            let animationDuration = max(0.1, TimeInterval(duration)) // Minimum 0.1 seconds

            // Create animation data
            let animData = PlayerAnimationData(
                pathPoints: pathPoints,
                totalDistance: totalDistance,
                startTime: startTime,
                duration: animationDuration
            )
            playerAnimationData[playerId] = animData

            // Mark player as moving and set initial position
            players[playerIndex].isMoving = true
            players[playerIndex].position = pathPoints.first! // Start at the beginning of the path

            playersToAnimate += 1
            print("Prepared animation for player \(playerIndex) (ID: \(playerId)) - Path: \(pathId), Duration: \(animationDuration)")
        }

        // 3. Start the timer if there are players to animate
        if playersToAnimate > 0 {
            print("Starting animation timer for \(playersToAnimate) players.")
            // Remove [weak self] capture
            animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
                self.updateAnimations(timer: timer)
            }
        } else {
            print("No players have assigned paths, stopping animation.")
            playbackState = .stopped // Reset state if nothing to animate
        }
    }

    private func stopAnimation() {
        print("Stopping animation")

        // 1. Invalidate the timer
        animationTimer?.invalidate()
        animationTimer = nil // Clear the timer reference

        // 2. Reset player positions and state
        for (playerId, originalPosition) in originalPlayerPositions {
            if let playerIndex = players.firstIndex(where: { $0.id == playerId }) {
                players[playerIndex].position = originalPosition
                players[playerIndex].isMoving = false // Ensure moving flag is reset
            }
        }

        // Reset highlighted paths
        for i in drawings.indices {
            drawings[i].isHighlightedDuringAnimation = false
        }

        // 3. Clear animation data
        playerAnimationData.removeAll()
        originalPlayerPositions.removeAll() // Clear stored original positions

        // 4. Reset playback state
        playbackState = .stopped

        // Reset basketball positions (keeping existing logic for now)
        if !originalBasketballPositions.isEmpty {
            for i in 0..<min(basketballs.count, originalBasketballPositions.count) {
                basketballs[i].position = originalBasketballPositions[i]
            }
            originalBasketballPositions.removeAll() // Clear stored basketball positions
        }

        print("Animation stopped and state reset.")
    }
    
    private func handleMove(location: CGPoint) {
        if debugMode {
            print("======== MOVE DEBUG ========")
            print("Touch location: \(location)")
            print("Players count: \(players.count)")
            for (i, p) in players.enumerated() {
                print("Player \(i): position=\(p.position)")
            }
            print("Basketballs count: \(basketballs.count)")
            for (i, b) in basketballs.enumerated() {
                print("Basketball \(i): position=\(b.position)")
            }
            print("Currently dragged: player=\(String(describing: draggedPlayerIndex)), basketball=\(String(describing: draggedBasketballIndex))")
        }
        
        // If there are no players or basketballs, don't try to access them
        if players.isEmpty && basketballs.isEmpty {
            // Clear any potential drag indices as there's nothing to drag
            draggedPlayerIndex = nil
            draggedBasketballIndex = nil
            if debugMode {
                print("No players or basketballs available to move")
                print("============================")
            }
            return
        }
        
        // Safety check for player index
        if let playerIndex = draggedPlayerIndex {
            // Make sure the index is in range
            if playerIndex >= 0 && playerIndex < players.count {
                // Continue moving the currently dragged player
                if debugMode {
                    print("Continuing to move player \(playerIndex) to \(location)")
                }
                
                // Update position
                players[playerIndex].position = location
                
                // Also update normalized position
                let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
                let normalizedX = location.x / boundary.width
                let normalizedY = location.y / boundary.height
                players[playerIndex].normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
                return
            } else {
                // Index out of range, reset it
                print("WARNING: Player index \(playerIndex) out of range, resetting")
                draggedPlayerIndex = nil
            }
        }
        
        // Safety check for basketball index
        if let basketballIndex = draggedBasketballIndex {
            // Make sure the index is in range
            if basketballIndex >= 0 && basketballIndex < basketballs.count {
                // Continue moving the currently dragged basketball
                if debugMode {
                    print("Continuing to move basketball \(basketballIndex) to \(location)")
                }
                
                // Update position
                basketballs[basketballIndex].position = location
                
                // Also update normalized position
                let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
                let normalizedX = location.x / boundary.width
                let normalizedY = location.y / boundary.height
                basketballs[basketballIndex].normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
                return
            } else {
                // Index out of range, reset it
                print("WARNING: Basketball index \(basketballIndex) out of range, resetting")
                draggedBasketballIndex = nil
            }
        }
        
        // Nothing being dragged yet, check if we're on a player or basketball
        
        // First try to find a player at this location
        for (index, player) in players.enumerated() {
            // Create a hit test frame around player position
            let hitFrame = CGRect(
                x: player.position.x - 40,
                y: player.position.y - 40,
                width: 80,
                height: 80
            )
            
            if hitFrame.contains(location) {
                // Found a player to move
                if debugMode {
                    print("FOUND HIT! Starting to move player \(index) at \(location)")
                    print("Player position: \(player.position)")
                    print("Hit frame: \(hitFrame)")
                }
                
                // Start dragging this player
                draggedPlayerIndex = index
                players[index].position = location
                return
            } else if debugMode {
                print("No hit on player \(index), hitFrame=\(hitFrame), touch=\(location)")
            }
        }
        
        // If no player found, try to find a basketball
        for (index, basketball) in basketballs.enumerated() {
            // Create a hit test frame around basketball position
            let hitFrame = CGRect(
                x: basketball.position.x - 35,
                y: basketball.position.y - 35,
                width: 70,
                height: 70
            )
            
            if hitFrame.contains(location) {
                // Found a basketball to move
                if debugMode {
                    print("FOUND HIT! Starting to move basketball \(index) at \(location)")
                    print("Basketball position: \(basketball.position)")
                    print("Hit frame: \(hitFrame)")
                }
                
                // Start dragging this basketball
                draggedBasketballIndex = index
                basketballs[index].position = location
                return
            } else if debugMode {
                print("No hit on basketball \(index), hitFrame=\(hitFrame), touch=\(location)")
            }
        }
        
        if debugMode {
            print("No item found to move at \(location)")
            print("============================")
        }
    }
    
    private func handleToolChange(_ tool: DrawingTool) {
        // Reset touch handling when changing tools
        if selectedTool != tool {
            // Clear any drawing in progress
            if tool != .pen && tool != .arrow {
                currentDrawing = nil
            }
            
            // Reset touch location when switching away from move tool
            if selectedTool == .move {
                // Hide any pencil indicator
                showPencilIndicator = false
                // Reset last touch location
                lastTouchLocation = .zero
            }
            
            // Reset drag indices when switching away from move tool
            if selectedTool == .move && (tool == .pen || tool == .arrow) {
                draggedPlayerIndex = nil
                draggedBasketballIndex = nil
            }
        }
        
        // Debug info for move tool
        if tool == .move {
            print("Move tool selected - touch detection disabled")
        } else if tool == .pen || tool == .arrow {
            print("Drawing tool selected - touch detection enabled")
        }
    }
}

struct ToolbarView: View {
    @Binding var selectedTool: DrawingTool
    @Binding var selectedPenStyle: PenStyle
    @Binding var playbackState: PlaybackState
    @Binding var isPathAssignmentMode: Bool
    let pathCount: Int
    var onAddPlayer: () -> Void
    var onAddBasketball: () -> Void
    var onUndo: () -> Void
    var onClear: () -> Void
    var onPlayAnimation: () -> Void
    var onStopAnimation: () -> Void
    var onAssignPath: () -> Void
    var onToolChange: (DrawingTool) -> Void // New callback for handling tool changes
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    Spacer(minLength: 0)
                    
                    // Drawing tool selection
                    ForEach(DrawingTool.allCases, id: \.self) { tool in
                        Button(action: {
                            // Use the callback to handle tool changes
                            onToolChange(tool)
                            
                            // Update the local tool state
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
                    
                    // Animation controls
                    Button(action: onAssignPath) {
                        ZStack {
                            Image(systemName: "arrow.triangle.pull")
                                .font(.title3)
                                .foregroundColor(isPathAssignmentMode ? .blue : .gray)
                                .frame(width: 36, height: 36)
                                .background(isPathAssignmentMode ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                            
                            // Show path count badge if there are assigned paths
                            if pathCount > 0 && !isPathAssignmentMode {
                                Text("\(pathCount)")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.green)
                                    .clipShape(Circle())
                                    .offset(x: 12, y: -12)
                            }
                        }
                    }
                    
                    if playbackState == .stopped {
                        Button(action: onPlayAnimation) {
                            Image(systemName: "play.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                                .frame(width: 36, height: 36)
                        }
                        .disabled(pathCount == 0) // Disable if no paths assigned
                        .opacity(pathCount == 0 ? 0.5 : 1.0) // Show as faded if disabled
                    } else {
                        Button(action: onStopAnimation) {
                            Image(systemName: "stop.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                                .frame(width: 36, height: 36)
                        }
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
    var isMoving: Bool = false
    
    var body: some View {
        ZStack {
            // Trailing effect when player is moving
            if isMoving {
                Circle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 54, height: 54)
                    .blur(radius: 4)
            }
            
            // Background circle
            Circle()
                .stroke(Color.black, lineWidth: 2)
                .background(Circle().fill(color))
                .frame(width: 50, height: 50)
            
            // Player number
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(width: 50, height: 50)
        // Make sure the entire view responds to touch events
        .contentShape(Circle())
    }
}

struct BasketballView: View {
    let position: CGPoint
    
    var body: some View {
        Image("basketball")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 40, height: 40)
            // Make sure the entire view responds to touch events
            .contentShape(Circle())
    }
}

struct Drawing {
    var id: UUID = UUID()  // Add unique identifier
    var path: Path
    var color: Color
    var lineWidth: CGFloat
    var type: DrawingTool
    var style: PenStyle
    var points: [CGPoint]  // Track points manually
    var normalizedPoints: [CGPoint]?  // Store normalized points for consistent representation
    var isAssignedToPlayer: Bool = false  // Track if this path is assigned to a player
    var associatedPlayerIndex: Int?  // Track the associated player index
    var isHighlightedDuringAnimation: Bool = false  // Track if this path should be highlighted during animation
}

struct PlayerCircle {
    var id = UUID() // Add unique ID
    var position: CGPoint
    var number: Int
    var color: Color = .blue  // Fixed color instead of computed property
    var normalizedPosition: CGPoint?
    var assignedPathId: UUID?  // Reference to drawing that this player should follow
    var isMoving: Bool = false  // Track if the player is currently moving
}

struct BasketballItem {
    var position: CGPoint
    var normalizedPosition: CGPoint?
    var assignedPathId: UUID?  // Reference to drawing that basketball should follow
}

enum DrawingTool: String, CaseIterable {
    case pen
    case arrow
    case move
    
    var iconName: String {
        switch self {
        case .pen: return "pencil"
        case .arrow: return "arrow.up.right"
        case .move: return "hand.point.up.left.fill"
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

    // Helper function to calculate minimum distance from a point to a line segment
    func minimumDistance(toLineSegment start: CGPoint, end: CGPoint) -> CGFloat {
        let segmentLengthSq = start.distanceSquared(to: end)
        if segmentLengthSq == 0 { // Start and end points are the same
            return self.distance(to: start)
        }

        // Project self onto the line defined by start and end
        let t = ((self.x - start.x) * (end.x - start.x) + (self.y - start.y) * (end.y - start.y)) / segmentLengthSq
        let clampedT = max(0, min(1, t))

        // Find the closest point on the segment
        let closestPoint = CGPoint(
            x: start.x + clampedT * (end.x - start.x),
            y: start.y + clampedT * (end.y - start.y)
        )

        return self.distance(to: closestPoint)
    }

    // Helper for squared distance (avoids sqrt)
    func distanceSquared(to point: CGPoint) -> CGFloat {
        let dx = point.x - self.x
        let dy = point.y - self.y
        return dx*dx + dy*dy
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
    var onMove: ((CGPoint) -> Void)?  // New optional callback for move tool
    var selectedTool: DrawingTool  // Add tool selection as a parameter
    
    func makeUIView(context: Context) -> TouchDetectionView {
        let view = TouchDetectionView()
        view.onTouchesChanged = onTouchesChanged
        view.onTouchesEnded = onTouchesEnded
        view.onMove = onMove
        view.selectedTool = selectedTool
        return view
    }
    
    func updateUIView(_ uiView: TouchDetectionView, context: Context) {
        uiView.onTouchesChanged = onTouchesChanged
        uiView.onTouchesEnded = onTouchesEnded
        uiView.onMove = onMove
        
        // If the tool changed, reset internal state
        if uiView.selectedTool != selectedTool {
            uiView.selectedTool = selectedTool
            uiView.resetInternalState()
        }
    }
    
    // Custom UIView subclass to detect touches
    class TouchDetectionView: UIView {
        var onTouchesChanged: ((TouchInputType, [CGPoint]) -> Void)?
        var onTouchesEnded: ((TouchInputType) -> Void)?
        var onMove: ((CGPoint) -> Void)?
        var selectedTool: DrawingTool = .pen
        // Track the current touch for better handling
        private var currentTouch: UITouch?
        
        func resetInternalState() {
            // Clear current touch when tool changes
            currentTouch = nil
            print("TouchDetectionView - reset internal state for tool: \(selectedTool)")
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            isMultipleTouchEnabled = true
            backgroundColor = .clear
            // Log frame changes to debug coordinate issues
            print("TouchDetectionView initialized")
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            print("TouchDetectionView frame updated: \(self.frame)")
        }
        
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            print("TouchDetectionView - touchesBegan - tool: \(selectedTool), frame: \(self.frame)")
            
            guard let touch = touches.first else { return }
            currentTouch = touch
            
            if selectedTool == .move {
                let location = touch.location(in: self)
                print("Direct touch location: \(location)")
                onMove?(location)
            } else {
                processTouches(touches, with: event)
            }
        }
        
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            // Keep track of continuous touch
            if currentTouch != nil, let updatedTouch = touches.first { // Changed condition
                currentTouch = updatedTouch
            }

            if selectedTool == .move, let touch = touches.first {
                let location = touch.location(in: self)
                onMove?(location)
            } else {
                processTouches(touches, with: event)
            }
        }
        
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            print("TouchDetectionView - touchesEnded - tool: \(selectedTool)")
            
            // Clear the current touch
            currentTouch = nil
            
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
            print("TouchDetectionView - touchesCancelled - tool: \(selectedTool)")
            
            // Clear the current touch
            currentTouch = nil
            
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
            guard let touch = touches.first, let event = event else { return }
            
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
            
            // Process main touch and coalesced touches for smoother drawing
            var locations: [CGPoint] = []
            
            // Get all touches associated with the main touch for this event
            let allTouches = event.coalescedTouches(for: touch) ?? [touch]

            for t in allTouches {
                // Use precise location if available (for Apple Pencil)
                if #available(iOS 13.4, *), t.type == .pencil {
                    locations.append(t.preciseLocation(in: self))
                } else {
                    locations.append(t.location(in: self))
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

// Helper View Extension for conditional modifiers
extension View {
    /// Applies the given transform if the condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// Add Animation data structures
enum PlaybackState {
    case stopped
    case playing
}

// Add these path helper functions inside WhiteboardView
extension WhiteboardView {
    private func calculatePathLength(points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        var totalDistance: CGFloat = 0
        for i in 0..<(points.count - 1) {
            totalDistance += points[i].distance(to: points[i+1])
        }
        return totalDistance
    }

    private func getPointOnPath(points: [CGPoint], progress: CGFloat) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        guard progress >= 0 && progress <= 1 else { return points.last } // Return last point if progress is out of bounds

        let totalLength = calculatePathLength(points: points)
        guard totalLength > 0 else { return points.first } // Return first point if path has no length

        let targetDistance = totalLength * progress
        var distanceCovered: CGFloat = 0

        // Handle edge case: progress is 0
        if progress == 0 {
            return points.first
        }

        for i in 0..<(points.count - 1) {
            let startPoint = points[i]
            let endPoint = points[i+1]
            let segmentLength = startPoint.distance(to: endPoint)

            if distanceCovered + segmentLength >= targetDistance {
                // The target point is on this segment
                let remainingDistance = targetDistance - distanceCovered
                let segmentProgress = remainingDistance / segmentLength
                return startPoint.interpolated(to: endPoint, t: segmentProgress)
            }
            distanceCovered += segmentLength
        }

        // Should ideally not be reached if progress <= 1, but return last point as fallback
        return points.last
    }
}


