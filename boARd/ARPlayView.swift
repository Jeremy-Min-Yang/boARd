import SwiftUI
import RealityKit
import ARKit
import Combine

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

struct ARPlayView: UIViewRepresentable {
    let play: Models.SavedPlay
    @Binding var shouldStartAnimationBinding: Bool

    @State private var arViewInstance: ARView? 
    // animationDataMap is now in the Coordinator

    private let coachingOverlay = ARCoachingOverlayView()

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

        let courtSize = play.courtTypeEnum.virtualCourtSize
        let arCourtWidth: Float = 1.0
        let arCourtHeight: Float = Float(courtSize.height / courtSize.width)

        // Load the hoop_court.usdz model instead of creating a plane
        let courtEntity: ModelEntity
        do {
            courtEntity = try ModelEntity.loadModel(named: "hoop_court")
            // Scale the court entity to a reasonable size
            courtEntity.scale = [0.001, 0.001, 0.001] // Adjusted scale to 0.001
            // Rotate the court 90 degrees around Y axis
            courtEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
            print("[ARPlayView] Successfully loaded 'hoop_court.usdz' for the court and scaled it.")
        } catch {
            print("[ARPlayView] ERROR loading 'hoop_court.usdz': \(error.localizedDescription). Falling back to default yellow plane.")
            let courtMesh = MeshResource.generatePlane(width: arCourtWidth, depth: arCourtHeight)
            let courtMaterial = SimpleMaterial(color: .yellow, isMetallic: false)
            courtEntity = ModelEntity(mesh: courtMesh, materials: [courtMaterial])
        }
        courtEntity.generateCollisionShapes(recursive: true)

        // Create separate anchors for court and players/basketballs
        let courtAnchor = AnchorEntity(plane: .horizontal)
        let playersAnchor = AnchorEntity(plane: .horizontal)
        
        // First place the court
        courtAnchor.addChild(courtEntity)
        courtEntity.position = [0,0,0]
        arView.scene.addAnchor(courtAnchor)
        
        // Then place the players and basketballs
        arView.scene.addAnchor(playersAnchor)
        print("[ARPlayView] Court (hoop_court.usdz) and anchors added to scene.")
        
        // Prepare animation data and store it in the coordinator
        context.coordinator.animationDataMap = ARPlayView.prepareAnimationData(
            play: self.play,
            courtSize: courtSize, 
            arCourtWidth: arCourtWidth, 
            arCourtHeight: arCourtHeight, 
            courtAnchor: playersAnchor  // Pass playersAnchor instead of courtAnchor
        )
        print("[ARPlayView] Prepared animation data for \(context.coordinator.animationDataMap.count) entities (in makeUIView, stored in coordinator).")

        DispatchQueue.main.async {
            context.coordinator.setupSceneUpdatesSubscription(arView: arView)
            print("[ARPlayView] Scene update subscription set up. Animations will wait for trigger.")
        }
        
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        coachingOverlay.frame = uiView.bounds
        if shouldStartAnimationBinding {
            print("[ARPlayView updateUIView] shouldStartAnimationBinding is true. Calling startAnimations.")
            // Pass context to startAnimations
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
    static func prepareAnimationData(play: Models.SavedPlay, courtSize: CGSize, arCourtWidth: Float, arCourtHeight: Float, courtAnchor: AnchorEntity) -> [UUID: ARAnimationData] {
        var tempAnimationDataMap: [UUID: ARAnimationData] = [:]
        print("[ARPlayView prepareAnimationData] Processing play: \(play.name) (ID: \(play.id))")
        print("[ARPlayView prepareAnimationData] Number of players: \(play.players.count), Basketballs: \(play.basketballs.count)")

        for (index, player) in play.players.enumerated() {
            print("[ARPlayView prepareAnimationData] Player [\(index)] details: ID \(player.id), Num \(player.number), Pos \(player.position.cgPoint), PathID \(player.assignedPathId?.uuidString ?? "None")")
            
            let playerEntity: ModelEntity
            do {
                // Try to load the cylinder model
                playerEntity = try ModelEntity.loadModel(named: "cylinder")
                // Scale the cylinder to match the court scale
                playerEntity.scale = [0.0005, 0.0005, 0.0005]
                print("[ARPlayView prepareAnimationData] Successfully loaded 'cylinder.usdz' for player \(player.id)")
            } catch {
                print("[ARPlayView prepareAnimationData] ERROR loading 'cylinder.usdz': \(error.localizedDescription). Using default green sphere.")
                // Fallback to a sphere if loading fails
                playerEntity = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.02),
                                           materials: [SimpleMaterial(color: .green, isMetallic: false)])
            }
            
            // Use static version of map2DToAR
            let initialPosAR = ARPlayView.rotate180Y(
                ARPlayView.map2DToAR(player.position.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight)
            )
            playerEntity.position = initialPosAR
            playerEntity.name = "player_\(player.id)"
            courtAnchor.addChild(playerEntity)

            if let pathId = player.assignedPathId,
               let drawingData = play.drawings.first(where: { $0.id == pathId }) {
                // Use static version of map2DToAR
                let arPathPoints = drawingData.points.map { ARPlayView.map2DToAR($0.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight) }
                let rotatedPathPoints = arPathPoints.map { ARPlayView.rotate180Y($0) }
                var animationPathPointsAR = rotatedPathPoints.count >= 2 && drawingData.type == DrawingTool.arrow.rawValue ? [rotatedPathPoints.first!, rotatedPathPoints.last!] : rotatedPathPoints

                if !animationPathPointsAR.isEmpty {
                    // Use static version of calculateARPathLength
                    let totalDistance = ARPlayView.calculateARPathLength(points: animationPathPointsAR)
                    let duration = TimeInterval(totalDistance / ( (275.0 / Float(courtSize.width)) * arCourtWidth ))
                    print("[ARPlayView prepAnim] Player \(player.id): PathID \(pathId), Points \(animationPathPointsAR.count), Dist \(totalDistance), Dur \(duration)")
                    tempAnimationDataMap[player.id] = ARAnimationData(entity: playerEntity, pathPointsAR: animationPathPointsAR, totalDistance: totalDistance, duration: max(0.1, duration))
                    playerEntity.position = animationPathPointsAR.first ?? initialPosAR
                }
            }
        }
        for (index, ballData) in play.basketballs.enumerated() {
            print("[ARPlayView prepareAnimationData] Ball [\(index)] details: ID \(ballData.id), Pos \(ballData.position.cgPoint), PathID \(ballData.assignedPathId?.uuidString ?? "None")")

            let ballEntity: ModelEntity
            do {
                // Try to load the custom basketball model
                ballEntity = try ModelEntity.loadModel(named: "ball")
                // Scale the ball to match the court scale
                ballEntity.scale = [0.001, 0.001, 0.001]
                print("[ARPlayView prepareAnimationData] Successfully loaded 'ball.usdz' for ball \(ballData.id)")
            } catch {
                print("[ARPlayView prepareAnimationData] ERROR loading 'ball.usdz': \(error.localizedDescription). Using default orange sphere.")
                // Fallback to a sphere if loading fails
                ballEntity = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.015),
                                         materials: [SimpleMaterial(color: .orange, isMetallic: false)])
            }

            // Use static version of map2DToAR
            let initialPosAR = ARPlayView.rotate180Y(
                ARPlayView.map2DToAR(ballData.position.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight)
            )
            ballEntity.position = initialPosAR
            ballEntity.name = "ball_\(ballData.id)"
            courtAnchor.addChild(ballEntity)
            if let pathId = ballData.assignedPathId,
               let drawingData = play.drawings.first(where: { $0.id == pathId }) {
                // Use static version of map2DToAR
                let arPathPoints = drawingData.points.map { ARPlayView.map2DToAR($0.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight) }
                let rotatedPathPoints = arPathPoints.map { ARPlayView.rotate180Y($0) }
                var animationPathPointsAR = rotatedPathPoints.count >= 2 && drawingData.type == DrawingTool.arrow.rawValue ? [rotatedPathPoints.first!, rotatedPathPoints.last!] : rotatedPathPoints

                if !animationPathPointsAR.isEmpty {
                    // Use static version of calculateARPathLength
                    let totalDistance = ARPlayView.calculateARPathLength(points: animationPathPointsAR)
                    let duration = TimeInterval(totalDistance / ( (275.0 / Float(courtSize.width)) * arCourtWidth ))
                     print("[ARPlayView prepAnim] Ball \(ballData.id): PathID \(pathId), Points \(animationPathPointsAR.count), Dist \(totalDistance), Dur \(duration)")
                    tempAnimationDataMap[ballData.id] = ARAnimationData(entity: ballEntity, pathPointsAR: animationPathPointsAR, totalDistance: totalDistance, duration: max(0.1, duration))
                    ballEntity.position = animationPathPointsAR.first ?? initialPosAR
                }
            }
        }
        return tempAnimationDataMap
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
                animData.isAnimating = false
                animData.startTime = nil
                if let firstPoint = animData.pathPointsAR.first {
                    animData.entity.position = firstPoint
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
        return SIMD3<Float>(x, 0.01, z)
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
        // Moved animationDataMap here
        var animationDataMap: [UUID: ARAnimationData] = [:]

        init(_ parent: ARPlayView) {
            self.parent = parent
            super.init()
        }

        func updateScene(event: SceneEvents.Update) {
            var allAnimationsFinishedThisFrame = true
            let currentTime = Date()

            // Access animationDataMap directly (self.animationDataMap)
            for id in self.animationDataMap.keys {
                // Get mutable copy from self.animationDataMap
                guard var animData = self.animationDataMap[id], animData.isAnimating, let startTime = animData.startTime else {
                    if self.animationDataMap[id]?.isAnimating == true && self.animationDataMap[id]?.startTime == nil {
                        print("[ARPlayView Update] Warning: Animation for \(id) is marked isAnimating but has no start time.")
                    }
                    continue
                }
                
                allAnimationsFinishedThisFrame = false

                let elapsedTime = currentTime.timeIntervalSince(startTime)
                var progress = Float(elapsedTime / animData.duration)

                if progress >= 1.0 {
                    progress = 1.0
                    animData.isAnimating = false
                    print("[ARPlayView Update] Animation finished for entity: \(id). Final Position: \(animData.entity.position)")
                }

                // Use static ARPlayView.getPointOnARPath
                if let newPosition = ARPlayView.getPointOnARPath(points: animData.pathPointsAR, progress: progress) {
                    animData.entity.position = newPosition
                } else {
                    print("[ARPlayView Update] Warning: Could not get point on path for entity \(id) at progress \(progress)")
                }
                // Write modified struct back to self.animationDataMap
                self.animationDataMap[id] = animData
            }
        }
        
        func setupSceneUpdatesSubscription(arView: ARView) {
            sceneUpdateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self, self.updateScene)
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
            if let arView = parent.arViewInstance { // arViewInstance is still on parent (ARPlayView)
                if parent.coachingOverlay.isActive {
                    print("[ARSession Coordinator] Coaching overlay is active after interruption ended, animations will start when it deactivates.")
                } else {
                    // Potentially re-trigger animations if state implies they should be playing.
                    // This might require more sophisticated state management.
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
}

// Usage in SwiftUI:
// NavigationLink(destination: ARPlayView(play: selectedPlay)) { Text("View in AR") } 
