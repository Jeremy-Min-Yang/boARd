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
        #if DEBUG
        print("[ARSession] didFailWithError: \(error.localizedDescription)")
        #endif
    }
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        #if DEBUG
        print("[ARSession] cameraDidChangeTrackingState: \(camera.trackingState)")
        #endif
    }
    func sessionWasInterrupted(_ session: ARSession) {
        #if DEBUG
        print("[ARSession] sessionWasInterrupted")
        #endif
    }
    func sessionInterruptionEnded(_ session: ARSession) {
        #if DEBUG
        print("[ARSession] sessionInterruptionEnded")
        #endif
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

private let placeCourButtonTag = 999

struct ARPlayView: UIViewRepresentable {
    let play: Models.SavedPlay
    @Binding var shouldStartAnimationBinding: Bool

    @State private var arViewInstance: ARView?
    @State private var isCourtPlaced: Bool = false
    @State private var showPlacementButton: Bool = true
    @State private var previewAnchor: AnchorEntity? = nil
    @State private var previewCourtEntity: ModelEntity? = nil

    private let coachingOverlay = ARCoachingOverlayView()

    static let walkingSpeed: Float = 0.2

    var courtModelConfig: (modelName: String, scale: Float) {
        switch play.courtTypeEnum {
        case .full, .half:
            return ("basketballCourt", 0.034)
        case .soccer:
            return ("soccerfield", 0.008)
        case .football:
            return ("footballField", 0.008)
        }
    }

    func makeUIView(context: Context) -> ARView {
        #if DEBUG
        print("[ARPlayView] makeUIView called")
        #endif
        let arView = ARView(frame: .zero)

        // Disable expensive render features for better performance on older devices
        arView.renderOptions = [
            .disableMotionBlur,
            .disableDepthOfField,
            .disableGroundingShadows,
            .disableHDR,
            .disableCameraGrain
        ]

        setupCoachingOverlay(for: arView, context: context)
        arView.session.delegate = context.coordinator
        self.arViewInstance = arView

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        // Scene reconstruction disabled — expensive on older iPads and not needed for placement
        arView.session.run(config)
        #if DEBUG
        print("[ARPlayView] AR session run with plane detection: \(config.planeDetection)")
        #endif

        let focus = FocusEntity(on: arView, focus: .classic)
        arView.focusEntity = focus
        focus.isEnabled = true

        showPlacementButton = true

        // --- PREVIEW COURT LOGIC ---
        do {
            let previewAnchor = AnchorEntity(world: .zero)
            let (previewModelName, previewModelScale) = self.courtModelConfig
            let courtEntity = try ModelEntity.loadModel(named: previewModelName)
            if let modelComponent = courtEntity.model {
                let transparentMaterial = SimpleMaterial(color: .white.withAlphaComponent(0.5), isMetallic: false)
                let materialCount = modelComponent.materials.count
                courtEntity.model?.materials = Array(repeating: transparentMaterial, count: max(1, materialCount))
            }
            courtEntity.scale = SIMD3<Float>(repeating: previewModelScale)
            courtEntity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            #if DEBUG
            let previewBounds = courtEntity.visualBounds(relativeTo: nil)
            print("[COMPARE][Preview] 3D '\(previewModelName)' extents (x,z): (\(previewBounds.extents.x), \(previewBounds.extents.z)) aspect z/x=\(previewBounds.extents.z / max(0.0001, previewBounds.extents.x))")
            #endif
            previewAnchor.addChild(courtEntity)
            arView.scene.addAnchor(previewAnchor)
            self.previewAnchor = previewAnchor
            self.previewCourtEntity = courtEntity
            #if DEBUG
            print("[ARPlayView] Preview court entity loaded and added to previewAnchor.")
            #endif
        } catch {
            #if DEBUG
            print("[ARPlayView] ERROR loading preview court: \(error.localizedDescription)")
            #endif
        }
        arView.scene.subscribe(to: SceneEvents.Update.self) { [weak arView] _ in
            guard let arView = arView, let focus = arView.focusEntity, let previewAnchor = self.previewAnchor else { return }
            previewAnchor.transform = Transform(matrix: focus.transformMatrix(relativeTo: nil))
        }
        // --- END PREVIEW COURT LOGIC ---

        context.coordinator.setupSceneUpdatesSubscription(arView: arView)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        coachingOverlay.frame = uiView.bounds
        context.coordinator.currentContext = context

        // Reuse existing button instead of remove+recreate every SwiftUI update
        if showPlacementButton {
            if let existing = uiView.viewWithTag(placeCourButtonTag) as? UIButton {
                existing.frame = CGRect(x: 20, y: uiView.bounds.height - 80, width: 160, height: 50)
            } else {
                let button = UIButton(type: .system)
                button.tag = placeCourButtonTag
                button.setTitle("Place Court", for: .normal)
                button.backgroundColor = .white
                button.setTitleColor(.black, for: .normal)
                button.layer.cornerRadius = 20
                button.frame = CGRect(x: 20, y: uiView.bounds.height - 80, width: 160, height: 50)
                button.addTarget(context.coordinator, action: #selector(Coordinator.placeCourtButtonTapped), for: .touchUpInside)
                uiView.addSubview(button)
            }
        } else {
            uiView.viewWithTag(placeCourButtonTag)?.removeFromSuperview()
        }

        if shouldStartAnimationBinding {
            #if DEBUG
            print("[ARPlayView updateUIView] shouldStartAnimationBinding is true. Calling startAnimations.")
            print("[ARPlayView updateUIView] Number of animations in map: \(context.coordinator.animationDataMap.count)")
            for (id, data) in context.coordinator.animationDataMap {
                print("[ARPlayView updateUIView] Animation data for \(id): points=\(data.pathPointsAR.count), duration=\(data.duration)")
            }
            #endif

            if context.coordinator.sceneUpdateSubscription == nil {
                #if DEBUG
                print("[ARPlayView updateUIView] Re-establishing scene update subscription")
                #endif
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

    static func prepareAnimationData(play: Models.SavedPlay, courtSize: CGSize, courtBounds: BoundingBox, courtAnchor: AnchorEntity, courtType: CourtType? = nil) -> PreparedAREntitiesAndAnimations {
        let resolvedCourtType = courtType ?? play.courtTypeEnum
        var preparedResult = PreparedAREntitiesAndAnimations()
        #if DEBUG
        print("[ARPlayView prepareAnimationData] Processing play: \(play.name) (ID: \(play.id))")
        print("[ARPlayView prepareAnimationData] Number of players: \(play.players.count), Balls: \(play.balls.count)")
        #endif

        for (index, player) in play.players.enumerated() {
            #if DEBUG
            print("[ARPlayView prepareAnimationData] Player [\(index)] details: ID \(player.id), Num \(player.number), Pos \(player.position.cgPoint), PathID \(player.assignedPathId?.uuidString ?? "None")")
            #endif

            let playerEntity: ModelEntity
            do {
                playerEntity = try ModelEntity.loadModel(named: "cylinder")
                playerEntity.scale = [0.0005, 0.0005, 0.0005]
                let isOpponent = player.number > 5
                let material = SimpleMaterial(color: isOpponent ? .red : .green, isMetallic: false)
                if playerEntity.model != nil {
                    playerEntity.model?.materials = [material]
                }
                #if DEBUG
                print("[ARPlayView prepareAnimationData] Successfully loaded 'cylinder.usdz' for player \(player.id)")
                #endif
            } catch {
                #if DEBUG
                print("[ARPlayView prepareAnimationData] ERROR loading 'cylinder.usdz': \(error.localizedDescription). Using default sphere.")
                #endif
                let isOpponent = player.number > 5
                playerEntity = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.02),
                                           materials: [SimpleMaterial(color: isOpponent ? .red : .green, isMetallic: false)])
            }
            let textMesh = MeshResource.generateText(
                "\(player.number)",
                extrusionDepth: 0.01,
                font: .systemFont(ofSize: 0.4, weight: .bold),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
            let textMaterial = SimpleMaterial(color: .white, isMetallic: false)
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
            textEntity.position = SIMD3<Float>(0, 0.04, 0)
            textEntity.setScale(SIMD3<Float>(repeating: 1.0), relativeTo: nil)
            playerEntity.addChild(textEntity)

            let initialPosAR = ARPlayView.mapWhiteboardToAR(player.position.cgPoint, courtSize: courtSize, courtBounds: courtBounds, courtType: resolvedCourtType, yOffset: 0.05)
            playerEntity.position = initialPosAR
            playerEntity.name = "player_\(player.id)"
            courtAnchor.addChild(playerEntity)
            preparedResult.playerEntities[player.id] = playerEntity

            if let pathId = player.assignedPathId,
               let drawingData = play.drawings.first(where: { $0.id == pathId }) {
                #if DEBUG
                print("[ARPlayView prepareAnimationData] Found path for player \(player.id):")
                print("  - Path points count: \(drawingData.points.count)")
                print("  - Path type: \(drawingData.type)")
                #endif

                let arPathPoints = drawingData.points.map { ARPlayView.mapWhiteboardToAR($0.cgPoint, courtSize: courtSize, courtBounds: courtBounds, courtType: resolvedCourtType, yOffset: 0.05) }
                let animationPathPointsAR = arPathPoints.count >= 2 && drawingData.type == DrawingTool.arrow.rawValue ? [arPathPoints.first!, arPathPoints.last!] : arPathPoints

                if !animationPathPointsAR.isEmpty {
                    let totalDistance = ARPlayView.calculateARPathLength(points: animationPathPointsAR)
                    let duration = TimeInterval(totalDistance / ARPlayView.walkingSpeed)
                    #if DEBUG
                    print("[ARPlayView prepAnim] Player \(player.id): PathID \(pathId), Points \(animationPathPointsAR.count), Dist \(totalDistance), Dur \(duration)")
                    #endif

                    preparedResult.animationDataMap[player.id] = ARAnimationData(
                        entity: playerEntity,
                        pathPointsAR: animationPathPointsAR,
                        totalDistance: totalDistance,
                        duration: max(0.1, duration)
                    )
                    playerEntity.position = animationPathPointsAR.first ?? initialPosAR
                } else {
                    #if DEBUG
                    print("[ARPlayView prepareAnimationData] Warning: No valid animation points for player \(player.id)")
                    #endif
                }
            } else {
                #if DEBUG
                print("[ARPlayView prepareAnimationData] No path assigned for player \(player.id)")
                #endif
            }
        }
        for (index, ballData) in play.balls.enumerated() {
            #if DEBUG
            print("[ARPlayView prepareAnimationData] Ball [\(index)] details: ID \(ballData.id), " +
                  "Pos \(ballData.position.cgPoint), PathID \(ballData.assignedPathId?.uuidString ?? "None"), " +
                  "PlayerID \(ballData.assignedPlayerId?.uuidString ?? "None")")
            #endif

            let ballEntity: ModelEntity
            do {
                ballEntity = try ModelEntity.loadModel(named: "ball")
                ballEntity.scale = [0.0015, 0.0015, 0.0015]
                #if DEBUG
                print("[ARPlayView prepareAnimationData] Successfully loaded 'ball.usdz' for ball \(ballData.id)")
                #endif
            } catch {
                #if DEBUG
                print("[ARPlayView prepareAnimationData] ERROR loading 'ball.usdz': \(error.localizedDescription). Using default orange sphere.")
                #endif
                let ballMaterial = SimpleMaterial(color: .orange, isMetallic: false)
                ballEntity = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.015),
                                         materials: [ballMaterial])
            }

            let initialPosAR = ARPlayView.mapWhiteboardToAR(ballData.position.cgPoint, courtSize: courtSize, courtBounds: courtBounds, courtType: resolvedCourtType, yOffset: 0.001)
            ballEntity.position = initialPosAR
            ballEntity.name = "ball_\(ballData.id)"
            courtAnchor.addChild(ballEntity)
            preparedResult.basketballEntities[ballData.id] = ballEntity

            if let assignedPlayerID = ballData.assignedPlayerId {
                preparedResult.basketballPlayerAssignments[ballData.id] = assignedPlayerID
                #if DEBUG
                print("[ARPlayView prepareAnimationData] Ball \(ballData.id) is ASSIGNED to player \(assignedPlayerID). It will follow the player.")
                #endif
            } else if let pathId = ballData.assignedPathId,
                      let drawingData = play.drawings.first(where: { $0.id == pathId }) {
                let arPathPoints = drawingData.points.map { ARPlayView.mapWhiteboardToAR($0.cgPoint, courtSize: courtSize, courtBounds: courtBounds, courtType: resolvedCourtType, yOffset: 0.001) }
                let animationPathPointsAR = arPathPoints.count >= 2 && drawingData.type == DrawingTool.arrow.rawValue ? [arPathPoints.first!, arPathPoints.last!] : arPathPoints

                if !animationPathPointsAR.isEmpty {
                    let totalDistance = ARPlayView.calculateARPathLength(points: animationPathPointsAR)
                    let duration = TimeInterval(totalDistance / ARPlayView.walkingSpeed)
                    #if DEBUG
                    print("[ARPlayView prepAnim] Ball \(ballData.id): PathID \(pathId), Points \(animationPathPointsAR.count), Dist \(totalDistance), Dur \(duration)")
                    #endif
                    preparedResult.animationDataMap[ballData.id] = ARAnimationData(entity: ballEntity, pathPointsAR: animationPathPointsAR, totalDistance: totalDistance, duration: max(0.1, duration))
                    ballEntity.position = animationPathPointsAR.first ?? initialPosAR
                }
            }
        }
        return preparedResult
    }

    func startAnimations(arView: ARView, context: Context) {
        guard !context.coordinator.animationDataMap.isEmpty else {
            #if DEBUG
            print("[ARPlayView startAnimations] No animation data. Count: \(context.coordinator.animationDataMap.count)")
            #endif
            return
        }

        #if DEBUG
        print("[ARPlayView startAnimations] Starting animations for \(context.coordinator.animationDataMap.count) entities.")
        #endif
        var didStartAnyAnimation = false
        for id in context.coordinator.animationDataMap.keys {
            if var animData = context.coordinator.animationDataMap[id] {
                animData.isAnimating = false
                animData.startTime = nil
                if let firstPoint = animData.pathPointsAR.first {
                    animData.entity.position = firstPoint
                }

                if !animData.pathPointsAR.isEmpty && animData.duration > 0 {
                    animData.startTime = Date()
                    animData.isAnimating = true
                    context.coordinator.animationDataMap[id] = animData
                    didStartAnyAnimation = true
                    #if DEBUG
                    print("[ARPlayView startAnimations] Animation started for entity: \(id)")
                    #endif
                }
            }
        }
        #if DEBUG
        if !didStartAnyAnimation {
            print("[ARPlayView startAnimations] All animations skipped or no valid data.")
        }
        #endif
    }

    // Maps a whiteboard point to AR anchor-local space using the court model's actual measured bounds.
    // xNorm/yNorm (0→1) interpolate directly from bounds.min to bounds.max in each axis.
    // Soccer/football swap axes because those canvases are rotated 90° vs the 3D model orientation.
    static func mapWhiteboardToAR(_ point: CGPoint, courtSize: CGSize, courtBounds: BoundingBox, courtType: CourtType, yOffset: Float = 0.05) -> SIMD3<Float> {
        let xNorm = Float(point.x / courtSize.width)
        let yNorm = Float(point.y / courtSize.height)
        let bMin = courtBounds.min
        let bMax = courtBounds.max
        switch courtType {
        case .soccer, .football:
            // Canvas X (short post-rotation axis) → AR Z; canvas Y (long post-rotation axis, flipped) → AR X
            let arX = bMin.x + (1.0 - yNorm) * (bMax.x - bMin.x)
            let arZ = bMin.z + xNorm * (bMax.z - bMin.z)
            return SIMD3<Float>(arX, yOffset, arZ)
        default:
            let arX = bMin.x + xNorm * (bMax.x - bMin.x)
            let arZ = bMin.z + yNorm * (bMax.z - bMin.z)
            return SIMD3<Float>(arX, yOffset, arZ)
        }
    }

    static func calculateARPathLength(points: [SIMD3<Float>]) -> Float {
        guard points.count > 1 else { return 0 }
        var totalDistance: Float = 0
        for i in 0..<(points.count - 1) {
            totalDistance += distance(points[i], points[i+1])
        }
        return totalDistance
    }

    static func getPointOnARPath(points: [SIMD3<Float>], progress: Float) -> SIMD3<Float>? {
        guard !points.isEmpty else { return nil }
        let clampedProgress = max(0.0, min(1.0, progress))
        guard clampedProgress > 0 else { return points.first }
        guard clampedProgress < 1 else { return points.last }
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
            let currentTime = Date()

            for id in self.animationDataMap.keys {
                guard var animData = self.animationDataMap[id], animData.isAnimating, let startTime = animData.startTime else {
                    continue
                }

                let elapsedTime = currentTime.timeIntervalSince(startTime)
                var progress = Float(elapsedTime / animData.duration)

                if progress >= 1.0 {
                    progress = 1.0
                    animData.isAnimating = false
                }

                if let newPosition = ARPlayView.getPointOnARPath(points: animData.pathPointsAR, progress: progress) {
                    animData.entity.position = newPosition
                }
                self.animationDataMap[id] = animData
            }

            for (ballID, playerID) in self.basketballPlayerAssignments {
                guard let ballEntity = self.basketballEntities[ballID],
                      let playerEntity = self.playerEntities[playerID] else { continue }
                var ballTargetPosition = playerEntity.position
                ballTargetPosition.y += 0.02
                ballEntity.position = ballTargetPosition
            }
        }

        func setupSceneUpdatesSubscription(arView: ARView) {
            sceneUpdateSubscription?.cancel()
            sceneUpdateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
                self?.updateScene(event: event)
            }
            #if DEBUG
            print("[ARPlayView Coordinator] Subscribed to scene updates.")
            #endif
        }

        deinit {
            sceneUpdateSubscription?.cancel()
        }

        // MARK: - ARCoachingOverlayViewDelegate
        func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {}

        func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
            #if DEBUG
            print("[ARPlayView Coordinator] Coaching overlay did deactivate.")
            #endif
        }

        func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {}

        // MARK: - ARSessionDelegate
        func session(_ session: ARSession, didFailWithError error: Error) {
            #if DEBUG
            print("[ARSession Coordinator] didFailWithError: \(error.localizedDescription)")
            #endif
        }
        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            #if DEBUG
            print("[ARSession Coordinator] cameraDidChangeTrackingState: \(camera.trackingState)")
            #endif
        }
        func sessionWasInterrupted(_ session: ARSession) {
            #if DEBUG
            print("[ARSession Coordinator] sessionWasInterrupted.")
            #endif
        }
        func sessionInterruptionEnded(_ session: ARSession) {
            #if DEBUG
            print("[ARSession Coordinator] sessionInterruptionEnded.")
            #endif
        }

        @objc func placeCourtButtonTapped() {
            #if DEBUG
            print("[ARPlayView] Place Court button tapped")
            #endif
            guard let arView = parent.arViewInstance, let context = currentContext else {
                #if DEBUG
                print("[ARPlayView] Cannot place court: arViewInstance or currentContext is nil.")
                #endif
                return
            }
            parent.placeCourtAtPreviewPosition(arView: arView, context: context)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func placeCourtOnly(at position: SIMD3<Float>, arView: ARView) -> (anchor: AnchorEntity, model: ModelEntity)? {
        #if DEBUG
        print("[ARPlayView] placeCourtOnly called with position: \(position)")
        #endif
        let (modelName, modelScale) = self.courtModelConfig
        let courtEntity: ModelEntity
        do {
            courtEntity = try ModelEntity.loadModel(named: modelName)
            courtEntity.scale = SIMD3<Float>(repeating: modelScale)
            courtEntity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            #if DEBUG
            let placedBounds = courtEntity.visualBounds(relativeTo: nil)
            print("[COMPARE][Placed] 3D '\(modelName)' extents (x,z): (\(placedBounds.extents.x), \(placedBounds.extents.z)) aspect z/x=\(placedBounds.extents.z / max(0.0001, placedBounds.extents.x))")
            #endif
        } catch {
            #if DEBUG
            print("[ARPlayView] ERROR loading '\(modelName).usdz': \(error.localizedDescription). Falling back to yellow plane.")
            #endif
            let boundary = self.play.courtTypeEnum.drawingBoundary
            let arCourtWidthFallback: Float = 0.3
            let arCourtHeightFallback: Float = arCourtWidthFallback * Float(boundary.height / boundary.width)
            let courtMesh = MeshResource.generatePlane(width: arCourtWidthFallback, depth: arCourtHeightFallback)
            let courtMaterial = SimpleMaterial(color: .yellow, isMetallic: false)
            courtEntity = ModelEntity(mesh: courtMesh, materials: [courtMaterial])
        }
        courtEntity.generateCollisionShapes(recursive: true)
        let courtAnchor = AnchorEntity(world: position)
        courtAnchor.addChild(courtEntity)
        arView.scene.addAnchor(courtAnchor)
        return (courtAnchor, courtEntity)
    }

    func placeCourtAtPreviewPosition(arView: ARView, context: Context) {
        guard let focusEntity = arView.focusEntity else {
            #if DEBUG
            print("[ARPlayView] FocusEntity is nil, cannot place court.")
            #endif
            return
        }
        guard focusEntity.onPlane else {
            #if DEBUG
            print("[ARPlayView] FocusEntity is not tracking a surface.")
            #endif
            return
        }
        let focusPosition = focusEntity.position

        if let previewAnchor = self.previewAnchor {
            arView.scene.removeAnchor(previewAnchor)
            self.previewAnchor = nil
            self.previewCourtEntity = nil
        }

        guard let (courtAnchor, courtEntity) = placeCourtOnly(at: focusPosition, arView: arView) else {
            return
        }

        // Bounds in anchor-local space: extents/center account for the model's scale, rotation,
        // and any origin offset — so players/balls placed relative to courtAnchor line up exactly.
        let courtBounds = courtEntity.visualBounds(relativeTo: courtAnchor)
        let boundary = self.play.courtTypeEnum.drawingBoundary
        let courtSize = CGSize(width: boundary.width, height: boundary.height)
        #if DEBUG
        print("[ARPlayView] courtBounds min=\(courtBounds.min) max=\(courtBounds.max) extents=\(courtBounds.extents)")
        #endif

        let preparedResult = ARPlayView.prepareAnimationData(
            play: self.play,
            courtSize: courtSize,
            courtBounds: courtBounds,
            courtAnchor: courtAnchor,
            courtType: self.play.courtTypeEnum
        )

        context.coordinator.animationDataMap = preparedResult.animationDataMap
        context.coordinator.playerEntities = preparedResult.playerEntities
        context.coordinator.basketballEntities = preparedResult.basketballEntities
        context.coordinator.basketballPlayerAssignments = preparedResult.basketballPlayerAssignments

        #if DEBUG
        print("[ARPlayView placeCourtAtPreviewPosition] Entities assigned to coordinator:")
        print("  - AnimationDataMap: \(context.coordinator.animationDataMap.count)")
        print("  - PlayerEntities: \(context.coordinator.playerEntities.count)")
        print("  - BasketballEntities: \(context.coordinator.basketballEntities.count)")
        print("  - Assignments: \(context.coordinator.basketballPlayerAssignments.count)")
        #endif

        isCourtPlaced = true
        showPlacementButton = false
        arView.focusEntity?.isEnabled = false
        arView.focusEntity = nil
    }
}

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
