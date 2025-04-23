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
    case opponent(PlayerCircle) // New: Opponent action
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
                    .onLongPressGesture {
                        draggedBasketballIndex = index
                    }
                    .overlay(
                        Group {
                            if draggedBasketballIndex == index {
                                Circle().stroke(Color.orange, lineWidth: 4).frame(width: 48, height: 48)
                            }
                        }
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
                    if isAssigningBasketballToPlayer, let bIndex = basketballToAssignIndex {
                        let event = BasketballPossessionEvent(playerId: player.id, time: animationProgress)
                        basketballs[bIndex].possessionTimeline.append(event)
                        isAssigningBasketballToPlayer = false
                        basketballToAssignIndex = nil
                    } else if isPathAssignmentMode, let drawingId = selectedDrawingId {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onAssignPath(drawingId, index)
                        }
                    }
                }
                .overlay(
                    Group {
                        if isAssigningBasketballToPlayer, let bIndex = basketballToAssignIndex, basketballs[bIndex].possessionTimeline.contains(where: { $0.playerId == player.id }) {
                            Circle().stroke(Color.orange, lineWidth: 4).frame(width: 56, height: 56)
                        }
                    }
                )
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
    var playToLoad: SavedPlay? = nil
    var isEditable: Bool = true // Default to true (for new plays)
    
    // Add this init method
    init(courtType: CourtType, playToLoad: SavedPlay? = nil, isEditable: Bool = true) {
        self.courtType = courtType
        self.playToLoad = playToLoad
        self.isEditable = isEditable

        // Configure Navigation Bar Appearance to remove shadow/hairline
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground() // Use opaque as base
        // Set background and shadow to clear to hide the default bar and its line
        appearance.backgroundColor = .clear 
        appearance.shadowColor = .clear 

        // Apply the appearance globally (can be scoped later if needed)
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    @State private var selectedTool: DrawingTool = .pen
    @State private var selectedPenStyle: PenStyle = .normal
    @State private var drawings: [Drawing] = []
    @State private var currentDrawing: Drawing?
    @State private var players: [PlayerCircle] = []
    @State private var opponents: [PlayerCircle] = [] // New: Opponents array
    @State private var basketballs: [BasketballItem] = []
    @State private var draggedPlayerIndex: Int?
    @State private var draggedBasketballIndex: Int?
    @State private var isAddingPlayer = false
    @State private var isAddingOpponent = false // New: Add opponent mode
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

    // State variables for save alert
    @State private var showingSaveAlert = false
    @State private var playNameInput = ""
    
    // Computed property to count assigned paths
    private var pathConnectionCount: Int {
        return players.filter { $0.assignedPathId != nil }.count
    }

    @State private var animationProgress: Double = 0.0 // Timeline progress (0.0 to 1.0)
    
    // Add computed properties for total animation time and current time
    private var totalAnimationTime: Double {
        playerAnimationData.values.map { $0.duration }.max() ?? 0.0
    }
    private var currentAnimationTime: Double {
        animationProgress * totalAnimationTime
    }
    private func formatTime(_ seconds: Double) -> String {
        let intSec = Int(seconds.rounded())
        let min = intSec / 60
        let sec = intSec % 60
        return String(format: "%d:%02d", min, sec)
    }

    @State private var isAssigningBasketballToPlayer = false
    @State private var basketballToAssignIndex: Int? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    // Main content area (court)
                    courtContentView(geometry: geometry)
                        .padding(.top, 0)
                    // Timeline slider below the court
                    if playbackState != .stopped || pathConnectionCount > 0 {
                        ZStack(alignment: .center) {
                            HStack {
                                Text(formatTime(currentAnimationTime)).font(.caption).frame(width: 40, alignment: .trailing)
                                Slider(value: $animationProgress, in: 0...1, step: 0.001) {
                                    Text("Timeline")
                                } onEditingChanged: { editing in
                                    if !editing {
                                        updatePositionsForProgress(animationProgress)
                                    }
                                }
                                .disabled(playbackState == .playing)
                                Text(formatTime(totalAnimationTime)).font(.caption).frame(width: 40, alignment: .leading)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                            // Overlay pass event dots
                            GeometryReader { geo in
                                ForEach(basketballs.indices, id: \ .self) { bIndex in
                                    ForEach(basketballs[bIndex].possessionTimeline, id: \ .time) { event in
                                        let sliderWidth = geo.size.width - 80 // 40 left + 40 right padding for time labels
                                        let x = CGFloat(event.time) * sliderWidth + 40
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 8, height: 8)
                                            .position(x: x, y: geo.size.height / 2)
                                    }
                                }
                            }
                            .allowsHitTesting(false)
                        }
                    }
                    // Toolbar VStack on bottom
                    ToolbarView(
                        selectedTool: $selectedTool,
                        selectedPenStyle: $selectedPenStyle,
                        playbackState: $playbackState,
                        isPathAssignmentMode: $isPathAssignmentMode,
                        pathCount: pathConnectionCount,
                        isEditable: isEditable, // Pass the isEditable state
                        onAddPlayer: {
                            isAddingPlayer = true
                            isAddingOpponent = false
                            isAddingBasketball = false
                        },
                        onAddOpponent: {
                            isAddingOpponent = true
                            isAddingPlayer = false
                            isAddingBasketball = false
                        },
                        onAddBasketball: {
                            isAddingBasketball = true
                            isAddingPlayer = false
                            isAddingOpponent = false
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
                                case .opponent:
                                    if !opponents.isEmpty {
                                        opponents.removeLast()
                                    }
                                }
                            }
                        },
                        onClear: {
                            showClearConfirmation = true
                        },
                        onPlayAnimation: {
                            startAnimation()
                        },
                        onPauseAnimation: {
                            pauseAnimation()
                        },
                        onAssignPath: {
                            togglePathAssignmentMode()
                        },
                        onToolChange: { tool in
                            handleToolChange(tool)
                        },
                        onSave: {
                            print("Save button tapped!")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                showingSaveAlert = true
                            }
                        }
                    )
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                }
                .ignoresSafeArea(edges: .bottom)
                .onChange(of: animationProgress) { newValue in
                    updatePositionsForProgress(newValue)
                }

                if isAssigningBasketballToPlayer {
                    VStack {
                        Spacer()
                        Text("Tap a player to assign the basketball")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                        Spacer()
                    }
                    .background(Color.black.opacity(0.3).edgesIgnoringSafeArea(.all))
                    .zIndex(200)
                }
            }
            .navigationTitle(courtType == .full ? "Full Court" : "Half Court")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Load play data if provided
            if let play = playToLoad {
                loadPlayData(play)
            }
        }
    }

    // ... existing code ...
    // Add helper to update positions for a given progress
    private func updatePositionsForProgress(_ progress: Double) {
        for (playerId, animData) in playerAnimationData {
            if let playerIndex = players.firstIndex(where: { $0.id == playerId }) {
                if let pos = getPointOnPath(points: animData.pathPoints, progress: progress) {
                    players[playerIndex].position = pos
                }
            }
        }
        // Basketball follows the correct player based on possession timeline
        for i in basketballs.indices {
            let timeline = basketballs[i].possessionTimeline.sorted { $0.time < $1.time }
            if let event = timeline.last(where: { $0.time <= progress }),
               let player = players.first(where: { $0.id == event.playerId }) {
                basketballs[i].position = player.position
            }
        }
    }
    // ... existing code ...
}

struct ToolbarView: View {
    @Binding var selectedTool: DrawingTool
    @Binding var selectedPenStyle: PenStyle
    @Binding var playbackState: PlaybackState
    @Binding var isPathAssignmentMode: Bool
    let pathCount: Int
    // Add isEditable property
    let isEditable: Bool
    let onAddPlayer: () -> Void
    let onAddOpponent: () -> Void
    let onAddBasketball: () -> Void
    let onUndo: () -> Void
    let onClear: () -> Void
    let onPlayAnimation: () -> Void
    let onPauseAnimation: () -> Void // Renamed from onStopAnimation
    let onAssignPath: () -> Void
    let onToolChange: (DrawingTool) -> Void
    // Add the new save action closure
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 20) { 
            if isEditable {
                // MARK: - Editable Mode Buttons
                // Disable drawing/editing tools in view mode (These are inside the if now)
                ToolButton(icon: "pencil.tip", selectedTool: $selectedTool, currentTool: .pen, action: { onToolChange(.pen) })
                ToolButton(icon: "arrow.right", selectedTool: $selectedTool, currentTool: .arrow, action: { onToolChange(.arrow) })
                ToolButton(icon: "hand.point.up.left", selectedTool: $selectedTool, currentTool: .move, action: { onToolChange(.move) })
                // Add buttons
                Button(action: onAddPlayer) {
                    Image(systemName: "plus.circle")
                        .font(.title2).frame(width: 44, height: 44).foregroundColor(.green)
                }
                Button(action: onAddOpponent) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.title2).frame(width: 44, height: 44).foregroundColor(.red)
                }
                Button(action: onAddBasketball) {
                    Image(systemName: "basketball.fill")
                        .font(.title2).frame(width: 44, height: 44).foregroundColor(.orange)
                }

                Spacer() // Spacer 1 (Editable Mode)

                // Path assignment button (Only shown when editable)
                Button(action: onAssignPath) {
                    HStack {
                        Image(systemName: isPathAssignmentMode ? "arrow.triangle.pull.fill" : "arrow.triangle.pull")
                        Text("\(pathCount)")
                    }
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .background(isPathAssignmentMode ? Color.blue.opacity(0.7) : Color.gray.opacity(0.2))
                    .foregroundColor(isPathAssignmentMode ? .white : .primary)
                    .cornerRadius(8)
                }
                .padding(.trailing, 8)
                
                // Play/Pause also shown in Editable mode here
                playbackControls // Extracted ViewBuilder
                
                Spacer() // Spacer 2 (Editable Mode)

                // Undo/Clear/Save buttons (Only shown when editable)
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title2).frame(width: 44, height: 44)
                }
                Button(action: onClear) {
                    Image(systemName: "trash")
                        .font(.title2).frame(width: 44, height: 44).foregroundColor(.red)
                }
                Button(action: onSave) { 
                    Image(systemName: "square.and.arrow.down")
                        .font(.title2).frame(width: 44, height: 44)
                }
                
            } else {
                // MARK: - View Mode Buttons (Only Playback)
                Spacer() // Center the playback controls
                
                playbackControls // Extracted ViewBuilder
                
                Spacer() // Center the playback controls
            }
        }
        .padding() // Restore default padding inside ToolbarView
        .frame(height: 50) // Give toolbar a consistent height
    }
    
    // Extracted ViewBuilder for playback controls
    @ViewBuilder
    private var playbackControls: some View {
        if playbackState == .playing {
            Button(action: onPauseAnimation) { 
                Image(systemName: "pause.fill") 
                    .font(.title2).frame(width: 44, height: 44) // Ensure size consistency
                    .foregroundColor(.red) 
            }
        } else {
            Button(action: onPlayAnimation) { 
                Image(systemName: "play.fill")
                    .font(.title2).frame(width: 44, height: 44) // Ensure size consistency
                    .foregroundColor(.green)
            }
        }
    }
}

// Define the ToolButton struct here
struct ToolButton: View {
    let icon: String
    @Binding var selectedTool: DrawingTool
    let currentTool: DrawingTool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2) // Increase icon font size
                .foregroundColor(selectedTool == currentTool ? .blue : .gray)
                .frame(width: 44, height: 44) // Increase frame size
                .background(selectedTool == currentTool ? Color.blue.opacity(0.2) : Color.clear)
                .cornerRadius(8)
        }
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
    enum PlayerType { case player, opponent }
    var id = UUID()
    var position: CGPoint
    var number: Int
    var type: PlayerType = .player
    var color: Color { type == .player ? .blue : .red }
    var normalizedPosition: CGPoint?
    var assignedPathId: UUID?
    var isMoving: Bool = false
}

struct BasketballPossessionEvent {
    var playerId: UUID
    var time: Double // 0.0 ... 1.0 (timeline progress)
}

struct BasketballItem {
    var position: CGPoint
    var normalizedPosition: CGPoint?
    var assignedPathId: UUID?  // Reference to drawing that basketball should follow
    var possessionTimeline: [BasketballPossessionEvent] = [] // New: timeline of possession
}

enum DrawingTool: String, CaseIterable {
    case pen
    case arrow
    case move
    // Add the new cases
    case addPlayer
    case addBasketball

    var iconName: String {
        switch self {
        case .pen: return "pencil"
        case .arrow: return "arrow.up.right"
        case .move: return "hand.point.up.left.fill"
        // Add icons for the new cases
        case .addPlayer: return "person.fill.badge.plus"
        case .addBasketball: return "basketball.fill"
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
    case paused // Add paused state
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

    private func updateAnimations(timer: Timer) {
        let currentTime = Date()
        var allAnimationsComplete = true
        var maxProgress: Double = 0.0
        for (playerId, animData) in playerAnimationData {
            let elapsedTime = currentTime.timeIntervalSince(animData.startTime)
            var progress = elapsedTime / animData.duration
            progress = max(0, min(1, progress))
            if progress > maxProgress { maxProgress = progress }
            if let playerIndex = players.firstIndex(where: { $0.id == playerId }) {
                if let newPosition = getPointOnPath(points: animData.pathPoints, progress: progress) {
                    players[playerIndex].position = newPosition
                    players[playerIndex].isMoving = progress < 1.0
                }
            }
            if progress < 1.0 { allAnimationsComplete = false }
        }
        animationProgress = maxProgress
        if allAnimationsComplete {
            completeAnimation()
        }
    }

    private func startAnimation() {
        animationProgress = 0.0 // Reset progress on start
        // ... existing code ...
    }

    private func completeAnimation() {
        animationProgress = 1.0 // Snap to end
        // ... existing code ...
    }

    private func pauseAnimation() {
        // ... existing code ...
        // animationProgress is not changed here
        // ... existing code ...
    }

    // ... existing code ...
}

struct WhiteboardView_Previews: PreviewProvider {
    static var previews: some View {
        WhiteboardView(courtType: .full)
    }
}

// Add OpponentsView implementation
struct OpponentsView: View {
    let courtType: CourtType
    @Binding var opponents: [PlayerCircle]
    @Binding var draggedOpponentIndex: Int?
    @Binding var currentTouchType: TouchInputType
    @Binding var selectedTool: DrawingTool
    var body: some View {
        ZStack {
            ForEach(opponents.indices, id: \ .self) { index in
                let opponent = opponents[index]
                PlayerCircleView(
                    position: opponent.position,
                    number: opponent.number,
                    color: opponent.color,
                    isMoving: opponent.isMoving
                )
                .position(opponent.position)
                .zIndex(opponent.isMoving ? 20 : 1)
            }
        }
    }
}


