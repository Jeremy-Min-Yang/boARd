import SwiftUI
import FocusEntity
import RealityKit
import ARKit
import Combine
import ObjectiveC

private var focusEntityKey: UInt8 = 0

extension ARView {
    var focusEntity: FocusEntity? {
        get { objc_getAssociatedObject(self, &focusEntityKey) as? FocusEntity }
        set { objc_setAssociatedObject(self, &focusEntityKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

class ARSessionDelegateDebug: NSObject, ARSessionDelegate {
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("[ARSession] didFailWithError: \(error.localizedDescription)")
    }
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        print("[ARSession] cameraDidChangeTrackingState: \(camera.trackingState)")
    }
    func sessionWasInterrupted(_ session: ARSession) {
        print("[ARSession] sessionWasInterrupted")
    }
    func sessionInterruptionEnded(_ session: ARSession) {
        print("[ARSession] sessionInterruptionEnded")
    }
}

struct ARAnimationData {
    let entity: Entity
    let pathPointsAR: [SIMD3<Float>]
    let totalDistance: Float
    let duration: TimeInterval
    var startTime: Date? = nil
    var isAnimating: Bool = false
}

struct PreparedAREntitiesAndAnimations {
    var animationDataMap: [UUID: ARAnimationData] = [:]
    var playerEntities: [UUID: ModelEntity] = [:]
    var basketballEntities: [UUID: ModelEntity] = [:]
    var basketballPlayerAssignments: [UUID: UUID] = [:]
}

struct ARPlayView: UIViewRepresentable {
    let play: Models.SavedPlay
    @Binding var shouldStartAnimationBinding: Bool

    @State private var arViewInstance: ARView? 
    @State private var isCourtPlaced: Bool = false
    @State private var showPlacementButton: Bool = true  // New: Controls visibility of placement button
    @State private var previewAnchor: AnchorEntity? = nil
    @State private var previewCourtEntity: ModelEntity? = nil

    private let coachingOverlay = ARCoachingOverlayView()

    static let walkingSpeed: Float = 0.2 // meters per second (adjust as needed)

    func makeUIView(context: Context) -> ARView {
        print("[ARPlayView] makeUIView called")
        let arView = ARView(frame: .zero)
        setupCoachingOverlay(for: arView, context: context)
        arView.session.delegate = context.coordinator
        self.arViewInstance = arView

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        arView.session.run(config)
        print("[ARPlayView] AR session run with plane detection: \(config.planeDetection), sceneReconstruction: \(config.sceneReconstruction)")

        // Set up focus entity for preview and attach to ARView
        let focus = FocusEntity(on: arView, focus: .classic)
        arView.focusEntity = focus
        focus.isEnabled = true

        showPlacementButton = true // Ensure the button always appears when AR view opens

        // --- PREVIEW COURT LOGIC ---
        do {
            let previewAnchor = AnchorEntity(world: .zero)
            let courtEntity = try ModelEntity.loadModel(named: "hoop_court")
            // Make all materials transparent
            if let modelComponent = courtEntity.model {
                let transparentMaterial = SimpleMaterial(color: .white.withAlphaComponent(0.5), isMetallic: false)
                let materialCount = modelComponent.materials.count
                courtEntity.model?.materials = Array(repeating: transparentMaterial, count: max(1, materialCount))
            }
            courtEntity.scale = [0.0008, 0.0008, 0.0008]
            courtEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
            previewAnchor.addChild(courtEntity)
            arView.scene.addAnchor(previewAnchor)
            self.previewAnchor = previewAnchor
            self.previewCourtEntity = courtEntity
            print("[ARPlayView] Preview court entity loaded and added to previewAnchor.")
        } catch {
            print("[ARPlayView] ERROR loading preview court: \(error.localizedDescription)")
        }
        // Subscribe to scene updates to move preview with FocusEntity
        arView.scene.subscribe(to: SceneEvents.Update.self) { [weak arView] _ in
            guard let arView = arView, let focus = arView.focusEntity, let previewAnchor = self.previewAnchor else { return }
            previewAnchor.transform = Transform(matrix: focus.transformMatrix(relativeTo: nil))
        }
        // --- END PREVIEW COURT LOGIC ---

        // Set up scene update subscription for animations
        context.coordinator.setupSceneUpdatesSubscription(arView: arView)
        print("[ARPlayView] Scene update subscription set up")

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        coachingOverlay.frame = uiView.bounds
        context.coordinator.currentContext = context // Ensure coordinator has latest context
        
        // Remove any existing Place Court buttons to avoid stacking
        uiView.subviews.compactMap { $0 as? UIButton }.forEach { $0.removeFromSuperview() }
        
        // Add placement button if court is not placed
        if showPlacementButton {
            let button = UIButton(type: .system)
            button.setTitle("Place Court", for: .normal)
            button.backgroundColor = .white
            button.setTitleColor(.black, for: .normal)
            button.layer.cornerRadius = 20
            // Move to lower left
            button.frame = CGRect(
                x: 20, // 20pt from the left
                y: uiView.bounds.height - 80, // 80pt from the bottom
                width: 160,
                height: 50
            )
            button.addTarget(context.coordinator, action: #selector(Coordinator.placeCourtButtonTapped), for: .touchUpInside)
            uiView.addSubview(button)
        }
        
        if shouldStartAnimationBinding {
            print("[ARPlayView updateUIView] shouldStartAnimationBinding is true. Calling startAnimations.")
            print("[ARPlayView updateUIView] Number of animations in map: \(context.coordinator.animationDataMap.count)")
            for (id, data) in context.coordinator.animationDataMap {
                print("[ARPlayView updateUIView] Animation data for \(id): points=\(data.pathPointsAR.count), duration=\(data.duration)")
            }
            
            // Ensure scene update subscription is active
            if context.coordinator.sceneUpdateSubscription == nil {
                print("[ARPlayView updateUIView] Re-establishing scene update subscription")
                context.coordinator.setupSceneUpdatesSubscription(arView: uiView)
            }
            
            startAnimations(arView: uiView, context: context) 
            DispatchQueue.main.async {
                self.shouldStartAnimationBinding = false
            }
        }
    }

    func setupCoachingOverlay(for arView: ARView, context: Context) {
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coachingOverlay)
        coachingOverlay.goal = .horizontalPlane 
        coachingOverlay.session = arView.session
        coachingOverlay.delegate = context.coordinator 
    }

    // Made static
    static func prepareAnimationData(play: Models.SavedPlay, courtSize: CGSize, arCourtWidth: Float, arCourtHeight: Float, courtAnchor: AnchorEntity) -> PreparedAREntitiesAndAnimations {
        var preparedResult = PreparedAREntitiesAndAnimations()
        print("[ARPlayView prepareAnimationData] Processing play: \(play.name) (ID: \(play.id))")
        print("[ARPlayView prepareAnimationData] Number of players: \(play.players.count), Balls: \(play.balls.count)")

        for (index, player) in play.players.enumerated() {
            print("[ARPlayView prepareAnimationData] Player [\(index)] details: ID \(player.id), Num \(player.number), Pos \(player.position.cgPoint), PathID \(player.assignedPathId?.uuidString ?? "None")")
            
            let playerEntity: ModelEntity
            do {
                playerEntity = try ModelEntity.loadModel(named: "cylinder")
                playerEntity.scale = [0.0005, 0.0005, 0.0005]
                let isOpponent = player.number > 5
                let material = SimpleMaterial(color: isOpponent ? .red : .green, isMetallic: false)
                if let modelComponent = playerEntity.model {
                    playerEntity.model?.materials = [material]
                }
                print("[ARPlayView prepareAnimationData] Successfully loaded 'cylinder.usdz' for player \(player.id)")
            } catch {
                print("[ARPlayView prepareAnimationData] ERROR loading 'cylinder.usdz': \(error.localizedDescription). Using default sphere.")
                let isOpponent = player.number > 5
                playerEntity = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.02),
                                           materials: [SimpleMaterial(color: isOpponent ? .red : .green, isMetallic: false)])
            }
            // Add number label as 3D text above the cylinder (debug: make it very large and bold)
            let textMesh = MeshResource.generateText(
                "\(player.number)",
                extrusionDepth: 0.01, // Much thicker
                font: .systemFont(ofSize: 0.4, weight: .bold), // Much larger and bold
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
            let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
            textEntity.position = SIMD3<Float>(0, 0.04, 0)
            textEntity.setScale(SIMD3<Float>(repeating: 1.0), relativeTo: nil) // Make text even larger
            // Try different orientations (comment/uncomment as needed)
            // textEntity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            // textEntity.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
            playerEntity.addChild(textEntity)
            print("Added text label \(player.number) to player \(player.id)")
            print("Children of playerEntity after adding text:", playerEntity.children)
            // Add a debug sphere above the cylinder to verify child visibility
            let debugSphere = ModelEntity(mesh: .generateSphere(radius: 0.01), materials: [SimpleMaterial(color: .yellow, isMetallic: false)])
            debugSphere.position = SIMD3<Float>(0, 0.06, 0)
            playerEntity.addChild(debugSphere)
            print("Added debug sphere above player \(player.id)")
            print("Children of playerEntity after adding debug sphere:", playerEntity.children)
            
            let initialPosAR = ARPlayView.rotate180Y(
                ARPlayView.map2DToAR(player.position.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight)
            )
            playerEntity.position = initialPosAR
            playerEntity.name = "player_\(player.id)"
            courtAnchor.addChild(playerEntity)
            preparedResult.playerEntities[player.id] = playerEntity

            if let pathId = player.assignedPathId,
               let drawingData = play.drawings.first(where: { $0.id == pathId }) {
                print("[ARPlayView prepareAnimationData] Found path for player \(player.id):")
                print("  - Path points count: \(drawingData.points.count)")
                print("  - Path type: \(drawingData.type)")
                
                let arPathPoints = drawingData.points.map { ARPlayView.map2DToAR($0.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight) }
                print("  - Converted to AR points: \(arPathPoints.count)")
                
                let rotatedPathPoints = arPathPoints.map { ARPlayView.rotate180Y($0) }
                print("  - Rotated points: \(rotatedPathPoints.count)")
                
                var animationPathPointsAR = rotatedPathPoints.count >= 2 && drawingData.type == DrawingTool.arrow.rawValue ? [rotatedPathPoints.first!, rotatedPathPoints.last!] : rotatedPathPoints
                print("  - Final animation points: \(animationPathPointsAR.count)")

                if !animationPathPointsAR.isEmpty {
                    let totalDistance = ARPlayView.calculateARPathLength(points: animationPathPointsAR)
                    let duration = TimeInterval(totalDistance / ARPlayView.walkingSpeed)
                    print("[ARPlayView prepAnim] Player \(player.id):")
                    print("  - PathID: \(pathId)")
                    print("  - Points: \(animationPathPointsAR.count)")
                    print("  - Distance: \(totalDistance)")
                    print("  - Duration: \(duration)")
                    
                    preparedResult.animationDataMap[player.id] = ARAnimationData(
                        entity: playerEntity,
                        pathPointsAR: animationPathPointsAR,
                        totalDistance: totalDistance,
                        duration: max(0.1, duration)
                    )
                    playerEntity.position = animationPathPointsAR.first ?? initialPosAR
                    print("  - Initial position set to: \(playerEntity.position)")
                } else {
                    print("[ARPlayView prepareAnimationData] Warning: No valid animation points for player \(player.id)")
                }
            } else {
                print("[ARPlayView prepareAnimationData] No path assigned for player \(player.id)")
            }
            print("playerEntity scale:", playerEntity.scale)
            print("textEntity scale:", textEntity.scale)
            print("debugSphere scale:", debugSphere.scale)
        }
        for (index, ballData) in play.balls.enumerated() {
            print("[ARPlayView prepareAnimationData] Ball [\(index)] details: ID \(ballData.id), " +
                  "Pos \(ballData.position.cgPoint), PathID \(ballData.assignedPathId?.uuidString ?? "None"), " +
                  "PlayerID \(ballData.assignedPlayerId?.uuidString ?? "None")")

            let ballEntity: ModelEntity
            do {
                ballEntity = try ModelEntity.loadModel(named: "ball")
                ballEntity.scale = [0.0015, 0.0015, 0.0015]
                print("[ARPlayView prepareAnimationData] Successfully loaded 'ball.usdz' for ball \(ballData.id)")
            } catch {
                print("[ARPlayView prepareAnimationData] ERROR loading 'ball.usdz': \(error.localizedDescription). Using default orange sphere.")
                let ballMaterial = SimpleMaterial(color: .orange, isMetallic: false)
                ballEntity = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.015),
                                         materials: [ballMaterial])
            }

            let initialPosAR = ARPlayView.rotate180Y(
                ARPlayView.map2DToARBall(ballData.position.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight)
            )
            ballEntity.position = initialPosAR
            ballEntity.name = "ball_\(ballData.id)"
            courtAnchor.addChild(ballEntity)
            preparedResult.basketballEntities[ballData.id] = ballEntity

            if let assignedPlayerID = ballData.assignedPlayerId {
                preparedResult.basketballPlayerAssignments[ballData.id] = assignedPlayerID
                print("[ARPlayView prepareAnimationData] Ball \(ballData.id) is ASSIGNED to player \(assignedPlayerID). It will follow the player.")
            } else if let pathId = ballData.assignedPathId,
                      let drawingData = play.drawings.first(where: { $0.id == pathId }) {
                let arPathPoints = drawingData.points.map { ARPlayView.map2DToARBall($0.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight) }
                let rotatedPathPoints = arPathPoints.map { ARPlayView.rotate180Y($0) }
                var animationPathPointsAR = rotatedPathPoints.count >= 2 && drawingData.type == DrawingTool.arrow.rawValue ? [rotatedPathPoints.first!, rotatedPathPoints.last!] : rotatedPathPoints

                if !animationPathPointsAR.isEmpty {
                    let totalDistance = ARPlayView.calculateARPathLength(points: animationPathPointsAR)
                    let duration = TimeInterval(totalDistance / ARPlayView.walkingSpeed)
                    print("[ARPlayView prepAnim] Ball \(ballData.id): PathID \(pathId), Points \(animationPathPointsAR.count), Dist \(totalDistance), Dur \(duration)")
                    preparedResult.animationDataMap[ballData.id] = ARAnimationData(entity: ballEntity, pathPointsAR: animationPathPointsAR, totalDistance: totalDistance, duration: max(0.1, duration))
                    ballEntity.position = animationPathPointsAR.first ?? initialPosAR
                }
            }
        }
        // At the end of prepareAnimationData, add a floating debug sphere directly to courtAnchor
        let floatingSphere = ModelEntity(mesh: .generateSphere(radius: 0.02), materials: [SimpleMaterial(color: .red, isMetallic: false)])
        floatingSphere.position = SIMD3<Float>(0, 0.1, 0) // Well above the court
        courtAnchor.addChild(floatingSphere)
        print("Added floating debug sphere to courtAnchor")
        // Print the full scene hierarchy for courtAnchor
        print("=== Scene Hierarchy for courtAnchor ===")
        for child in courtAnchor.children {
            print("- \(child.name) [\(type(of: child))]")
            for subchild in child.children {
                print("  - \(subchild.name) [\(type(of: subchild))]")
            }
        }
        print("=======================================")
        return preparedResult
    }

    // Added context parameter, uses context.coordinator.animationDataMap
    func startAnimations(arView: ARView, context: Context) { 
        guard !context.coordinator.animationDataMap.isEmpty else {
            print("[ARPlayView startAnimations] No animation data prepared in coordinator.animationDataMap. Count: \(context.coordinator.animationDataMap.count)")
            return
        }
        
        print("[ARPlayView startAnimations] Resetting and starting animations for \(context.coordinator.animationDataMap.count) entities.")
        var didStartAnyAnimation = false
        // Iterate over keys from coordinator's map
        for id in context.coordinator.animationDataMap.keys {
            // Get mutable copy from coordinator's map
            if var animData = context.coordinator.animationDataMap[id] { 
                print("[ARPlayView startAnimations] Processing animation for \(id)")
                print("[ARPlayView startAnimations] Path points: \(animData.pathPointsAR.count)")
                print("[ARPlayView startAnimations] Duration: \(animData.duration)")
                
                animData.isAnimating = false
                animData.startTime = nil
                if let firstPoint = animData.pathPointsAR.first {
                    animData.entity.position = firstPoint
                    print("[ARPlayView startAnimations] Set initial position to: \(firstPoint)")
                } else {
                     print("[ARPlayView startAnimations] Warning - entity \(id) has no path points.")
                }

                if !animData.pathPointsAR.isEmpty && animData.duration > 0 {
                    animData.startTime = Date()
                    animData.isAnimating = true
                    // Write modified struct back to coordinator's map
                    context.coordinator.animationDataMap[id] = animData 
                    didStartAnyAnimation = true
                    print("[ARPlayView startAnimations] Animation effectively started for entity: \(id) at \(animData.startTime!)")
                } else {
                    print("[ARPlayView startAnimations] Skipping animation for \(id): No path or zero duration. PathPoints: \(animData.pathPointsAR.count), Duration: \(animData.duration)")
                }
            }
        }
        if !didStartAnyAnimation {
             print("[ARPlayView startAnimations] All animations were skipped or no valid animation data found.")
        }
    }
    
    // Made static
    static func map2DToAR(_ point: CGPoint, courtSize: CGSize, arCourtWidth: Float, arCourtHeight: Float) -> SIMD3<Float> {
        let xNorm = Float(point.x / courtSize.width)
        let zNorm = Float(point.y / courtSize.height)
        let x = (xNorm - 0.5) * arCourtWidth
        let z = (zNorm - 0.5) * arCourtHeight
        print("[ARPlayView map2DToAR] Converting point: \(point) to AR: (\(x), 0.05, \(z))")
        return SIMD3<Float>(x, 0.05, z)
    }

    // New function specifically for ball positioning
    static func map2DToARBall(_ point: CGPoint, courtSize: CGSize, arCourtWidth: Float, arCourtHeight: Float) -> SIMD3<Float> {
        let xNorm = Float(point.x / courtSize.width)
        let zNorm = Float(point.y / courtSize.height)
        let x = (xNorm - 0.5) * arCourtWidth
        let z = (zNorm - 0.5) * arCourtHeight
        print("[ARPlayView map2DToARBall] Converting point: \(point) to AR: (\(x), 0.001, \(z))")
        return SIMD3<Float>(x, 0.001, z)
    }

    // Made static
    static func calculateARPathLength(points: [SIMD3<Float>]) -> Float {
        guard points.count > 1 else { return 0 }
        var totalDistance: Float = 0
        for i in 0..<(points.count - 1) {
            totalDistance += distance(points[i], points[i+1])
        }
        return totalDistance
    }

    // Made static
    static func getPointOnARPath(points: [SIMD3<Float>], progress: Float) -> SIMD3<Float>? {
        guard !points.isEmpty else { return nil }
        let clampedProgress = max(0.0, min(1.0, progress))
        guard clampedProgress > 0 else { return points.first }
        guard clampedProgress < 1 else { return points.last }
        // Use static version of calculateARPathLength
        let totalLength = ARPlayView.calculateARPathLength(points: points)
        guard totalLength > 0 else { return points.first }
        let targetDistance = totalLength * clampedProgress
        var distanceCovered: Float = 0
        for i in 0..<(points.count - 1) {
            let startPoint = points[i]
            let endPoint = points[i+1]
            let segmentLength = distance(startPoint, endPoint)
            if distanceCovered + segmentLength >= targetDistance {
                let remainingDistance = targetDistance - distanceCovered
                let segmentProgress = remainingDistance / segmentLength
                return simd_mix(startPoint, endPoint, SIMD3<Float>(repeating: segmentProgress))
            }
            distanceCovered += segmentLength
        }
        return points.last
    }

    // Helper to rotate a position 180 degrees around Y axis about the origin
    static func rotate180Y(_ pos: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3<Float>(-pos.x, pos.y, -pos.z)
    }

    class Coordinator: NSObject, ARCoachingOverlayViewDelegate, ARSessionDelegate {
        var parent: ARPlayView
        var sceneUpdateSubscription: Cancellable?
        var animationDataMap: [UUID: ARAnimationData] = [:]
        var currentContext: Context?

        var playerEntities: [UUID: ModelEntity] = [:]
        var basketballEntities: [UUID: ModelEntity] = [:]
        var basketballPlayerAssignments: [UUID: UUID] = [:]

        init(_ parent: ARPlayView) {
            self.parent = parent
            super.init()
        }

        func updateScene(event: SceneEvents.Update) {
            var allAnimationsFinishedThisFrame = true
            let currentTime = Date()

            // Update entities based on path animations
            for id in self.animationDataMap.keys {
                guard var animData = self.animationDataMap[id], animData.isAnimating, let startTime = animData.startTime else {
                    if self.animationDataMap[id]?.isAnimating == true && self.animationDataMap[id]?.startTime == nil {
                        print("[ARPlayView Update] Warning: Animation for \(id) is marked isAnimating but has no start time.")
                    }
                    continue
                }
                
                allAnimationsFinishedThisFrame = false

                let elapsedTime = currentTime.timeIntervalSince(startTime)
                var progress = Float(elapsedTime / animData.duration)
                // print("[ARPlayView Update] Entity \(id) - Progress: \(progress), Elapsed: \(elapsedTime), Duration: \(animData.duration)") // Verbose

                if progress >= 1.0 {
                    progress = 1.0
                    animData.isAnimating = false
                    // print("[ARPlayView Update] Animation finished for entity: \(id). Final Position: \(animData.entity.position)")
                }

                if let newPosition = ARPlayView.getPointOnARPath(points: animData.pathPointsAR, progress: progress) {
                    animData.entity.position = newPosition
                    // print("[ARPlayView Update] Updated position for \(id) to: \(newPosition)")
                } else {
                    // print("[ARPlayView Update] Warning: Could not get point on path for entity \(id) at progress \(progress)")
                }
                self.animationDataMap[id] = animData
            }

            // Update basketballs assigned to players
            for (ballID, playerID) in self.basketballPlayerAssignments {
                guard let ballEntity = self.basketballEntities[ballID],
                      let playerEntity = self.playerEntities[playerID] else {
                    print("[ARPlayView Update] Warning: Could not find ball or player entity for assignment: BallID \(ballID), PlayerID \(playerID)")
                    continue
                }
                
                // Match ball position to player position (relative to the common courtAnchor)
                // Add a slight Y offset so the ball appears near the player's feet or held.
                var ballTargetPosition = playerEntity.position
                ballTargetPosition.y += 0.02 // Adjust this offset as needed for visual appearance
                ballEntity.position = ballTargetPosition
                print("[ARPlayView Update] Updated ball \(ballID) position to follow player \(playerID) at \(ballTargetPosition)")
            }
        }
        
        func setupSceneUpdatesSubscription(arView: ARView) {
            // Cancel any existing subscription
            sceneUpdateSubscription?.cancel()
            
            // Create new subscription
            sceneUpdateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
                self?.updateScene(event: event)
            }
            print("[ARPlayView Coordinator] Subscribed to scene updates.")
        }
        
        deinit {
            sceneUpdateSubscription?.cancel()
            print("[ARPlayView Coordinator] Unsubscribed from scene updates.")
        }
        
        // MARK: - ARCoachingOverlayViewDelegate
        func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
            print("[ARPlayView Coordinator] Coaching overlay will activate.")
        }

        func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
            print("[ARPlayView Coordinator] Coaching overlay did deactivate. AR environment should be ready. Waiting for play button.")
        }

        func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
            print("[ARPlayView Coordinator] Coaching overlay requested session reset.")
        }
        
        // MARK: - ARSessionDelegate
        func session(_ session: ARSession, didFailWithError error: Error) {
            print("[ARSession Coordinator] didFailWithError: \(error.localizedDescription)")
        }
        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            print("[ARSession Coordinator] cameraDidChangeTrackingState: \(camera.trackingState)")
        }
        func sessionWasInterrupted(_ session: ARSession) {
            print("[ARSession Coordinator] sessionWasInterrupted. Current tracking state: \(session.currentFrame?.camera.trackingState)")
        }
        func sessionInterruptionEnded(_ session: ARSession) {
            print("[ARSession Coordinator] sessionInterruptionEnded. Restarting coaching if needed, then animations.")
            if let arView = parent.arViewInstance {
                if parent.coachingOverlay.isActive {
                    print("[ARSession Coordinator] Coaching overlay is active after interruption ended, animations will start when it deactivates.")
                }
            }
        }

        @objc func placeCourtButtonTapped() {
            print("[ARPlayView] Place Court button tapped")
            if let arView = parent.arViewInstance {
                parent.placeCourtAtPreviewPosition(arView: arView, context: currentContext!)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    // Place only the hoop_court at the given position
    func placeCourtOnly(at position: SIMD3<Float>, arView: ARView) -> AnchorEntity? {
        print("[ARPlayView] placeCourtOnly called with position: \(position)")
        let courtEntity: ModelEntity
        do {
            print("[ARPlayView] Attempting to load 'hoop_court.usdz' from bundle...")
            courtEntity = try ModelEntity.loadModel(named: "hoop_court")
            courtEntity.scale = [0.0008, 0.0008, 0.0008]
            courtEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
            print("[ARPlayView] Successfully loaded 'hoop_court.usdz' for the court and scaled it. Scale: \(courtEntity.scale)")
        } catch {
            print("[ARPlayView] ERROR loading 'hoop_court.usdz': \(error.localizedDescription). Falling back to default yellow plane.")
            let courtSize = self.play.courtTypeEnum.virtualCourtSize
            let arCourtWidthFallback: Float = 0.3 
            let arCourtHeightFallback: Float = 0.3 * Float(courtSize.height / courtSize.width)
            let courtMesh = MeshResource.generatePlane(width: arCourtWidthFallback, depth: arCourtHeightFallback)
            let courtMaterial = SimpleMaterial(color: .yellow, isMetallic: false)
            courtEntity = ModelEntity(mesh: courtMesh, materials: [courtMaterial])
        }
        courtEntity.generateCollisionShapes(recursive: true)
        let courtAnchor = AnchorEntity(world: position)
        print("[ARPlayView] Created courtAnchor at position: \(position)")
        courtAnchor.addChild(courtEntity)
        print("[ARPlayView] Added courtEntity as child to courtAnchor.")
        arView.scene.addAnchor(courtAnchor)
        print("[ARPlayView] Added courtAnchor to arView.scene. Scene anchors now: \(arView.scene.anchors.count)")
        print("[ARPlayView] Court placement complete.")
        return courtAnchor
    }

    func placeCourtAtPreviewPosition(arView: ARView, context: Context) {
        print("[ARPlayView] placeCourtAtPreviewPosition called")
        guard let focusEntity = arView.focusEntity else {
            print("[ARPlayView] FocusEntity is nil, cannot place court.")
            return
        }
        guard focusEntity.onPlane else {
            print("[ARPlayView] FocusEntity is not tracking a surface. Placement not allowed.")
            return
        }
        let focusPosition = focusEntity.position
        print("[ARPlayView] Placing court at focus position: \(focusPosition)")
        
        // Remove preview before placing real court
        if let previewAnchor = self.previewAnchor {
            arView.scene.removeAnchor(previewAnchor)
            self.previewAnchor = nil
            self.previewCourtEntity = nil
            print("[ARPlayView] Preview court removed from scene.")
        }

        // Place the court model and get the anchor it's on
        guard let courtAnchor = placeCourtOnly(at: focusPosition, arView: arView) else {
            print("[ARPlayView placeCourtAtPreviewPosition] Failed to place court model.")
            return
        }

        // Now prepare and add other entities (players, balls) to this courtAnchor
        // and set up animation data in the coordinator.
        let courtSize = self.play.courtTypeEnum.virtualCourtSize
        // Define AR court dimensions consistently (can be constants or calculated as needed)
        let arCourtWidth: Float = 0.3 
        let arCourtHeight: Float = arCourtWidth * Float(courtSize.height / courtSize.width) 

        let preparedResult = ARPlayView.prepareAnimationData(
            play: self.play, 
            courtSize: courtSize, 
            arCourtWidth: arCourtWidth, 
            arCourtHeight: arCourtHeight, 
            courtAnchor: courtAnchor
        )

        context.coordinator.animationDataMap = preparedResult.animationDataMap
        context.coordinator.playerEntities = preparedResult.playerEntities
        context.coordinator.basketballEntities = preparedResult.basketballEntities
        context.coordinator.basketballPlayerAssignments = preparedResult.basketballPlayerAssignments

        print("[ARPlayView placeCourtAtPreviewPosition] Prepared and assigned entities to coordinator:")
        print("  - AnimationDataMap count: \(context.coordinator.animationDataMap.count)")
        print("  - PlayerEntities count: \(context.coordinator.playerEntities.count)")
        print("  - BasketballEntities count: \(context.coordinator.basketballEntities.count)")
        print("  - BasketballPlayerAssignments count: \(context.coordinator.basketballPlayerAssignments.count)")

        arView.setNeedsLayout() // Not typically needed for RealityKit scene changes
        arView.setNeedsDisplay() // Not typically needed for RealityKit scene changes
        isCourtPlaced = true
        showPlacementButton = false
        // Disable focus entity after placement
        arView.focusEntity?.isEnabled = false
        arView.focusEntity = nil
    }
}

// Usage in SwiftUI:
// NavigationLink(destination: ARPlayView(play: selectedPlay)) { Text("View in AR") } 

// Add exit button support
struct ARPlayViewWrapper: View {
    @Environment(\.presentationMode) var presentationMode
    let play: Models.SavedPlay
    @State private var shouldStartAnimationBinding = false
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ARPlayView(play: play, shouldStartAnimationBinding: $shouldStartAnimationBinding)
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.white)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .padding()
            }
        }
    }
}

