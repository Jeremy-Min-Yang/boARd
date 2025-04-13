import SwiftUI
import PDFKit
import UIKit

// Enum definition for CourtType

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
    
    // New state variables for save functionality
    @State private var showSaveDialog = false
    @State private var playName = ""
    @State private var showSaveSuccessToast = false
    @State private var editingPlayId: UUID? // Set when editing an existing play
    
    // Environment to access presentation mode
    @Environment(\.presentationMode) var presentationMode
    
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
                        },
                        // Add new save button handler
                        onSave: {
                            showSaveDialog = true
                        }
                    )
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                }
                
                // Success toast notification
                if showSaveSuccessToast {
                    VStack {
                        Text("Play saved successfully!")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green.opacity(0.8))
                            .cornerRadius(10)
                            .shadow(radius: 3)
                            .padding(.top, 100)
                        Spacer()
                    }
                    .transition(.move(edge: .top))
                    .zIndex(1000)
                    .onAppear {
                        // Auto-dismiss the toast after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showSaveSuccessToast = false
                            }
                        }
                    }
                }
                
                // Remove the persistent path counter here
            }
            .navigationTitle(courtType == .full ? "Full Court" : "Half Court")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: 
                Button(action: {
                    showSaveDialog = true
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .imageScale(.large)
                }
            )
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
            // Add save dialog
            .sheet(isPresented: $showSaveDialog) {
                savePlayDialog()
            }
            .ignoresSafeArea(edges: .bottom) // Ensure content can use the full screen
        }
    }
    
    // Save Play Dialog
    private func savePlayDialog() -> some View {
        NavigationView {
            Form {
                Section(header: Text("Play Details")) {
                    TextField("Play Name", text: $playName)
                        .disableAutocorrection(true)
                }
                
                Section {
                    Button(action: savePlay) {
                        HStack {
                            Spacer()
                            Text(editingPlayId == nil ? "Save Play" : "Update Play")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .disabled(playName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(editingPlayId == nil ? "Save Play" : "Update Play")
            .navigationBarItems(leading: Button("Cancel") {
                showSaveDialog = false
                playName = ""
            })
        }
    }
    
    // Save Play Function
    private func savePlay() {
        // Create drawing data from the current state
        let drawingsData = drawings.map { SavedPlayService.convertToDrawingData(drawing: $0) }
        let playersData = players.map { SavedPlayService.convertToPlayerData(player: $0) }
        let basketballsData = basketballs.map { SavedPlayService.convertToBasketballData(basketball: $0) }
        
        // Create the saved play model
        let play = SavedPlay(
            id: editingPlayId ?? UUID(),
            name: playName,
            dateCreated: Date(),
            lastModified: Date(),
            courtType: courtType == .full ? "full" : "half",
            drawings: drawingsData,
            players: playersData,
            basketballs: basketballsData
        )
        
        // Save the play
        SavedPlayService.shared.savePlay(play)
        
        // Close the dialog and show success message
        showSaveDialog = false
        playName = ""
        
        // Show success toast
        withAnimation {
            showSaveSuccessToast = true
        }
        
        // Auto-dismiss the toast after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaveSuccessToast = false
            }
            
            // Optionally navigate back to home screen after saving
            // Uncomment if you want this behavior:
            // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            //     presentationMode.wrappedValue.dismiss()
            // }
        }
    }
    
    // Load Play Function (for when editing existing plays)
    func loadPlay(play: SavedPlay) {
        // Clear current state
        drawings.removeAll()
        players.removeAll()
        basketballs.removeAll()
        actions.removeAll()
        
        // Set editingPlayId
        editingPlayId = play.id
        playName = play.name
        
        // Load players
        play.players.forEach { playerData in
            players.append(SavedPlayService.convertToPlayer(playerData: playerData))
        }
        
        // Load basketballs
        play.basketballs.forEach { basketballData in
            basketballs.append(SavedPlayService.convertToBasketball(basketballData: basketballData))
        }
        
        // Load drawings (after players, so path assignments can be linked)
        play.drawings.forEach { drawingData in
            drawings.append(SavedPlayService.convertToDrawing(drawingData: drawingData))
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
    var onToolChange: (DrawingTool) -> Void
    var onSave: () -> Void
    
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
                    
                    // Save button
                    Button(action: onSave) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title3)
                            .foregroundColor(.blue)
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