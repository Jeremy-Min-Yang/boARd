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
    @Binding var isPathAssignmentMode: Bool
    @Binding var selectedDrawingId: UUID?
    
    var body: some View {
        Canvas { context, size in
            // Draw all existing drawings
            for drawing in drawings {
                let path = drawing.path
                
                // Determine drawing color
                var drawingColor = drawing.color
                
                // Highlight selected path when in assignment mode
                if isPathAssignmentMode && selectedDrawingId == drawing.id {
                    // Selected path in assignment mode gets highlighted in green
                    drawingColor = .green
                }
                // All other paths use their default color (black)
                
                if drawing.type == .arrow {
                    // Draw the arrow
                    if drawing.points.count >= 5 {
                        let lastPoint = drawing.points.last!
                        let firstPoint = drawing.points.first!
                        let arrowPath = createArrowPath(from: firstPoint, to: lastPoint)
                        context.stroke(arrowPath, with: .color(drawingColor), lineWidth: drawing.lineWidth)
                    }
                } else {
                    // Draw pen strokes
                    context.stroke(
                        path,
                        with: .color(drawingColor),
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
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onEnded { value in
                    // Only handle taps in path assignment mode
                    if isPathAssignmentMode {
                        let location = value.location
                        handlePathSelection(at: location)
                    }
                }
        )
    }
    
    private func handlePathSelection(at location: CGPoint) {
        // Only proceed if we have drawings
        guard !drawings.isEmpty else { return }
        
        print("Tap location: \(location)")
        
        // Check if any drawing was tapped
        var tappedDrawingId: UUID? = nil
        var closestDistance: CGFloat = 20 // Maximum distance to consider a hit
        
        // Check each drawing to see if it was tapped
        for drawing in drawings {
            for point in drawing.points {
                let distance = hypot(location.x - point.x, location.y - point.y)
                
                if distance < closestDistance {
                    closestDistance = distance
                    tappedDrawingId = drawing.id
                }
            }
        }
        
        if let tappedId = tappedDrawingId {
            // A drawing was tapped
            selectedDrawingId = tappedId
            print("Selected path by tap: \(tappedId)")
        } else if selectedDrawingId == nil && !drawings.isEmpty {
            // No drawing tapped and none selected, select the first one
            selectedDrawingId = drawings[0].id
            print("No path tapped, defaulting to first: \(drawings[0].id)")
        } else {
            // No drawing tapped but one is selected, cycle to next
            if let currentIndex = drawings.firstIndex(where: { $0.id == selectedDrawingId }) {
                let nextIndex = (currentIndex + 1) % drawings.count
                selectedDrawingId = drawings[nextIndex].id
                print("Cycling to next path: \(drawings[nextIndex].id)")
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
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                // Only move if we're using the move tool
                                if selectedTool == .move {
                                    // Set the index and directly update position with the current location
                                    draggedBasketballIndex = index
                                    basketballs[index].position = value.location
                                }
                            }
                            .onEnded { value in
                                if selectedTool == .move, let index = draggedBasketballIndex {
                                    // Update normalized position
                                    let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
                                    let normalizedX = value.location.x / boundary.width
                                    let normalizedY = value.location.y / boundary.height
                                    basketballs[index].normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
                                }
                                draggedBasketballIndex = nil
                            }
                    )
            }
        }
    }
}

// Create a component for players display
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
                    // Visual indicator for assigned paths - now using a consistent color
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 54, height: 54)
                        .opacity(player.assignedPathId != nil ? 1 : 0)
                    
                    // The actual player view
                    PlayerCircleView(position: player.position, number: player.number, color: playerColor)
                }
                .position(player.position)
                .contentShape(Circle().size(CGSize(width: 60, height: 60))) // Larger hit area
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            // Only move if we're using the move tool and not in assignment mode
                            if selectedTool == .move && !isPathAssignmentMode {
                                // Set the index and directly update position with the current location
                                draggedPlayerIndex = index
                                players[index].position = value.location
                            }
                        }
                        .onEnded { value in
                            if selectedTool == .move && !isPathAssignmentMode, let index = draggedPlayerIndex {
                                // Update normalized position
                                let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
                                let normalizedX = value.location.x / boundary.width
                                let normalizedY = value.location.y / boundary.height
                                players[index].normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
                            }
                            draggedPlayerIndex = nil
                        }
                )
                .onTapGesture {
                    print("Player \(index) tapped, assignment mode: \(isPathAssignmentMode), selected path: \(String(describing: selectedDrawingId))")
                    
                    // Handle path assignment
                    if isPathAssignmentMode, let drawingId = selectedDrawingId {
                        print("Assigning path \(drawingId) to player \(index)")
                        onAssignPath(drawingId, index)
                    }
                }
            }
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
    @State private var showClearConfirmation = false
    
    // Animation/Playback state
    @State private var playbackState: PlaybackState = .stopped
    @State private var isPathAssignmentMode: Bool = false
    @State private var selectedDrawingId: UUID?
    @State private var animationSpeed: Double = 2.0  // Animation speed (seconds)
    @State private var animationPaths: [AnimationPath] = []
    @State private var originalPlayerPositions: [CGPoint] = []  // To reset after animation
    @State private var originalBasketballPositions: [CGPoint] = []  // To reset after animation
    
    // Add this new state variable to track all actions
    @State private var actions: [Action] = []
    
    // Add this new state variable to track the previous tool
    @State private var previousTool: DrawingTool?
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Toolbar stays the same
                ToolbarView(
                    selectedTool: $selectedTool,
                    selectedPenStyle: $selectedPenStyle,
                    playbackState: $playbackState,
                    isPathAssignmentMode: $isPathAssignmentMode,
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
            
            // Path assignment mode overlay
            if isPathAssignmentMode {
                pathAssignmentOverlay()
            }
            
            // Add player mode overlay
            if isAddingPlayer {
                addPlayerOverlay()
            }
            
            // Add basketball mode overlay
            if isAddingBasketball {
                addBasketballOverlay()
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
                // No frame or offset here - it inherits from parent ZStack

                // Touch detection - Sized to match drawing area
                TouchTypeDetectionView(
                    onTouchesChanged: { touchType, locations in
                        handleTouchChanged(touchType: touchType, locations: locations)
                    },
                    onTouchesEnded: { touchType in
                        handleTouchEnded(touchType: touchType)
                    }
                )
                // Disable hit testing when move tool is selected to allow dragging underneath
                .allowsHitTesting(selectedTool != .move)
                // No frame or offset here

                // Basketballs - Positioned within this ZStack's coordinate space
                BasketballsView(
                    courtType: courtType,
                    basketballs: $basketballs,
                    draggedBasketballIndex: $draggedBasketballIndex,
                    currentTouchType: $currentTouchType,
                    selectedTool: $selectedTool
                )
                .zIndex(selectedTool == .move ? 1 : 0) // Higher z-index when in move mode
                // No frame or offset here

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
                .zIndex(selectedTool == .move ? 1 : 0) // Higher z-index when in move mode
                // No frame or offset here

                // Pencil indicator - Positioned within this ZStack's coordinate space
                if showPencilIndicator {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .position(lastTouchLocation) // lastTouchLocation should be relative to this ZStack
                        .allowsHitTesting(false) // Don't let indicator block touches
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
                                    // Check if any player was tapped
                                    for (index, player) in players.enumerated() {
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
                                }
                        )
                        .zIndex(100) // Ensure this is on top
                }
            }
            .frame(width: drawingWidth, height: drawingHeight) // Apply frame to inner ZStack
            .offset(x: drawingOffsetX, y: drawingOffsetY) // Apply offset to inner ZStack
            .clipped() // Prevent drawing outside the bounds
            .contentShape(Rectangle()) // Define hit area for gestures if needed directly on ZStack
            
        }
        .frame(width: containerWidth, height: containerHeight) // Outer frame remains
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
            
            // Show assigned path count in the middle of the screen
            if animationPaths.count > 0 {
                Text("\(animationPaths.count) paths assigned")
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
    private func addPlayerOverlay() -> some View {
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
                .border(Color.red, width: 2) // Optional: keep border for debugging
                .gesture(
                    // Use DragGesture with minimal distance to detect taps
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            // Get the tap location relative to this view (which is the inner ZStack)
                            let tapPosition = value.location
                            addPlayerAt(position: tapPosition)
                            isAddingPlayer = false
                        }
                )
        }
    }
    
    // Add basketball overlay
    @ViewBuilder
    private func addBasketballOverlay() -> some View {
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
            
            // Gesture capturing area (fills the parent - the inner ZStack)
            Color.clear
                .contentShape(Rectangle()) // Makes the clear color tappable
                .border(Color.blue, width: 2) // Optional: keep border for debugging
                .gesture(
                    // Use DragGesture with minimal distance to detect taps
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            // Get the tap location relative to this view (which is the inner ZStack)
                            let tapPosition = value.location
                            addBasketballAt(position: tapPosition)
                            isAddingBasketball = false
                        }
                )
        }
    }
    
    private func handleTouchChanged(touchType: TouchInputType, locations: [CGPoint]) {
        // Update current touch type
        currentTouchType = touchType
        
        // If it's a pencil, show the indicator
        showPencilIndicator = (touchType == .pencil)
        
        // If we're in drawing mode with a pencil, and not currently dragging something, handle drawing
        if touchType == .pencil && 
           (selectedTool == .pen || selectedTool == .arrow) && 
           draggedPlayerIndex == nil && 
           draggedBasketballIndex == nil &&
           !isPathAssignmentMode { // Prevent drawing in path assignment mode
            // Process each location received (includes coalesced touches)
            for location in locations {
                if currentDrawing == nil {
                    // Start a new drawing with the first point
                    self.startNewDrawing(at: location)
                } else {
                    // Continue existing drawing with subsequent points
                    self.continueDrawing(at: location)
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
    }
    
    private func addPlayerAt(position: CGPoint) {
        // Check if we've reached the player limit
        if players.count >= 5 {
            showPlayerLimitAlert = true
            return
        }
        
        // Get the boundary for normalization
        let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
        
        // The 'position' received is already relative to the overlay, which matches the drawing area.
        // No need to call adjustTouchLocation. Use the position directly.
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
        
        // The 'position' received is already relative to the overlay, which matches the drawing area.
        // No need to call adjustTouchLocation. Use the position directly.
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
        isPathAssignmentMode.toggle()
        selectedDrawingId = nil // Reset selection
        
        // Automatically switch to move tool when entering path assignment mode
        // This prevents drawing while assigning paths
        if isPathAssignmentMode {
            // Store the previous tool to restore later
            previousTool = selectedTool
            selectedTool = .move
        } else {
            // Restore previous tool when exiting assignment mode
            if let prevTool = previousTool {
                selectedTool = prevTool
            }
        }
    }
    
    private func assignPathToPlayer(drawingId: UUID, playerIndex: Int) {
        print("ASSIGNING PATH: \(drawingId) to player \(playerIndex)")
        
        // Ensure player index is valid
        guard playerIndex >= 0 && playerIndex < players.count else {
            print("Invalid player index: \(playerIndex)")
            return
        }
        
        // Associate the drawing with the player
        players[playerIndex].assignedPathId = drawingId
        
        // Mark the drawing as assigned
        if let index = drawings.firstIndex(where: { $0.id == drawingId }) {
            drawings[index].isAssignedToPlayer = true
            
            // Create animation path
            let animationPath = AnimationPath(
                drawingId: drawingId,
                playerIndex: playerIndex,
                path: drawings[index].points
            )
            
            print("Created animation path with \(animationPath.path.count) points")
            
            // Add or update animation path
            if let existingIndex = animationPaths.firstIndex(where: { $0.playerIndex == playerIndex }) {
                animationPaths[existingIndex] = animationPath
                print("Updated existing animation path for player \(playerIndex)")
            } else {
                animationPaths.append(animationPath)
                print("Added new animation path for player \(playerIndex)")
            }
        } else {
            print("Could not find drawing with ID: \(drawingId)")
        }
        
        // Reset selection but STAY in path assignment mode
        selectedDrawingId = nil
        
        print("Path assigned to Player \(playerIndex+1). Select another path or exit assignment mode when done.")
    }
    
    private func startAnimation() {
        // If no paths assigned, do nothing
        if animationPaths.isEmpty {
            print("No animation paths to play")
            return
        }
        
        print("Starting animation with \(animationPaths.count) paths")
        
        // Store original positions for reset
        originalPlayerPositions = players.map { $0.position }
        originalBasketballPositions = basketballs.map { $0.position }
        
        // Set playback state
        playbackState = .playing
        
        // Animate each player along their assigned path
        for animPath in animationPaths {
            print("Animating player \(animPath.playerIndex) along path with \(animPath.path.count) points")
            animatePlayer(at: animPath.playerIndex, along: animPath.path)
        }
    }
    
    private func animatePlayer(at index: Int, along path: [CGPoint]) {
        guard index < players.count, !path.isEmpty else {
            print("Invalid player index or empty path")
            return
        }
        
        // Only animate if points are sufficient
        if path.count < 2 {
            print("Path has too few points to animate")
            return
        }
        
        // Get the start position
        let startPosition = path.first!
        players[index].position = startPosition
        
        // Animate through the path
        let totalDuration = animationSpeed
        let pointCount = path.count
        
        // Animate through each segment with smoother animation
        DispatchQueue.main.async {
            // Use withAnimation for the entire sequence
            withAnimation(.linear(duration: totalDuration)) {
                // Create a sequence of animations
                var delay: Double = 0
                
                for i in 1..<path.count {
                    let segmentDuration = totalDuration / Double(pointCount - 1)
                    
                    // Schedule each position update
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
                        guard playbackState == .playing else { return }
                        
                        // Update the position
                        players[index].position = path[i]
                        
                        // Check if this is the last segment and the last player
                        if i == path.count - 1 {
                            // Check if all animations are complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
                                guard playbackState == .playing else { return }
                                
                                // Check if this was the last player to finish
                                let allPlayersComplete = true // This will need more logic if animations have different durations
                                
                                if allPlayersComplete {
                                    print("All animations completed")
                                    playbackState = .stopped
                                }
                            }
                        }
                    }
                    
                    delay += segmentDuration
                }
            }
        }
    }
    
    private func stopAnimation() {
        print("Stopping animation")
        
        // Change state immediately to cancel ongoing animations
        playbackState = .stopped
        
        // Reset to original positions
        if !originalPlayerPositions.isEmpty {
            for i in 0..<min(players.count, originalPlayerPositions.count) {
                players[i].position = originalPlayerPositions[i]
            }
        }
        
        if !originalBasketballPositions.isEmpty {
            for i in 0..<min(basketballs.count, originalBasketballPositions.count) {
                basketballs[i].position = originalBasketballPositions[i]
            }
        }
        
        print("Animation stopped, positions reset")
    }
}

struct ToolbarView: View {
    @Binding var selectedTool: DrawingTool
    @Binding var selectedPenStyle: PenStyle
    @Binding var playbackState: PlaybackState
    @Binding var isPathAssignmentMode: Bool
    var onAddPlayer: () -> Void
    var onAddBasketball: () -> Void
    var onUndo: () -> Void
    var onClear: () -> Void
    var onPlayAnimation: () -> Void
    var onStopAnimation: () -> Void
    var onAssignPath: () -> Void
    
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
                    
                    // Animation controls
                    Button(action: onAssignPath) {
                        Image(systemName: "arrow.triangle.pull")
                            .font(.title3)
                            .foregroundColor(isPathAssignmentMode ? .blue : .gray)
                            .frame(width: 36, height: 36)
                            .background(isPathAssignmentMode ? Color.blue.opacity(0.2) : Color.clear)
                            .cornerRadius(8)
                    }
                    
                    if playbackState == .stopped {
                        Button(action: onPlayAnimation) {
                            Image(systemName: "play.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                                .frame(width: 36, height: 36)
                        }
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
    var id: UUID = UUID()  // Add unique identifier
    var path: Path
    var color: Color
    var lineWidth: CGFloat
    var type: DrawingTool
    var style: PenStyle
    var points: [CGPoint]  // Track points manually
    var normalizedPoints: [CGPoint]?  // Store normalized points for consistent representation
    var isAssignedToPlayer: Bool = false  // Track if this path is assigned to a player
}

struct PlayerCircle {
    var position: CGPoint
    var number: Int
    var color: Color = .blue  // Fixed color instead of computed property
    var normalizedPosition: CGPoint?
    var assignedPathId: UUID?  // Reference to drawing that this player should follow
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
            print("TouchDetectionView - touchesBegan")
            processTouches(touches, with: event)
        }
        
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            print("TouchDetectionView - touchesMoved")
            processTouches(touches, with: event)
        }
        
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            print("TouchDetectionView - touchesEnded")
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
            print("TouchDetectionView - touchesCancelled")
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
            // print("TouchDetectionView - processTouches") // Let's comment this one out for now to reduce noise, uncomment if needed
            guard let touch = touches.first, let event = event else { return } // Ensure event is not nil
            
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
            
            // Debug log for touch locations
            print("Touch locations: \(locations)")
            
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

struct AnimationPath {
    let drawingId: UUID
    let playerIndex: Int
    let path: [CGPoint]  // Points to follow
} 
