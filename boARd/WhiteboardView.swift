import SwiftUI
import PDFKit
import UIKit


// Now modify the main WhiteboardView to use these components
struct WhiteboardView: View {
    let courtType: CourtType
    var playToLoad: Models.SavedPlay? = nil
    var isEditable: Bool = true // Default to true (for new plays)
    
    // Add this init method
    init(courtType: CourtType, playToLoad: Models.SavedPlay? = nil, isEditable: Bool = true) {
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
    @State private var basketballs: [BasketballItem] = []
    @State private var opponents: [OpponentCircle] = []
    @State private var draggedPlayerIndex: Int?
    @State private var draggedBasketballIndex: Int?
    @State private var draggedOpponentIndex: Int?
    @State private var isAddingPlayer = false
    @State private var isAddingBasketball = false
    @State private var isAddingOpponent = false
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

    // In WhiteboardView, add a new @State for timeline progress
    @State private var playbackProgress: Double = 0.0
    
    // Helper to get the max animation duration
    private var maxAnimationDuration: TimeInterval {
        playerAnimationData.values.map { $0.duration }.max() ?? 0
    }
    
    @State private var indicatorPhase: Double = 0.0
    @State private var indicatorTimer: Timer? = nil
    
    @State private var isDirty: Bool = false
    
    // Add state for Save As dialog
    @State private var showingSaveAsAlert = false
    
    @Environment(\.presentationMode) var presentationMode
    @State private var showExitAlert = false
    @State private var showSaveErrorAlert = false
    @State private var saveErrorMessage = ""
    @State private var autoSaveTimer: Timer? = nil
    @State private var showDraftRecoveryAlert = false
    
    // --- Auto-Save/Drafts ---
    private var draftKey: String {
        if let play = playToLoad {
            return "draft_whiteboard_\(play.id)"
        } else {
            return "draft_whiteboard_new"
        }
    }

    // Add state for assign ball mode
    @State private var isAssigningBall = false
    @State private var selectedBasketballIndex: Int? = nil

    var body: some View {
        GeometryReader { geometry in
            if !isEditable {
                if pathConnectionCount > 0 {
                    VStack(spacing: 0) {
                        // Playback controls and court content
                        HStack(spacing: 12) {
                            Button(action: {
                                if playbackState == .playing {
                                    pauseAnimation()
                                } else {
                                    startAnimation()
                                }
                            }) {
                                Image(systemName: playbackState == .playing ? "pause.fill" : "play.fill")
                                    .font(.title2)
                                    .foregroundColor(playbackState == .playing ? .red : .green)
                                    .frame(width: 44, height: 44)
                            }
                            Slider(value: Binding(
                                get: { playbackProgress },
                                set: { newValue in
                                    playbackProgress = newValue
                                    setAnimationProgress(newValue)
                                }
                            ), in: 0...1, step: 0.001)
                            .frame(maxWidth: 200)
                            HStack {
                                Text("0:00")
                                Text("/")
                                Text(animationDurationString())
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        courtContentView(geometry: geometry)
                            .padding(.top, 8)
                        Spacer().frame(height: 32)
                    }
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    // Show placeholder if no connected plays
                    VStack {
                        Spacer()
                        Text("No connected plays available for playback.")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                        courtContentView(geometry: geometry)
                            .padding(.top, 8)
                        Spacer()
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            } else {
                ZStack(alignment: .top) {
                    courtContentView(geometry: geometry)
                        .padding(.top, 61)
                    VStack(spacing: 0) {
                        // Save status indicator in top right above toolbar
                        HStack {
                            Spacer()
                            if isDirty {
                                Text("Unsaved changes")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                    .padding(6)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .padding(.trailing, 12)
                            } else {
                                Text("All changes saved")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .padding(6)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .padding(.trailing, 12)
                            }
                        }
                        .padding(.top, 4)
                        // Divider between nav bar and toolbar
                        Divider()
                            .background(Color(.systemGray3))
                        HStack {
                            ToolbarView(
                                selectedTool: $selectedTool,
                                selectedPenStyle: $selectedPenStyle,
                                playbackState: $playbackState,
                                isPathAssignmentMode: $isPathAssignmentMode,
                                pathCount: pathConnectionCount,
                                isEditable: isEditable,
                                onAddPlayer: {
                                    isAddingPlayer = true
                                    isAddingBasketball = false
                                    isAddingOpponent = false
                                },
                                onAddBasketball: {
                                    isAddingBasketball = true
                                    isAddingPlayer = false
                                    isAddingOpponent = false
                                },
                                onAddOpponent: {
                                    isAddingOpponent = true
                                    isAddingPlayer = false
                                    isAddingBasketball = false
                                },
                                onUndo: {
                                    if let lastAction = actions.popLast() {
                                        switch lastAction {
                                        case .drawing:
                                            if !drawings.isEmpty { drawings.removeLast() }
                                        case .basketball:
                                            if !basketballs.isEmpty { basketballs.removeLast() }
                                        case .player:
                                            if !players.isEmpty { players.removeLast() }
                                        case .opponent:
                                            if !opponents.isEmpty { opponents.removeLast() }
                                        }
                                    }
                                },
                                onClear: { showClearConfirmation = true },
                                onPlayAnimation: { startAnimation() },
                                onPauseAnimation: { pauseAnimation() },
                                onAssignPath: { togglePathAssignmentMode() },
                                onAssignBall: {
                                    if !isAssigningBall {
                                        if isPathAssignmentMode {
                                            isPathAssignmentMode = false
                                        }
                                        previousTool = selectedTool
                                        selectedTool = .move
                                        isAssigningBall = true
                                    } else {
                                        isAssigningBall = false
                                        if let prevTool = previousTool {
                                            selectedTool = prevTool
                                        }
                                    }
                                    selectedBasketballIndex = nil
                                },
                                isAssigningBall: isAssigningBall,
                                onToolChange: { tool in handleToolChange(tool) },
                                onSave: {
                                    saveCurrentPlayImmediate()
                                }
                            )
                            .padding(.vertical, 8)
                            .background(Color.white)
                            // Add Save As button next to Save
                            Button(action: {
                                print("Save As button tapped!")
                                showingSaveAsAlert = true
                            }) {
                                Image(systemName: "square.and.arrow.down.on.square")
                                    .font(.title2)
                                    .accessibilityLabel("Save As")
                            }
                            .padding(.trailing, 8)
                        }
                        Divider().background(Color(.systemGray3))
                        // Show instructions when assigning ball
                        if isAssigningBall {
                            Text("Choose a player to connect the basketball to")
                                .font(.footnote)
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle(courtType == .full ? "Full Court" : "Half Court")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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
        .alert("Clear Whiteboard?", isPresented: $showClearConfirmation) {
            Button("Clear", role: .destructive) {
                drawings.removeAll()
                players.removeAll()
                basketballs.removeAll()
                actions.removeAll()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to clear the whiteboard? This action cannot be undone.")
        }
        .sheet(isPresented: $showingSaveAlert) {
            SavePlaySheet(playNameInput: $playNameInput) {
                saveCurrentPlay()
            }
        }
        .sheet(isPresented: $showingSaveAsAlert) {
            SavePlaySheet(playNameInput: $playNameInput) {
                saveAsNewPlay()
            }
        }
        .onAppear {
            if let play = playToLoad {
                loadPlayData(play)
            }
            if playbackState == .stopped {
                startIndicatorAnimation()
            }
            // Start auto-save timer
            autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
                if isDirty {
                    saveDraft()
                }
            }
            // Check for draft on appear
            if let _ = loadDraft() {
                showDraftRecoveryAlert = true
            }
        }
        .onChange(of: playbackState) { newState in
            if newState == .stopped {
                startIndicatorAnimation()
            } else {
                stopIndicatorAnimation()
            }
        }
        .onDisappear {
            stopIndicatorAnimation()
            autoSaveTimer?.invalidate()
            autoSaveTimer = nil
        }
        .alert(isPresented: $showExitAlert) {
            Alert(
                title: Text("Unsaved Changes"),
                message: Text("You have unsaved changes. What would you like to do?"),
                primaryButton: .default(Text("Save"), action: {
                    saveCurrentPlayImmediate(onSuccess: {
                        presentationMode.wrappedValue.dismiss()
                    })
                }),
                secondaryButton: .destructive(Text("Discard"), action: {
                    presentationMode.wrappedValue.dismiss()
                })
            )
        }
        .alert(isPresented: $showSaveErrorAlert) {
            Alert(title: Text("Save Error"), message: Text(saveErrorMessage), dismissButton: .default(Text("OK")))
        }
        .alert(isPresented: $showDraftRecoveryAlert) {
            Alert(
                title: Text("Draft Found"),
                message: Text("A draft was found. Would you like to recover it?"),
                primaryButton: .default(Text("Recover"), action: {
                    if let draft = loadDraft() {
                        restoreFromDraft(draft)
                    }
                    showDraftRecoveryAlert = false
                }),
                secondaryButton: .destructive(Text("Discard"), action: {
                    deleteDraft()
                    showDraftRecoveryAlert = false
                })
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    if isDirty {
                        showExitAlert = true
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
    }
    
    // Extract content view to a separate method to reduce complexity
    @ViewBuilder
    private func courtContentView(geometry: GeometryProxy) -> some View {
        ZStack {
            // Background color
            Color.white.edgesIgnoringSafeArea(.all) // Revert background to white
            // Color.green // Temporary background for debugging
            //     .edgesIgnoringSafeArea(.all)
            
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
            
            // Path assignment mode overlay (Can be shown in view mode)
            if isPathAssignmentMode {
                pathAssignmentOverlay()
            }
            
            // Only show Add overlays if editable
            if isEditable {
                // Add player mode overlay
                if isAddingPlayer {
                    addPlayerOverlay(geometry: geometry)
                }
                
                // Add basketball mode overlay
                if isAddingBasketball {
                    addBasketballOverlay(geometry: geometry)
                }
                
                // Add opponent mode overlay
                if isAddingOpponent {
                    addOpponentOverlay(geometry: geometry)
                }
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

            // --- Indicator and DrawingLayer in the same coordinate space ---
            ZStack {
                if playbackState == .stopped {
                    ForEach(players.indices, id: \.self) { playerIndex in
                        indicatorViewForPlayer(playerIndex: playerIndex, drawingWidth: drawingWidth, drawingHeight: drawingHeight)
                    }
                }
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
                .zIndex(isPathAssignmentMode ? 50 : 0)
                PlayersView(
                    courtType: courtType,
                    players: $players,
                    draggedPlayerIndex: $draggedPlayerIndex,
                    currentTouchType: $currentTouchType,
                    selectedTool: $selectedTool,
                    isPathAssignmentMode: $isPathAssignmentMode,
                    selectedDrawingId: $selectedDrawingId,
                    drawings: $drawings,
                    onAssignPath: assignPathToPlayer,
                    isAssigningBall: isAssigningBall,
                    selectedBasketballIndex: $selectedBasketballIndex,
                    onAssignBall: { playerIndex in
                        if let ballIdx = selectedBasketballIndex {
                            assignBasketballToPlayer(basketballIndex: ballIdx, playerIndex: playerIndex)
                            isAssigningBall = false
                            selectedBasketballIndex = nil
                        }
                    }
                )
                .zIndex(20)
                BasketballsView(
                    courtType: courtType,
                    basketballs: $basketballs,
                    players: $players,
                    draggedBasketballIndex: $draggedBasketballIndex,
                    currentTouchType: $currentTouchType,
                    selectedTool: $selectedTool,
                    isAssigningBall: isAssigningBall,
                    selectedBasketballIndex: $selectedBasketballIndex
                )
                .zIndex(selectedTool == .move || playbackState == .playing ? 10 : 2)
                OpponentsView(
                    courtType: courtType,
                    opponents: $opponents,
                    draggedOpponentIndex: $draggedOpponentIndex,
                    currentTouchType: $currentTouchType,
                    selectedTool: $selectedTool
                )
                .zIndex(selectedTool == .move || playbackState == .playing ? 10 : 2.5)
                TouchTypeDetectionView(
                    onTouchesChanged: { touchType, locations in
                        handleTouchChanged(touchType: touchType, locations: locations)
                    },
                    onTouchesEnded: { touchType in
                        handleTouchEnded(touchType: touchType)
                        if selectedTool == .move {
                            showPencilIndicator = false
                        }
                    },
                    onMove: { location in
                        lastTouchLocation = location
                        showPencilIndicator = true
                        handleMove(location: location)
                    },
                    selectedTool: selectedTool
                )
                .zIndex(isPathAssignmentMode ? 0 : 5)
                .allowsHitTesting(isEditable && !isPathAssignmentMode)
                if showPencilIndicator {
                    ZStack {
                        if selectedTool == .move {
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
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 16, height: 16)
                            Circle()
                                .stroke(Color.blue, lineWidth: 1)
                                .frame(width: 24, height: 24)
                        }
                    }
                    .position(lastTouchLocation)
                    .allowsHitTesting(false)
                    .zIndex(100)
                }
                if isPathAssignmentMode, let selectedPath = selectedDrawingId {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                .onEnded { value in
                                    let location = value.location
                                    print("Global tap at location: \(location)")
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
                        .zIndex(100)
                }
            }
            .frame(width: drawingWidth, height: drawingHeight)
            .offset(x: drawingOffsetX, y: drawingOffsetY)
            // --- End Indicator and DrawingLayer ---
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
            // Remove the status banner at the top
            /*
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
            */
            
            Spacer()

            // Remove the assigned path count text
            /*
            if playerAnimationData.count > 0 {
                Text("\(playerAnimationData.count) paths assigned")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
            }
            */
            
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
        // --- Condition Check: Only process drawing if a drawing tool is selected ---
        guard selectedTool == .pen || selectedTool == .arrow else {
            // print("handleTouchChanged: Ignoring touch, selectedTool is \\(selectedTool)") // Reduce log noise
            return
        }

        // Prevent drawing in path assignment mode
        guard !isPathAssignmentMode else {
            print("handleTouchChanged: Ignoring touch, in path assignment mode.")
            return
        }

        // Prevent drawing if move tool is active (should be caught by first guard, but double-check)
         // This guard might be redundant now due to the first one, but keep for safety
        guard selectedTool != .move else { return }


        currentTouchType = touchType
        // Only show pencil indicator when using a pencil with drawing tools
         showPencilIndicator = (touchType == .pencil && (selectedTool == .pen || selectedTool == .arrow)) // Corrected indicator logic


        // If we're in drawing mode with a pencil, and not currently dragging something, handle drawing
        // Ensure not accidentally dragging while drawing
        if touchType == .pencil && (selectedTool == .pen || selectedTool == .arrow) && draggedPlayerIndex == nil && draggedBasketballIndex == nil && !isPathAssignmentMode {

            // Process each location received (includes coalesced touches)
            if !locations.isEmpty {
                // Use the last location for visual indicator
                lastTouchLocation = locations.last!
                 showPencilIndicator = true // Show indicator while drawing with pencil


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
                    // print("Drawing at \\(lastTouchLocation)") // Reduce log noise
                }
            }
         } else {
             // Hide indicator if not drawing with pencil or if dragging
             showPencilIndicator = false
         }
        isDirty = true
    }

    private func handleTouchEnded(touchType: TouchInputType) {
        print("handleTouchEnded: tool=\(selectedTool), type=\(touchType)")

        // Always hide indicator on touch end
        showPencilIndicator = false

        // If we were drawing, finalize the drawing
        if (selectedTool == .pen || selectedTool == .arrow) && currentDrawing != nil { // Check tool selection here too
            if let drawing = currentDrawing {
                 // Ensure minimum points for an arrow (maybe 2 is enough?)
                 if drawing.type == .arrow && drawing.points.count < 2 {
                     print("Arrow too short, discarding.")
                     currentDrawing = nil // Discard short arrow
                 } else {
                     print("Finalizing drawing (ID: \\(drawing.id), type: \\(drawing.type))")
                     drawings.append(drawing)
                     actions.append(.drawing(drawing))
                     currentDrawing = nil
                 }
            }
        }

        // --- Finalize Move Operation ---
        // Check if we WERE dragging a player
        if let playerIndex = draggedPlayerIndex {
             print("handleTouchEnded: Finalizing move for player \\(playerIndex)")
             // Update normalized position one last time (might be redundant if done in handleMove, but safe)
             if playerIndex >= 0 && playerIndex < players.count {
                 updateNormalizedPosition(forPlayer: playerIndex, location: players[playerIndex].position)
             }
            draggedPlayerIndex = nil // Reset drag index
        }
        // Check if we WERE dragging a basketball
        if let basketballIndex = draggedBasketballIndex {
             print("handleTouchEnded: Finalizing move for basketball \\(basketballIndex)")
             // Update normalized position one last time
             if basketballIndex >= 0 && basketballIndex < basketballs.count {
                 updateNormalizedPosition(forBasketball: basketballIndex, location: basketballs[basketballIndex].position)
             }
            draggedBasketballIndex = nil // Reset drag index
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
        isDirty = true
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
        isDirty = true
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
        let willBeActive = !isPathAssignmentMode
        isPathAssignmentMode = willBeActive
        
        // If activating path assignment, turn off assign ball mode
        if willBeActive {
            if isAssigningBall {
                isAssigningBall = false
            }
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
        
        // Move player to the start of the assigned path
        if let startPoint = drawings[drawingIndex].points.first {
            players[playerIndex].position = startPoint
            updateNormalizedPosition(forPlayer: playerIndex, location: startPoint)
        }
        
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
        var maxProgress: Double = 0.0
        let maxDuration = maxAnimationDuration
        for (playerId, animData) in playerAnimationData {
            guard let playerIndex = players.firstIndex(where: { $0.id == playerId }) else {
                print("Warning: Could not find player with ID \(playerId) during animation update.")
                continue
            }
            let elapsedTime = currentTime.timeIntervalSince(animData.startTime)
            let timelineProgress = maxDuration > 0 ? min(elapsedTime / maxDuration, 1.0) : 0.0
            // For each player, their own progress is relative to their own duration
            let playerProgress = min(timelineProgress * maxDuration / animData.duration, 1.0)
            maxProgress = max(maxProgress, timelineProgress)
            if let newPosition = getPointOnPath(points: animData.pathPoints, progress: playerProgress) {
                players[playerIndex].position = newPosition
                players[playerIndex].isMoving = playerProgress < 1.0 && timelineProgress < 1.0
            } else {
                print("Warning: Could not get point on path for player \(playerId) at progress \(playerProgress)")
            }
            if playerProgress < 1.0 && timelineProgress < 1.0 {
                allAnimationsComplete = false
            } else {
                if players[playerIndex].isMoving {
                    players[playerIndex].isMoving = false
                }
                if let finalPosition = getPointOnPath(points: animData.pathPoints, progress: 1.0) {
                    players[playerIndex].position = finalPosition
                }
            }
        }
        // Move assigned basketballs with their players
        for i in basketballs.indices {
            if let assignedId = basketballs[i].assignedPlayerId,
               let player = players.first(where: { $0.id == assignedId }) {
                basketballs[i].position = player.position
                updateNormalizedPosition(forBasketball: i, location: player.position)
            }
        }
        playbackProgress = maxProgress
        if allAnimationsComplete {
            print("All animations reported complete.")
            completeAnimation()
        }
    }

    private func startAnimation() {
        let currentTime = Date() // Get current time for calculations

        switch playbackState {
        case .playing:
            print("Animation already playing.")
            return // Do nothing if already playing

        case .paused:
            print("Resuming animation...")
            // Ensure we have animation data and the time when pause occurred
            guard !playerAnimationData.isEmpty, let pt = pauseTime else {
                print("Cannot resume: Missing animation data or pause time. Resetting state.")
                playbackState = .stopped
                pauseTime = nil // Clear pause time just in case
                // We should also potentially reset player positions here if desired
                return
            }

            // Calculate how long the animation was paused
            let pauseDuration = currentTime.timeIntervalSince(pt)
            print("Pause duration: \(pauseDuration) seconds")

            // Adjust start times for all active animations
            var adjustedAnimationData: [UUID: PlayerAnimationData] = [:]
            for (playerId, animData) in playerAnimationData {
                // Create a new PlayerAnimationData with the startTime shifted forward
                let newStartTime = animData.startTime.addingTimeInterval(pauseDuration)
                let adjustedData = PlayerAnimationData(
                    pathPoints: animData.pathPoints,
                    totalDistance: animData.totalDistance,
                    startTime: newStartTime, // Use the adjusted start time
                    duration: animData.duration
                )
                adjustedAnimationData[playerId] = adjustedData
                print("Adjusted startTime for player \(playerId) to \(newStartTime)")
            }
            // Update the state with the adjusted data
            playerAnimationData = adjustedAnimationData

            // Clear the pause time now that we've used it
            self.pauseTime = nil

            // Set state and restart timer
            playbackState = .playing
            animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in 
                self.updateAnimations(timer: timer)
            }
            print("Animation Resumed.")

        case .stopped:
            print("Starting animation from stopped state (Resetting)...")
            playbackState = .playing // Set state early

            // --- Reset Logic (Moved from old stopAnimation) --- 
            animationTimer?.invalidate() 
            animationTimer = nil
            playerAnimationData.removeAll()
            originalPlayerPositions.removeAll()
            // Reset basketball positions (if using)
            // originalBasketballPositions.removeAll()
            // Reset highlighted paths
            for i in drawings.indices {
                drawings[i].isHighlightedDuringAnimation = false
            }
            // --- End Reset Logic --- 

            print("Preparing new animation...")
            let pixelsPerSecond: CGFloat = 275 
            var playersToAnimate = 0
            // Use currentTime defined at the start of the function

            // Prepare animation data for players with assigned paths
            for playerIndex in players.indices {
                guard let pathId = players[playerIndex].assignedPathId,
                      let drawing = drawings.first(where: { $0.id == pathId }),
                      !drawing.points.isEmpty else {
                    continue // Skip players without valid paths
                }

                let playerId = players[playerIndex].id
                // Determine the points to use for animation based on drawing type
                var animationPathPoints: [CGPoint] = []
                if drawing.type == .arrow && drawing.points.count >= 2 {
                    // For arrows, use only the start and end points for a straight line animation
                    animationPathPoints = [drawing.points.first!, drawing.points.last!]
                    print("Using straight path for arrow animation: \(animationPathPoints)")
                } else {
                    // For other types, use all recorded points
                    animationPathPoints = drawing.points
                }
                
                // Ensure we have points to animate
                guard !animationPathPoints.isEmpty else {
                    print("Skipping player \(playerId): No valid animation points.")
                    continue
                }

                // Store original position (current position before animation starts)
                originalPlayerPositions[playerId] = players[playerIndex].position
                // Highlight path
                if let drawingIndex = drawings.firstIndex(where: { $0.id == pathId }) {
                    drawings[drawingIndex].isHighlightedDuringAnimation = true
                }

                // Calculate path length and duration using the determined animation path
                let totalDistance = calculatePathLength(points: animationPathPoints)
                let duration = totalDistance / pixelsPerSecond
                let animationDuration = max(0.1, TimeInterval(duration)) 

                // Create animation data with the current time as startTime
                let animData = PlayerAnimationData(
                    pathPoints: animationPathPoints, // Use the potentially simplified path
                    totalDistance: totalDistance,
                    startTime: currentTime, // Use current time for new animation
                    duration: animationDuration
                )
                playerAnimationData[playerId] = animData

                // Mark player as moving and set initial position to start of the animation path
                players[playerIndex].isMoving = true
                players[playerIndex].position = animationPathPoints.first! // Use the start of the determined path

                playersToAnimate += 1
                print("Prepared animation for player \(playerIndex) (ID: \(playerId)) - Path: \(pathId), Duration: \(animationDuration)")
            }

            // Start the timer if there are players to animate
            if playersToAnimate > 0 {
                print("Starting animation timer for \(playersToAnimate) players.")
                animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in 
                    self.updateAnimations(timer: timer)
                }
            } else {
                print("No players have assigned paths, stopping animation.")
                playbackState = .stopped // Reset state if nothing to animate
            }
        }
    }

    // Add state variable for pause time
    @State private var pauseTime: Date?

    private func pauseAnimation() {
        print("Pausing animation")
        guard playbackState == .playing else { 
            print("Not playing, cannot pause.")
            return 
        }

        // 1. Invalidate the timer (stop updates)
        animationTimer?.invalidate()
        animationTimer = nil

        // 2. Record pause time
        pauseTime = Date()

        // 3. Set state to paused
        playbackState = .paused

        print("Animation paused at \(pauseTime!).")
    }
    
    private func handleMove(location: CGPoint) {
         // Ensure move tool is active *before* doing anything else
         guard selectedTool == .move else {
             // print("handleMove called but selectedTool is \\(selectedTool). Ignoring.") // Reduce noise
             return
         }

         // Simplified Debug Logging
         if debugMode {
              print("handleMove: loc=\(location), draggingP=\(String(describing: draggedPlayerIndex)), draggingB=\(String(describing: draggedBasketballIndex))")
         }

         // If currently dragging a player
         if let playerIndex = draggedPlayerIndex {
             // Make sure the index is in range
             if playerIndex >= 0 && playerIndex < players.count {
                 // Continue moving the currently dragged player
                 players[playerIndex].position = location
                 updateNormalizedPosition(forPlayer: playerIndex, location: location)
                 return // Already handled drag update
             } else {
                 // Index out of range, reset it
                 print("WARNING: Player index \\(playerIndex) out of range, resetting drag")
                 draggedPlayerIndex = nil
             }
         }

         // If currently dragging a basketball
         if let basketballIndex = draggedBasketballIndex {
             // Make sure the index is in range
             if basketballIndex >= 0 && basketballIndex < basketballs.count {
                 // Continue moving the currently dragged basketball
                 basketballs[basketballIndex].position = location
                 updateNormalizedPosition(forBasketball: basketballIndex, location: location)
                 return // Already handled drag update
             } else {
                 // Index out of range, reset it
                 print("WARNING: Basketball index \\(basketballIndex) out of range, resetting drag")
                 draggedBasketballIndex = nil
             }
         }

         // --- Hit Testing: Only if NOT currently dragging anything ---
         guard draggedPlayerIndex == nil && draggedBasketballIndex == nil else {
              // Already handled drag update above, no need for hit testing
              return
         }

         // Check for players first
         for (index, player) in players.enumerated() {
             let playerFrame = CGRect(x: player.position.x - 40, y: player.position.y - 40, width: 80, height: 80)
             if playerFrame.contains(location) {
                 if debugMode { print("handleMove: FOUND HIT! Starting to move player \\(index)") }
                 draggedPlayerIndex = index
                 players[index].position = location // Update position immediately
                 updateNormalizedPosition(forPlayer: index, location: location)
                 return // Found a player, start dragging
             }
         }

         // Check for basketballs if no player was hit
         for (index, basketball) in basketballs.enumerated() {
              let basketballFrame = CGRect(x: basketball.position.x - 35, y: basketball.position.y - 35, width: 70, height: 70)
             if basketballFrame.contains(location) {
                  if debugMode { print("handleMove: FOUND HIT! Starting to move basketball \\(index)") }
                 draggedBasketballIndex = index
                 basketballs[index].position = location // Update position immediately
                 updateNormalizedPosition(forBasketball: index, location: location)
                 return // Found a basketball, start dragging
             }
         }

         if debugMode {
              // print("handleMove: No item found to start dragging at \\(location)") // Reduce noise
         }
    }
    
    private func handleToolChange(_ tool: DrawingTool) {
        // Don't do anything if the same tool is tapped unless it's an 'add' tool
        if selectedTool == tool && tool != .addPlayer && tool != .addBasketball {
             print("Tool tapped, but it's the same non-add tool (\\(tool)). No state change.")
             // Ensure add modes are off if tapping same non-add tool
             isAddingPlayer = false
             isAddingBasketball = false
            return
        }

         print("Tool changing from \\(selectedTool) to \\(tool)")

        // --- Store old tool ---
         let previousSelectedTool = selectedTool

        // --- Update selectedTool state ---
         selectedTool = tool

        // --- Handle state resets based on the *previous* tool ---
        // Clear current drawing if switching AWAY from drawing tools
         if previousSelectedTool == .pen || previousSelectedTool == .arrow {
             if tool != .pen && tool != .arrow {
                 currentDrawing = nil
                 print("Cleared currentDrawing")
            }
        }
        // Reset indicator/location if switching AWAY from move tool
         if previousSelectedTool == .move {
            showPencilIndicator = false
            lastTouchLocation = .zero
            print("Reset pencil indicator and last touch location")
        }
        // Reset drag indices if switching AWAY from move tool
         if previousSelectedTool == .move {
            // No need to check the new tool, just reset if old was move
            draggedPlayerIndex = nil
            draggedBasketballIndex = nil
            print("Reset drag indices because switching AWAY from move tool")
        }

        // --- Handle state based on the *new* tool ---
        // Activate Add Modes or ensure they are off
         if tool == .addPlayer {
             isAddingPlayer = true
             isAddingBasketball = false
             print("Activating Add Player overlay")
         } else if tool == .addBasketball {
             isAddingBasketball = true
             isAddingPlayer = false
             print("Activating Add Basketball overlay")
         } else {
             // Ensure add modes are off for any other tool
             isAddingPlayer = false
             isAddingBasketball = false
             // print("Add modes deactivated for tool \\(tool)") // Can add if needed
         }


        // --- General cleanup ---
        // Exit path assignment mode if it was active
        if isPathAssignmentMode {
             exitPathAssignmentMode()
             print("Exited path assignment mode due to tool change")
        }


        // Final debug log for confirmation
        print("Tool change complete. Current tool: \\(selectedTool), isAddingPlayer: \\(isAddingPlayer), isAddingBasketball: \\(isAddingBasketball)")
    }

    private func loadPlayData(_ play: Models.SavedPlay) {
        // Convert and update state variables
        self.drawings = play.drawings.map { SavedPlayService.convertToDrawing(drawingData: $0) }
        self.players = play.players.map { SavedPlayService.convertToPlayer(playerData: $0) }
        self.basketballs = play.basketballs.map { SavedPlayService.convertToBasketball(basketballData: $0) }
        
        // Set play name if needed (you might want to add a @State var for this)
        // self.playName = play.name
        
        // Set other states based on the loaded play if necessary
    }

    // Add helper functions for normalized position updates
    private func updateNormalizedPosition(forPlayer index: Int, location: CGPoint) {
        guard index >= 0 && index < players.count else { return }
        let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
        let normalizedX = location.x / boundary.width
        let normalizedY = location.y / boundary.height
        players[index].normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
    }

    private func updateNormalizedPosition(forBasketball index: Int, location: CGPoint) {
         guard index >= 0 && index < basketballs.count else { return }
        let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
        let normalizedX = location.x / boundary.width
        let normalizedY = location.y / boundary.height
        basketballs[index].normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
    }

    // Add the actual save function
    private func saveCurrentPlay() {
        // 1. Gather Data
        let currentDrawings = self.drawings
        let currentPlayers = self.players
        let currentBasketballs = self.basketballs
        let name = self.playNameInput.trimmingCharacters(in: .whitespacesAndNewlines) // Trim whitespace
        let courtTypeString = self.courtType == .full ? "full" : "half"

        // Ensure name is not empty after trimming
        guard !name.isEmpty else {
            print("Save cancelled: Play name is empty.")
            // Optionally show an alert to the user
            return
        }

        // 2. Convert Data
        let drawingData = currentDrawings.map { SavedPlayService.convertToDrawingData(drawing: $0) }
        let playerData = currentPlayers.map { SavedPlayService.convertToPlayerData(player: $0) }
        let basketballData = currentBasketballs.map { SavedPlayService.convertToBasketballData(basketball: $0) }

        // 3. Create SavedPlay Object
        // Use the existing play's ID and dateCreated if editing, otherwise generate new
        let newPlay = Models.SavedPlay(
            id: playToLoad?.id ?? UUID(),
            name: name,
            dateCreated: playToLoad?.dateCreated ?? Date(),
            lastModified: Date(),
            courtType: courtTypeString,
            drawings: drawingData,
            players: playerData,
            basketballs: basketballData
        )

        // Print success message *before* attempting to persist
        print("Preparing to save Play '\(name)' with ID: \(newPlay.id)")

        // 4. Persist
        SavedPlayService.shared.savePlay(newPlay)
        // print("Play '\(name)' saved successfully with ID: \(newPlay.id)") // Moved this line up

        // 5. Cleanup
        playNameInput = "" // Clear the input field
        showingSaveAlert = false // Dismiss the alert implicitly by state change
        isDirty = false
        deleteDraft()

        // Optional: Add user feedback (e.g., a temporary banner)
    }

    // Add the completion handler function
    private func completeAnimation() {
        print("Completing animation...")
        // Ensure we are actually playing or paused to complete
        guard playbackState == .playing || playbackState == .paused else {
            print("Cannot complete: Animation not playing or paused.")
            return
        }

        // 1. Invalidate the timer
        animationTimer?.invalidate()
        animationTimer = nil

        // 2. Set state to stopped
        playbackState = .stopped

        // 3. Clear pause time
        pauseTime = nil

        // 4. Ensure players are at final positions and not moving
        //    (Partially done in updateAnimations, but confirm here)
        for (playerId, animData) in playerAnimationData {
             if let playerIndex = players.firstIndex(where: { $0.id == playerId }) {
                if let finalPosition = getPointOnPath(points: animData.pathPoints, progress: 1.0) {
                    players[playerIndex].position = finalPosition
                 }
                players[playerIndex].isMoving = false
            }
        }

        // 5. Clear animation data (but keep original positions)
        playerAnimationData.removeAll()
        // DO NOT clear originalPlayerPositions here

        // 6. Reset highlighted paths
        for i in drawings.indices {
            drawings[i].isHighlightedDuringAnimation = false
        }

        print("Animation completed and state reset to stopped.")
    }

    // Add opponent overlay
    @ViewBuilder
    private func addOpponentOverlay(geometry: GeometryProxy) -> some View {
        let parentWidth = geometry.size.width
        let parentHeight = geometry.size.height
        let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
        let drawingWidth = boundary.width
        let drawingHeight = boundary.height
        let drawingOffsetX = boundary.offsetX
        let drawingOffsetY = boundary.offsetY
        let drawingAreaOriginX = parentWidth / 2 + drawingOffsetX - drawingWidth / 2
        let drawingAreaOriginY = (parentHeight / 2 - 30) + drawingOffsetY - drawingHeight / 2
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture { isAddingOpponent = false }
            VStack {
                Text("Tap within the court to add opponent")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .padding(.top, 100)
                Spacer()
            }
            .allowsHitTesting(false)
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let tapPosition = value.location
                            let relativeX = tapPosition.x - drawingAreaOriginX
                            let relativeY = tapPosition.y - drawingAreaOriginY
                            let adjustedPosition = CGPoint(x: relativeX, y: relativeY)
                            if relativeX >= 0 && relativeX <= drawingWidth && relativeY >= 0 && relativeY <= drawingHeight {
                                addOpponentAt(position: adjustedPosition)
                            }
                            isAddingOpponent = false
                        }
                )
        }
    }

    private func addOpponentAt(position: CGPoint) {
        let boundary = courtType == .full ? DrawingBoundary.fullCourt : DrawingBoundary.halfCourt
        let adjustedPosition = position
        let normalizedX = adjustedPosition.x / boundary.width
        let normalizedY = adjustedPosition.y / boundary.height
        let newOpponent = OpponentCircle(
            position: adjustedPosition,
            number: opponents.count + 1,
            normalizedPosition: CGPoint(x: normalizedX, y: normalizedY)
        )
        opponents.append(newOpponent)
        actions.append(.opponent(newOpponent))
        isDirty = true
    }

    // Add helper to set animation progress
    private func setAnimationProgress(_ progress: Double) {
        let maxDuration = maxAnimationDuration
        let timelineTime = progress * maxDuration
        for (playerId, animData) in playerAnimationData {
            if let playerIndex = players.firstIndex(where: { $0.id == playerId }) {
                let playerProgress = min(timelineTime / animData.duration, 1.0)
                if let newPosition = getPointOnPath(points: animData.pathPoints, progress: CGFloat(playerProgress)) {
                    players[playerIndex].position = newPosition
                    players[playerIndex].isMoving = (playerProgress < 1.0)
                }
            }
        }
    }

    // Add helper to get animation duration string (max duration among all players)
    private func animationDurationString() -> String {
        let maxDuration = maxAnimationDuration
        let minutes = Int(maxDuration) / 60
        let seconds = Int(maxDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startIndicatorAnimation() {
        stopIndicatorAnimation()
        indicatorTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            indicatorPhase += 0.008
            if indicatorPhase > 1.0 { indicatorPhase = 0.0 }
        }
    }
    private func stopIndicatorAnimation() {
        indicatorTimer?.invalidate()
        indicatorTimer = nil
    }

    private func calculatePathLength(points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        var totalDistance: CGFloat = 0
        for i in 0..<(points.count - 1) {
            totalDistance += points[i].distance(to: points[i+1])
        }
        return totalDistance;
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

    @ViewBuilder
    private func indicatorViewForPlayer(playerIndex: Int, drawingWidth: CGFloat, drawingHeight: CGFloat) -> some View {
        let player = players[playerIndex]
        if let pathId = player.assignedPathId,
           let drawing = drawings.first(where: { $0.id == pathId }),
           drawing.points.count > 1,
           let indicatorPosition = getPointOnPath(points: drawing.points, progress: indicatorPhase) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: 18, height: 18)
                    .scaleEffect(1 + 0.3 * sin(indicatorPhase * 2 * .pi))
                    .shadow(color: Color.blue.opacity(0.5), radius: 8)
                Image(systemName: "arrow.right")
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .bold))
                    .rotationEffect(
                        Angle(radians: atan2(
                            drawing.points.last!.y - drawing.points.first!.y,
                            drawing.points.last!.x - drawing.points.first!.x
                        ))
                    )
            }
            .position(indicatorPosition)
        } else {
            EmptyView()
        }
    }

    // Implement saveAsNewPlay function
    private func saveAsNewPlay() {
        // 1. Gather Data
        let currentDrawings = self.drawings
        let currentPlayers = self.players
        let currentBasketballs = self.basketballs
        let name = self.playNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let courtTypeString = self.courtType == .full ? "full" : "half"
        guard !name.isEmpty else { return }
        let drawingData = currentDrawings.map { SavedPlayService.convertToDrawingData(drawing: $0) }
        let playerData = currentPlayers.map { SavedPlayService.convertToPlayerData(player: $0) }
        let basketballData = currentBasketballs.map { SavedPlayService.convertToBasketballData(basketball: $0) }
        let newPlay = Models.SavedPlay(
            id: UUID(), // Always new UUID
            name: name,
            dateCreated: Date(),
            lastModified: Date(),
            courtType: courtTypeString,
            drawings: drawingData,
            players: playerData,
            basketballs: basketballData
        )
        SavedPlayService.shared.savePlay(newPlay)
        playNameInput = ""
        showingSaveAsAlert = false
        isDirty = false
    }

    // Add new function for immediate save
    private func saveCurrentPlayImmediate(onSuccess: (() -> Void)? = nil) {
        let currentDrawings = self.drawings
        let currentPlayers = self.players
        let currentBasketballs = self.basketballs
        let name: String = playToLoad?.name ?? playNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let courtTypeString = self.courtType == .full ? "full" : "half"
        guard !name.isEmpty else { return }
        let drawingData = currentDrawings.map { SavedPlayService.convertToDrawingData(drawing: $0) }
        let playerData = currentPlayers.map { SavedPlayService.convertToPlayerData(player: $0) }
        let basketballData = currentBasketballs.map { SavedPlayService.convertToBasketballData(basketball: $0) }
        let newPlay = Models.SavedPlay(
            id: playToLoad?.id ?? UUID(),
            name: name,
            dateCreated: playToLoad?.dateCreated ?? Date(),
            lastModified: Date(),
            courtType: courtTypeString,
            drawings: drawingData,
            players: playerData,
            basketballs: basketballData
        )
        SavedPlayService.shared.savePlay(newPlay)
        isDirty = false
        deleteDraft()
        onSuccess?()
    }

    // --- Auto-Save/Drafts ---
    private func saveDraft() {
        guard isDirty else { return } // Only save if there are unsaved changes
        let drawingData = self.drawings.map { SavedPlayService.convertToDrawingData(drawing: $0) }
        let playerData = self.players.map { SavedPlayService.convertToPlayerData(player: $0) }
        let basketballData = self.basketballs.map { SavedPlayService.convertToBasketballData(basketball: $0) }
        let draft = DraftPlay(
            drawings: drawingData,
            players: playerData,
            basketballs: basketballData,
            name: playToLoad?.name ?? playNameInput,
            courtType: self.courtType == .full ? "full" : "half"
        )
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: draftKey)
        }
    }
    private func loadDraft() -> DraftPlay? {
        if let data = UserDefaults.standard.data(forKey: draftKey),
           let draft = try? JSONDecoder().decode(DraftPlay.self, from: data) {
            // Only return the draft if it matches the current play (by name and courtType)
            let currentName = playToLoad?.name ?? playNameInput
            let currentCourtType = self.courtType == .full ? "full" : "half"
            if draft.name == currentName && draft.courtType == currentCourtType {
                return draft
            }
        }
        return nil
    }
    private func deleteDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
    }

    // --- Draft Model ---
    private struct DraftPlay: Codable {
        var drawings: [Models.DrawingData]
        var players: [Models.PlayerData]
        var basketballs: [Models.BasketballData]
        var name: String
        var courtType: String // "full" or "half"
    }

    private func restoreFromDraft(_ draft: DraftPlay) {
        self.drawings = draft.drawings.map { SavedPlayService.convertToDrawing(drawingData: $0) }
        self.players = draft.players.map { SavedPlayService.convertToPlayer(playerData: $0) }
        self.basketballs = draft.basketballs.map { SavedPlayService.convertToBasketball(basketballData: $0) }
        self.playNameInput = draft.name
        // courtType is fixed for this view
        isDirty = true
    }

    // Assign a basketball to a player
    private func assignBasketballToPlayer(basketballIndex: Int, playerIndex: Int) {
        guard basketballIndex >= 0, basketballIndex < basketballs.count,
              playerIndex >= 0, playerIndex < players.count else { return }
        basketballs[basketballIndex].assignedPlayerId = players[playerIndex].id
        // Move the basketball to the player's position immediately
        basketballs[basketballIndex].position = players[playerIndex].position
        updateNormalizedPosition(forBasketball: basketballIndex, location: players[playerIndex].position)
    }

    func loadPlay(play: Models.SavedPlay) {
        // ... existing code ...
    }
}

struct WhiteboardView_Previews: PreviewProvider {
    static var previews: some View {
        WhiteboardView(courtType: .full)
    }
}



