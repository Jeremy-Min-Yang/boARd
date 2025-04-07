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

// CourtImageView implementation
struct CourtImageView: View {
    let courtType: CourtType
    let frame: CGRect // Use a fixed frame passed from parent
    
    var body: some View {
        ZStack {
            // White background
            Color.white
            
            if courtType == .full {
                // Full court rotates based on orientation
                ZStack {
                    // Court image
                    Image("fullcourt")
                        .resizable()
                        .scaledToFit()
                        .rotationEffect(frame.width > frame.height ? Angle(degrees: 90) : Angle(degrees: 0))
                        .overlay(
                            Rectangle()
                                .stroke(Color.black, lineWidth: 3)
                                .allowsHitTesting(false) // The border shouldn't block interaction
                        )
                        .rotationEffect(frame.width > frame.height ? Angle(degrees: 90) : Angle(degrees: 0))
                    
                    // Border rotates with the court
                    Rectangle()
                        .stroke(Color.red, lineWidth: 3)
                        .allowsHitTesting(false) // The border shouldn't block interaction
                        .rotationEffect(frame.width > frame.height ? Angle(degrees: 90) : Angle(degrees: 0))
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
    @State private var isLandscape: Bool = false
    @State private var currentTouchType: TouchInputType = .unknown
    @State private var showPencilIndicator: Bool = false
    @State private var lastTouchLocation: CGPoint = .zero
    @State private var showDrawingBounds: Bool = false
    
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
                        transformDrawingsForRotation(width: geometry.size.width, height: geometry.size.height)
                        transformObjectsForRotation(players: &players, width: geometry.size.width, height: geometry.size.height)
                        transformObjectsForRotation(basketballs: &basketballs, width: geometry.size.width, height: geometry.size.height)
                    }
                }
            }
            
            VStack(spacing: 0) {
                // Fixed toolbar row below navigation bar
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
                        if !drawings.isEmpty {
                            drawings.removeLast()
                        }
                    },
                    onClear: {
                        drawings.removeAll()
                        players.removeAll()
                        basketballs.removeAll()
                    }
                )
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
                
                // Main content area
                ZStack {
                    // Background color
                    Color.white.edgesIgnoringSafeArea(.all)
                    
                    // Define constants for consistent sizing
                    // Use a larger scaling factor to match the visible court area better
                    let courtWidth = courtType == .full && newIsLandscape ? 
                                    geometry.size.height * 0.95 : geometry.size.width * 0.95
                    // Use aspect ratio of the court image for better matching
                    let courtAspectRatio: CGFloat = courtType == .full ? 1.87 : 1.0  // Adjust these based on actual image
                    let courtHeight = courtType == .full && newIsLandscape ? 
                                     geometry.size.width * 0.95 : courtWidth / courtAspectRatio
                    
                    // For full court, we need to invert the aspect ratio based on orientation
                    let isCourtRotated = courtType == .full && newIsLandscape
                    
                    // Calculate the visible court factors based on orientation
                    // When the court is rotated, we need to swap width and height factors
                    let visibleCourtWidthFactor: CGFloat = isCourtRotated ? 0.90 : 0.94
                    let visibleCourtHeightFactor: CGFloat = isCourtRotated ? 0.94 : 0.90
                    
                    // Main drawing area with both court and canvas in a single container
                    ZStack {
                        // Background color
                        Color.white
                        
                        // Court image as the background
                        Group {
                            if courtType == .full {
                                Image("fullcourt")
                                    .resizable()
                                    .scaledToFit()
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.black, lineWidth: 3)
                                            .allowsHitTesting(false)
                                    )
                                    .rotationEffect(newIsLandscape ? Angle(degrees: 90) : Angle(degrees: 0))
                            } else {
                                // For half court, use the container size directly
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
                        .frame(width: courtWidth, height: courtHeight)
                        
                        // Drawing layer on top
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
                        .frame(width: courtWidth, height: courtHeight)
                        
                        // Touch detection layer - make sure it has the exact same dimensions and position
                        // as the DrawingLayer for perfect alignment
                        TouchTypeDetectionView(
                            onTouchesChanged: { touchType, locations in
                                if !locations.isEmpty {
                                    let location = locations.first!
                                    // Don't update lastTouchLocation immediately, allow adjustment function to handle it
                                    // That way the visual indicator matches the actual drawing position
                                    handleTouchChanged(touchType: touchType, location: location)
                                }
                            },
                            onTouchesEnded: { touchType in
                                handleTouchEnded(touchType: touchType)
                            }
                        )
                        .frame(width: courtWidth, height: courtHeight)
                        .allowsHitTesting(true)
                        
                        // Basketballs - draw at exact locations
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
                                                
                                                // Update normalized position
                                                let courtWidth = isLandscape ? geometry.size.height * 0.95 : geometry.size.width * 0.95
                                                let courtHeight = isLandscape ? geometry.size.width * 0.95 : (geometry.size.height - 48) * 0.95
                                                
                                                // Calculate court origin using the consistent method
                                                let courtOriginX = (geometry.size.width - courtWidth) / 2
                                                let courtOriginY = (geometry.size.height - 48) / 2
                                                
                                                let normalizedX = (value.location.x - courtOriginX) / courtWidth
                                                let normalizedY = (value.location.y - courtOriginY) / courtHeight
                                                
                                                updatedBasketball.normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
                                                
                                                basketballs[index] = updatedBasketball
                                            }
                                        }
                                        .onEnded { _ in
                                            draggedBasketballIndex = nil
                                        }
                                )
                        }
                        
                        // Player circles - draw at exact locations
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
                                                
                                                // Update normalized position
                                                let courtWidth = isLandscape ? geometry.size.height * 0.95 : geometry.size.width * 0.95
                                                let courtHeight = isLandscape ? geometry.size.width * 0.95 : (geometry.size.height - 48) * 0.95
                                                
                                                // Calculate court origin using the consistent method
                                                let courtOriginX = (geometry.size.width - courtWidth) / 2
                                                let courtOriginY = (geometry.size.height - 48) / 2
                                                
                                                let normalizedX = (value.location.x - courtOriginX) / courtWidth
                                                let normalizedY = (value.location.y - courtOriginY) / courtHeight
                                                
                                                updatedPlayer.normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
                                                
                                                players[index] = updatedPlayer
                                            }
                                        }
                                        .onEnded { _ in
                                            draggedPlayerIndex = nil
                                        }
                                )
                        }
                        
                        // Pencil indicator (shows when Apple Pencil is detected)
                        if showPencilIndicator {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 20, height: 20)
                                .position(lastTouchLocation)
                        }
                        
                        // Debug visualization for drawing boundaries
                        if showDrawingBounds {
                            // Calculate the court boundaries to match the actual visible court lines
                            
                            // 1. Draw a green boundary to show the image frame
                            Rectangle()
                                .stroke(Color.green, lineWidth: 2)
                                .frame(width: courtWidth, height: courtHeight)
                                .opacity(0.7)
                            
                            // 2. Draw a red boundary to show where we're enforcing drawing limits
                            // For half court, we'll use a 94% width and 90% height of the image
                            // For full court, we'll adjust based on orientation
                            let visibleWidth = courtWidth * visibleCourtWidthFactor
                            let visibleHeight = courtHeight * visibleCourtHeightFactor
                            
                            Rectangle()
                                .stroke(Color.red, lineWidth: 2)
                                .frame(width: visibleWidth, height: visibleHeight)
                                .opacity(0.7)
                            
                            // Display orientation information in the debug overlay
                            Text("Rotated: \(isCourtRotated ? "Yes" : "No")")
                                .font(.caption)
                                .foregroundColor(.red)
                                .background(Color.white.opacity(0.7))
                                .position(x: courtWidth / 2, y: 20)
                            
                            // 3. Draw corner markers for the visible court
                            let offsetX = (courtWidth - visibleWidth) / 2
                            let offsetY = (courtHeight - visibleHeight) / 2
                            
                            // Show visible drawing area corners
                            ForEach(0..<4) { corner in
                                let x = corner % 2 == 0 ? offsetX : courtWidth - offsetX
                                let y = corner < 2 ? offsetY : courtHeight - offsetY
                                
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                    .position(x: x, y: y)
                            }
                            
                            // 4. Draw center marker
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                        }
                    }
                    .frame(width: courtWidth, height: courtHeight)
                    .overlay(
                        Rectangle()
                            .stroke(Color.blue, lineWidth: 4)
                            .allowsHitTesting(false)
                    )
                    .position(x: geometry.size.width / 2, y: (geometry.size.height - 48) / 2)
                    
                    // Debug information overlay
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Court: \(courtType == .full ? "Full" : "Half")")
                            .font(.caption)
                            .foregroundColor(.black)
                        Text("Orientation: \(newIsLandscape ? "Landscape" : "Portrait")")
                            .font(.caption)
                            .foregroundColor(.black)
                        Text("Size: \(Int(courtWidth))×\(Int(courtHeight))")
                            .font(.caption)
                            .foregroundColor(.black)
                        Text("Input: \(currentTouchType == .pencil ? "Apple Pencil" : currentTouchType == .finger ? "Finger" : "Unknown")")
                            .font(.caption)
                            .foregroundColor(currentTouchType == .pencil ? .blue : .black)
                        
                        // Add toggle for debug visualization
                        Toggle("Show Boundaries", isOn: $showDrawingBounds)
                            .font(.caption)
                            .foregroundColor(.black)
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
                    
                    // Add player button (shows when isAddingPlayer is true)
                    if isAddingPlayer {
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
                            .frame(width: courtWidth, height: courtHeight)
                            .contentShape(Rectangle())
                            .gesture(
                                TapGesture()
                                    .onEnded { _ in
                                        let center = CGPoint(
                                            x: courtWidth / 2,
                                            y: courtHeight / 2
                                        )
                                        addPlayerAt(position: center)
                                        isAddingPlayer = false
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
                            .frame(width: courtWidth, height: courtHeight)
                            .contentShape(Rectangle())
                            .gesture(
                                TapGesture()
                                    .onEnded { _ in
                                        let center = CGPoint(
                                            x: courtWidth / 2,
                                            y: courtHeight / 2
                                        )
                                        addBasketballAt(position: center)
                                        isAddingBasketball = false
                                    }
                            )
                    }
                }
            }
            .navigationTitle(courtType == .full ? "Full Court" : "Half Court")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func handleTouchChanged(touchType: TouchInputType, location: CGPoint) {
        // Update current touch type
        currentTouchType = touchType
        
        // If it's a pencil, show the indicator
        showPencilIndicator = (touchType == .pencil)
        
        // If we're in drawing mode with a pencil, handle drawing
        if touchType == .pencil && (selectedTool == .pen || selectedTool == .arrow) {
            // Get the actual dimensions using UIScreen for consistency
            let screenSize = UIScreen.main.bounds.size
            let courtWidth = isLandscape ? screenSize.height * 0.95 : screenSize.width * 0.95
            let courtHeight = isLandscape ? screenSize.width * 0.95 : (screenSize.height - 48) * 0.95
            
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
    
    private func startNewDrawing(at point: CGPoint) {
        // Get screen and court dimensions for normalization
        let screenSize = UIScreen.main.bounds.size
        let courtWidth = isLandscape ? screenSize.height * 0.95 : screenSize.width * 0.95
        
        // Use aspect ratio for consistent height calculation
        let courtAspectRatio: CGFloat = courtType == .full ? 1.87 : 1.0
        let courtHeight = isLandscape ? screenSize.width * 0.95 : courtWidth / courtAspectRatio
        
        // Determine if the court is rotated (for full court in landscape)
        let isCourtRotated = courtType == .full && isLandscape
        
        // Adjust the point to make sure it's mapped correctly to the court
        let adjustedPoint = adjustTouchLocation(point, in: screenSize, courtWidth: courtWidth, courtHeight: courtHeight)
        
        // Calculate visible court area
        let visibleCourtWidthFactor: CGFloat = isCourtRotated ? 0.90 : 0.94
        let visibleCourtHeightFactor: CGFloat = isCourtRotated ? 0.94 : 0.90
        
        let visibleWidth = courtWidth * visibleCourtWidthFactor
        let visibleHeight = courtHeight * visibleCourtHeightFactor
        
        // Calculate offsets to the visible court boundaries
        let offsetX = (courtWidth - visibleWidth) / 2
        let offsetY = (courtHeight - visibleHeight) / 2
        
        // Calculate normalized position relative to the visible court area
        let normalizedX = (adjustedPoint.x - offsetX) / visibleWidth
        let normalizedY = (adjustedPoint.y - offsetY) / visibleHeight
        let normalizedPoint = CGPoint(x: normalizedX, y: normalizedY)
        
        // Start a new drawing
        var newPath = Path()
        newPath.move(to: adjustedPoint)
        
        // Determine line width based on input type
        let lineWidth = (selectedTool == .arrow) ? 5 : getPencilWidth(for: currentTouchType)
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
        let courtWidth = isLandscape ? screenSize.height * 0.95 : screenSize.width * 0.95
        
        // Use aspect ratio for consistent height calculation
        let courtAspectRatio: CGFloat = courtType == .full ? 1.87 : 1.0
        let courtHeight = isLandscape ? screenSize.width * 0.95 : courtWidth / courtAspectRatio
        
        // Determine if the court is rotated (for full court in landscape)
        let isCourtRotated = courtType == .full && isLandscape
        
        // Adjust the point to make sure it's mapped correctly to the court
        let adjustedPoint = adjustTouchLocation(point, in: screenSize, courtWidth: courtWidth, courtHeight: courtHeight)
        
        // Calculate visible court area
        let visibleCourtWidthFactor: CGFloat = isCourtRotated ? 0.90 : 0.94
        let visibleCourtHeightFactor: CGFloat = isCourtRotated ? 0.94 : 0.90
        
        let visibleWidth = courtWidth * visibleCourtWidthFactor
        let visibleHeight = courtHeight * visibleCourtHeightFactor
        
        // Calculate offsets to the visible court boundaries
        let offsetX = (courtWidth - visibleWidth) / 2
        let offsetY = (courtHeight - visibleHeight) / 2
        
        // Calculate normalized position relative to the visible court area
        let normalizedX = (adjustedPoint.x - offsetX) / visibleWidth
        let normalizedY = (adjustedPoint.y - offsetY) / visibleHeight
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
                    x: (mid.y - previousPoint.y) * 0.3,
                    y: (previousPoint.x - mid.x) * 0.3
                )
                let controlPoint = CGPoint(
                    x: mid.x + offset.x,
                    y: mid.y + offset.y
                )
                path.addQuadCurve(to: adjustedPoint, control: controlPoint)
                
            case .zigzag:
                // Create zigzag effect
                let distance = previousPoint.distance(to: adjustedPoint)
                let segments = max(Int(distance / 10), 1)
                
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
                currentDrawing = nil
            }
        }
    }
    
    private func addPlayerAt(position: CGPoint) {
        // Calculate court dimensions
        let geometry = UIScreen.main.bounds.size
        let courtWidth = isLandscape ? geometry.height * 0.95 : geometry.width * 0.95
        let courtHeight = isLandscape ? geometry.width * 0.95 : (geometry.height - 48) * 0.95
        
        // Calculate court origin using the consistent method
        let courtOriginX = (geometry.width - courtWidth) / 2
        let courtOriginY = (geometry.height - 48) / 2
        
        // Calculate normalized position
        let normalizedX = (position.x - courtOriginX) / courtWidth
        let normalizedY = (position.y - courtOriginY) / courtHeight
        
        let newPlayer = PlayerCircle(
            position: position,
            number: players.count + 1,
            color: .blue,
            normalizedPosition: CGPoint(x: normalizedX, y: normalizedY)
        )
        players.append(newPlayer)
    }
    
    private func addBasketballAt(position: CGPoint) {
        // Calculate court dimensions
        let geometry = UIScreen.main.bounds.size
        let courtWidth = isLandscape ? geometry.height * 0.95 : geometry.width * 0.95
        let courtHeight = isLandscape ? geometry.width * 0.95 : (geometry.height - 48) * 0.95
        
        // Calculate court origin using the consistent method
        let courtOriginX = (geometry.width - courtWidth) / 2
        let courtOriginY = (geometry.height - 48) / 2
        
        // Calculate normalized position
        let normalizedX = (position.x - courtOriginX) / courtWidth
        let normalizedY = (position.y - courtOriginY) / courtHeight
        
        let newBasketball = BasketballItem(
            position: position,
            normalizedPosition: CGPoint(x: normalizedX, y: normalizedY)
        )
        basketballs.append(newBasketball)
    }
    
    // Transform drawings when rotating
    private func transformDrawingsForRotation(width: CGFloat, height: CGFloat) {
        // Only transform for full court
        if courtType != .full {
            return
        }
        
        // Calculate current court dimensions
        let currentCourtWidth = isLandscape ? height * 0.95 : width * 0.95
        let currentCourtHeight = isLandscape ? width * 0.95 : (height - 48) * 0.95
        
        // Calculate current court origin using consistent method
        let currentCourtOriginX = (width - currentCourtWidth) / 2
        let currentCourtOriginY = (height - 48) / 2
        
        // Calculate new court dimensions after rotation
        let newCourtWidth = !isLandscape ? height * 0.95 : width * 0.95
        let newCourtHeight = !isLandscape ? width * 0.95 : (height - 48) * 0.95
        
        // Calculate new court origin using consistent method
        let newCourtOriginX = (width - newCourtWidth) / 2
        let newCourtOriginY = (height - 48) / 2
        
        // Transform all existing drawings
        for i in 0..<drawings.count {
            var newPath = Path()
            var newPoints: [CGPoint] = []
            var normalizedPoints: [CGPoint] = []
            
            // If we already have normalized points, use them for better accuracy
            if let existingNormalizedPoints = drawings[i].normalizedPoints {
                normalizedPoints = existingNormalizedPoints
                
                // Convert normalized points to new screen coordinates
                for normalizedPoint in normalizedPoints {
                    let transformedPoint = CGPoint(
                        x: normalizedPoint.x * newCourtWidth + (width - newCourtWidth) / 2,
                        y: normalizedPoint.y * newCourtHeight + (height - newCourtHeight) / 2
                    )
                    
                    newPoints.append(transformedPoint)
                    
                    if newPath.isEmpty {
                        newPath.move(to: transformedPoint)
                    } else {
                        newPath.addLine(to: transformedPoint)
                    }
                }
            } else {
                // Calculate normalized points if we don't have them yet
                for point in drawings[i].points {
                    // Normalize the point to court dimensions (0-1 range)
                    let normalizedX = (point.x - (width - currentCourtWidth) / 2) / currentCourtWidth
                    let normalizedY = (point.y - (height - currentCourtHeight) / 2) / currentCourtHeight
                    
                    // Store the normalized point
                    normalizedPoints.append(CGPoint(x: normalizedX, y: normalizedY))
                    
                    // For rotation, swap coordinates but preserve relative position
                    let newNormalizedX = normalizedY
                    let newNormalizedY = 1 - normalizedX
                    
                    // Convert back to absolute coordinates for the new orientation
                    let transformedPoint = CGPoint(
                        x: newNormalizedX * newCourtWidth + (width - newCourtWidth) / 2,
                        y: newNormalizedY * newCourtHeight + (height - newCourtHeight) / 2
                    )
                    
                    newPoints.append(transformedPoint)
                    
                    if newPath.isEmpty {
                        newPath.move(to: transformedPoint)
                    } else {
                        newPath.addLine(to: transformedPoint)
                    }
                }
            }
            
            // Update the drawing with the new path, points and normalized points
            drawings[i].path = newPath
            drawings[i].points = newPoints
            drawings[i].normalizedPoints = normalizedPoints
        }
    }
    
    // Transform player circles when rotating
    private func transformObjectsForRotation(players: inout [PlayerCircle], width: CGFloat, height: CGFloat) {
        // Only transform for full court
        if courtType != .full {
            return
        }
        
        // Calculate current court dimensions
        let currentCourtWidth = isLandscape ? height * 0.95 : width * 0.95
        let currentCourtHeight = isLandscape ? width * 0.95 : (height - 48) * 0.95
        
        // Calculate new court dimensions after rotation
        let newCourtWidth = !isLandscape ? height * 0.95 : width * 0.95
        let newCourtHeight = !isLandscape ? width * 0.95 : (height - 48) * 0.95
        
        // Transform all player positions
        for i in 0..<players.count {
            // If we already have normalized position, use it
            if let normalizedPosition = players[i].normalizedPosition {
                // For rotation, swap coordinates but preserve relative position
                let newNormalizedX = normalizedPosition.y
                let newNormalizedY = 1 - normalizedPosition.x
                
                // Convert back to screen coordinates
                let transformedPosition = CGPoint(
                    x: newNormalizedX * newCourtWidth + (width - newCourtWidth) / 2,
                    y: newNormalizedY * newCourtHeight + (height - newCourtHeight) / 2
                )
                
                players[i].position = transformedPosition
            } else {
                // Calculate normalized position relative to the court
                let position = players[i].position
                let normalizedX = (position.x - (width - currentCourtWidth) / 2) / currentCourtWidth
                let normalizedY = (position.y - (height - currentCourtHeight) / 2) / currentCourtHeight
                
                // Store the normalized position
                players[i].normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
                
                // For rotation, swap coordinates but preserve relative position
                let newNormalizedX = normalizedY
                let newNormalizedY = 1 - normalizedX
                
                // Convert back to screen coordinates
                let transformedPosition = CGPoint(
                    x: newNormalizedX * newCourtWidth + (width - newCourtWidth) / 2,
                    y: newNormalizedY * newCourtHeight + (height - newCourtHeight) / 2
                )
                
                players[i].position = transformedPosition
            }
        }
    }
    
    // Transform basketballs when rotating
    private func transformObjectsForRotation(basketballs: inout [BasketballItem], width: CGFloat, height: CGFloat) {
        // Only transform for full court
        if courtType != .full {
            return
        }
        
        // Calculate current court dimensions
        let currentCourtWidth = isLandscape ? height * 0.95 : width * 0.95
        let currentCourtHeight = isLandscape ? width * 0.95 : (height - 48) * 0.95
        
        // Calculate new court dimensions after rotation
        let newCourtWidth = !isLandscape ? height * 0.95 : width * 0.95
        let newCourtHeight = !isLandscape ? width * 0.95 : (height - 48) * 0.95
        
        // Transform all basketball positions
        for i in 0..<basketballs.count {
            // If we already have normalized position, use it
            if let normalizedPosition = basketballs[i].normalizedPosition {
                // For rotation, swap coordinates but preserve relative position
                let newNormalizedX = normalizedPosition.y
                let newNormalizedY = 1 - normalizedPosition.x
                
                // Convert back to screen coordinates
                let transformedPosition = CGPoint(
                    x: newNormalizedX * newCourtWidth + (width - newCourtWidth) / 2,
                    y: newNormalizedY * newCourtHeight + (height - newCourtHeight) / 2
                )
                
                basketballs[i].position = transformedPosition
            } else {
                // Calculate normalized position relative to the court
                let position = basketballs[i].position
                let normalizedX = (position.x - (width - currentCourtWidth) / 2) / currentCourtWidth
                let normalizedY = (position.y - (height - currentCourtHeight) / 2) / currentCourtHeight
                
                // Store the normalized position
                basketballs[i].normalizedPosition = CGPoint(x: normalizedX, y: normalizedY)
                
                // For rotation, swap coordinates but preserve relative position
                let newNormalizedX = normalizedY
                let newNormalizedY = 1 - normalizedX
                
                // Convert back to screen coordinates
                let transformedPosition = CGPoint(
                    x: newNormalizedX * newCourtWidth + (width - newCourtWidth) / 2,
                    y: newNormalizedY * newCourtHeight + (height - newCourtHeight) / 2
                )
                
                basketballs[i].position = transformedPosition
            }
        }
    }
    
    private func getPencilWidth(for touchType: TouchInputType) -> CGFloat {
        // Default widths based on input type
        switch touchType {
        case .pencil:
            return 2.0  // Thinner line for pencil
        case .finger:
            return 5.0  // Thicker line for finger
        case .unknown:
            return 3.0  // Medium for unknown
        }
    }
    
    // Helper function to adjust coordinates for better precision
    private func adjustTouchLocation(_ location: CGPoint, in geometrySize: CGSize, courtWidth: CGFloat, courtHeight: CGFloat) -> CGPoint {
        // Determine if the court is rotated (for full court in landscape)
        let isCourtRotated = courtType == .full && isLandscape
        
        // Calculate the visible court area based on the factors we determined, accounting for rotation
        let visibleCourtWidthFactor: CGFloat = isCourtRotated ? 0.90 : 0.94
        let visibleCourtHeightFactor: CGFloat = isCourtRotated ? 0.94 : 0.90
        
        let visibleWidth = courtWidth * visibleCourtWidthFactor
        let visibleHeight = courtHeight * visibleCourtHeightFactor
        
        // Calculate offsets to the visible court boundaries
        let offsetX = (courtWidth - visibleWidth) / 2
        let offsetY = (courtHeight - visibleHeight) / 2
        
        // Convert the touch point to the coordinate space of the court itself
        // This assumes the touch is already in the ZStack's coordinate space
        let courtX = location.x
        let courtY = location.y
        
        // Debug by logging the bounds
        if showDrawingBounds {
            print("Court size: \(courtWidth) × \(courtHeight)")
            print("Visible court: \(visibleWidth) × \(visibleHeight)")
            print("Is court rotated: \(isCourtRotated)")
            print("Touch location: \(location)")
            print("Adjusted location in court space: (\(courtX), \(courtY))")
        }
        
        // If the touch is within the visible court bounds, use it directly
        if courtX >= offsetX && courtX <= courtWidth - offsetX &&
           courtY >= offsetY && courtY <= courtHeight - offsetY {
            return location
        }
        
        // Otherwise, clamp the location to the visible court bounds
        let adjustedX = max(offsetX, min(courtWidth - offsetX, courtX))
        let adjustedY = max(offsetY, min(courtHeight - offsetY, courtY))
        
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