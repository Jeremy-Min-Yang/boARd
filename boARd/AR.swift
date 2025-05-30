//
//  AR.swift
//  boARd
//
//  Created by Andy Ahn on 5/29/25.
//

import SwiftUI
import RealityKit
import ARKit
import FocusEntity
import Combine
import UIKit

// MARK: - ARModel
class ARModel {
    var modelName: String
    var image: UIImage
    var modelEntity: ModelEntity?
    
    private var cancellable: AnyCancellable? = nil
    
    init(modelName: String) {
        self.modelName = modelName
        
        // For chibi_kid variants, use the same image
        if modelName.starts(with: "cylinder_") {
            self.image = UIImage(named: "cylinder")!
        } else {
            self.image = UIImage(named: modelName)!
        }
        
        // For chibi_kid variants, use the same USDZ file
        let filename: String
        if modelName.starts(with: "cylinder_") {
            filename = "cylinder.usdz"
        } else {
            filename = modelName + ".usdz"
        }
        
        self.cancellable = ModelEntity.loadModelAsync(named: filename)
            .sink(receiveCompletion: { loadCompletion in
                print("DEBUG: Unable to load modelEntity for modelName: \(self.modelName)")
            }, receiveValue: { modelEntity in
                // Custom scaling for specific models
                switch self.modelName {
                case "hoop_court":
                    modelEntity.scale = SIMD3<Float>(repeating: 0.0003)
                    modelEntity.setPosition(.zero, relativeTo: nil)
                    modelEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
                    print("DEBUG: Applied scaling to hoop_court.")
                case let name where name.starts(with: "cylinder_"):
                    modelEntity.scale = SIMD3<Float>(repeating: 0.0000000000005)
                    modelEntity.setPosition(.zero, relativeTo: nil)
                    print("DEBUG: Applied scaling to \(self.modelName).")
                case "ball":
                    modelEntity.scale = SIMD3<Float>(repeating: 0.0000000000005)
                    modelEntity.setPosition(.zero, relativeTo: nil)
                    print("DEBUG: Applied scaling to ball.")
                default:
                    break
                }
                let bounds = modelEntity.visualBounds(relativeTo: nil)
                print("DEBUG: \(self.modelName) bounds: \(bounds)")
                self.modelEntity = modelEntity
                print("DEBUG: Successfully loaded modelEntity for modelName: \(self.modelName)")
            })
    }
}

// MARK: - Player and Ball Data Structures
struct ARPlayer {
    let id: Int
    let number: Int
    let position: CGPoint // 2D position on the court
}

struct ARBall {
    let id: Int
    let position: CGPoint // 2D position on the court
}

// MARK: - ContentView
struct ContentView: View {
    let play: Models.SavedPlay
    @State private var isPlacementEnabled = false
    @State private var selectedModel: ARModel?
    @State private var modelConfirmedForPlacement: ARModel?
    @State private var placedModels: Set<String> = [] // Track which models have been placed
    @State private var animationData: [UUID: ARAnimationData] = [:]
    @State private var isAnimating = false
    @State private var entityMap: [UUID: ModelEntity] = [:]
    @State private var arViewInstance: CustomARView? = nil

    static let walkingSpeed: Float = 0.2 // meters per second (adjust as needed)

    private var models: [ARModel] {
        var availableModels: [ARModel] = []
        // Only add the hoop_court if present
        let filemanager = FileManager.default
        if let path = Bundle.main.resourcePath, let files = try? filemanager.contentsOfDirectory(atPath: path) {
            if files.contains("hoop_court.usdz") {
                let model = ARModel(modelName: "hoop_court")
                availableModels.append(model)
            }
        }
        return availableModels
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(
                modelConfirmedForPlacement: self.$modelConfirmedForPlacement,
                placedModels: self.$placedModels,
                isPlacementEnabled: self.$isPlacementEnabled,
                selectedModel: self.selectedModel,
                play: play,
                animationData: self.$animationData,
                isAnimating: self.$isAnimating,
                entityMap: self.$entityMap,
                arViewInstance: self.$arViewInstance
            )
            if self.isPlacementEnabled {
                PlacementButtonsView(isPlacementEnabled: self.$isPlacementEnabled,
                                   selectedModel: self.$selectedModel,
                                   modelConfirmedForPlacement: self.$modelConfirmedForPlacement,
                                   placedModels: self.$placedModels)
            } else {
                ModelPickerView(isPlacementEnabled: self.$isPlacementEnabled,
                              selectedModel: self.$selectedModel,
                              models: self.models,
                              placedModels: self.$placedModels)
            }
            // Play button
            let _ = { print("DEBUG: Play button condition - placedModels: \(placedModels), isAnimating: \(isAnimating)") }()
            if placedModels.contains("hoop_court") {
                Button(action: {
                    print("DEBUG: Play button pressed. Removing old player/ball entities if any.")
                    guard let arView = arViewInstance else {
                        print("DEBUG: Could not find CustomARView instance.")
                        return
                    }
                    // Remove old player/ball entities
                    let toRemove = arView.mainAnchor.children.filter { $0.name.starts(with: "player_") || $0.name.starts(with: "ball_") }
                    for child in toRemove {
                        arView.mainAnchor.removeChild(child)
                        print("DEBUG: Removed entity from mainAnchor: \(child.name)")
                    }
                    // Recreate and add player/ball entities
                    let courtSize = play.courtType == "full" ? CGSize(width: 300, height: 600) : CGSize(width: 300, height: 300)
                    let arCourtWidth: Float = 0.15
                    let arCourtHeight: Float = 0.15 * Float(courtSize.height / courtSize.width)
                    arView.placePlayersAndBalls(for: play, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight)
                    // Start animation
                    arView.startAnimation(with: play)
                }) {
                    Image(systemName: "play.fill")
                        .font(.largeTitle)
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                .padding(.bottom, 100)
            }
        }
    }

    // Animation logic
    func startAnimation() {
        print("DEBUG: startAnimation called. animationData count before: \(animationData.count)")
        guard !isAnimating else { return }
        // Prepare animation data for all players and balls with assigned paths
        var newAnimationData: [UUID: ARAnimationData] = [:]
        let courtSize = play.courtType == "full" ? CGSize(width: 300, height: 600) : CGSize(width: 300, height: 300)
        let arCourtWidth: Float = 0.15
        let arCourtHeight: Float = 0.15 * Float(courtSize.height / courtSize.width)
        // Players
        for player in play.players {
            guard let pathId = player.assignedPathId,
                  let drawing = play.drawings.first(where: { $0.id == pathId }),
                  !drawing.points.isEmpty else {
                print("DEBUG: Skipping player \(player.id) - no assigned path or empty path.")
                continue
            }
            let arPath = drawing.points.map { map2DToAR($0.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight) }
            let percent: Double = 0.8
            let count = max(2, Int(Double(arPath.count) * percent))
            let shortPath = Array(arPath.suffix(count))
            print("DEBUG: Animating player \(player.id) with path of \(arPath.count) points.")
            let totalDistance = ARPlayView.calculateARPathLength(points: shortPath)
            let duration: TimeInterval = max(0.1, Double(totalDistance) / Double(ContentView.walkingSpeed))
            if let entity = entityMap[player.id] {
                newAnimationData[player.id] = ARAnimationData(entity: entity, pathPointsAR: shortPath, totalDistance: totalDistance, duration: duration, startTime: Date(), isAnimating: true)
            } else {
                print("DEBUG: No entity found for player \(player.id) in entityMap.")
            }
        }
        // Balls
        for ball in play.basketballs {
            guard let pathId = ball.assignedPathId,
                  let drawing = play.drawings.first(where: { $0.id == pathId }),
                  !drawing.points.isEmpty else {
                print("DEBUG: Skipping ball \(ball.id) - no assigned path or empty path.")
                continue
            }
            let arPath = drawing.points.map { map2DToAR($0.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight) }
            let percent: Double = 0.8
            let count = max(2, Int(Double(arPath.count) * percent))
            let shortPath = Array(arPath.suffix(count))
            print("DEBUG: Animating ball \(ball.id) with path of \(arPath.count) points.")
            let totalDistance = ARPlayView.calculateARPathLength(points: shortPath)
            let duration: TimeInterval = max(0.1, Double(totalDistance) / Double(ContentView.walkingSpeed))
            if let entity = entityMap[ball.id] {
                newAnimationData[ball.id] = ARAnimationData(entity: entity, pathPointsAR: shortPath, totalDistance: totalDistance, duration: duration, startTime: Date(), isAnimating: true)
            } else {
                print("DEBUG: No entity found for ball \(ball.id) in entityMap.")
            }
        }
        self.animationData = newAnimationData
        self.isAnimating = true
        print("DEBUG: animationData count after: \(self.animationData.count)")
        print("DEBUG: entityMap keys: \(entityMap.keys)")
        print("DEBUG: Animation started or replayed. isAnimating: \(isAnimating)")
    }
    func findEntityByName(_ name: String) -> ModelEntity? {
        // Search in the ARView's mainAnchor for an entity with the given name
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            for subview in rootViewController.view.subviews {
                if let arView = subview as? CustomARView {
                    return arView.mainAnchor.children.compactMap { $0 as? ModelEntity }.first(where: { $0.name == name })
                }
            }
        }
        return nil
    }
}

// MARK: - ARViewContainer
struct ARViewContainer: UIViewRepresentable {
    @Binding var modelConfirmedForPlacement: ARModel?
    @Binding var placedModels: Set<String>
    @Binding var isPlacementEnabled: Bool
    var selectedModel: ARModel? = nil
    let play: Models.SavedPlay
    @Binding var animationData: [UUID: ARAnimationData]
    @Binding var isAnimating: Bool
    @Binding var entityMap: [UUID: ModelEntity]
    @Binding var arViewInstance: CustomARView?
    
    func makeUIView(context: Context) -> ARView {
        let arView = CustomARView(frame: .zero)
        DispatchQueue.main.async {
            self.arViewInstance = arView
        }
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        if let customARView = uiView as? CustomARView {
            // Sync animation state from SwiftUI to ARView
            customARView.animationData = animationData
            customARView.isAnimating = isAnimating
            // Handle model selection for movement
            if let selectedModel = selectedModel, !isPlacementEnabled {
                if let chibiKid = customARView.findChibiKid(withModelName: selectedModel.modelName) {
                    customARView.lastPlacedEntity = chibiKid
                    print("DEBUG: Selected existing chibi_kid for movement: \(selectedModel.modelName)")
                    
                    // Temporarily increase size
                    let originalScale = chibiKid.scale
                    let newScale = SIMD3<Float>(
                        originalScale.x * 1.4,
                        originalScale.y * 1.4,
                        originalScale.z * 1.4
                    )
                    chibiKid.setScale(newScale, relativeTo: nil)
                    
                    // Return to original size after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        chibiKid.setScale(originalScale, relativeTo: nil)
                        print("DEBUG: Returned chibi_kid to original size: \(selectedModel.modelName)")
                    }
                }
                // Remove any existing preview when selecting an existing model
                customARView.removePreview()
            }
            
            // Show preview if a model is selected but not yet placed
            if let selectedModel = selectedModel, modelConfirmedForPlacement == nil, isPlacementEnabled {
                customARView.showPreview(for: selectedModel)
                customARView.updatePreviewPosition()
            } else {
                customARView.removePreview()
            }
        }
        
        if let model = self.modelConfirmedForPlacement {
            if let modelEntity = model.modelEntity {
                print("DEBUG: adding model to scene - \(model.modelName)")
                let clonedEntity = modelEntity.clone(recursive: true)
                clonedEntity.name = model.modelName
                if clonedEntity.collision == nil {
                    let bounds = clonedEntity.visualBounds(relativeTo: nil)
                    let collisionShape = ShapeResource.generateBox(size: bounds.extents).offsetBy(translation: bounds.center)
                    clonedEntity.collision = CollisionComponent(shapes: [collisionShape])
                }
                if let customARView = uiView as? CustomARView {
                    if model.modelName == "hoop_court" {
                        if let focusPosition = customARView.focusEntityPosition() {
                            customARView.mainAnchor.setPosition(focusPosition, relativeTo: nil)
                            clonedEntity.setPosition(.zero, relativeTo: nil)
                            // Always set the same fixed rotation
                            clonedEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
                            customARView.mainAnchor.addChild(clonedEntity)
                            customARView.lastPlacedEntity = clonedEntity
                            customARView.toggleFocusEntity(isVisible: false)
                            customARView.removePreview()

                            // --- Place players and ball on the court using play data (NO rotate180Y) ---
                            let courtSize = play.courtType == "full" ? CGSize(width: 300, height: 600) : CGSize(width: 300, height: 300)
                            let arCourtWidth: Float = 0.15
                            let arCourtHeight: Float = 0.15 * Float(courtSize.height / courtSize.width)
                            for player in play.players {
                                let arPosition = map2DToAR(player.position.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight)
                                let playerEntity: ModelEntity
                                if let loaded = try? ModelEntity.loadModel(named: "cylinder") {
                                    print("Loaded cylinder model for player \(player.number)")
                                    playerEntity = loaded
                                    playerEntity.scale = SIMD3<Float>(repeating: 0.0002)
                                    playerEntity.model?.materials = [SimpleMaterial(color: .green, isMetallic: false)]
                                } else {
                                    print("Failed to load cylinder model for player \(player.number), using fallback sphere.")
                                    playerEntity = ModelEntity(mesh: .generateSphere(radius: 0.008), materials: [SimpleMaterial(color: .green, isMetallic: false)])
                                }
                                playerEntity.position = arPosition
                                playerEntity.name = "player_\(player.id)"
                                let textMesh = MeshResource.generateText("\(player.number)", extrusionDepth: 0.02, font: .systemFont(ofSize: 0.1), containerFrame: .zero, alignment: .center, lineBreakMode: .byWordWrapping)
                                let textMaterial = SimpleMaterial(color: .green, isMetallic: false)
                                let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
                                textEntity.position = SIMD3<Float>(0, 0.3, 0)
                                playerEntity.addChild(textEntity)
                                customARView.mainAnchor.addChild(playerEntity)
                                entityMap[player.id] = playerEntity
                            }
                            for ball in play.basketballs {
                                let ballARPosition = map2DToAR(ball.position.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight)
                                let ballEntity: ModelEntity
                                if let loaded = try? ModelEntity.loadModel(named: "ball") {
                                    print("Loaded ball model")
                                    ballEntity = loaded
                                    ballEntity.scale = SIMD3<Float>(repeating: 0.00045)
                                } else {
                                    print("Failed to load ball model, using fallback orange sphere.")
                                    ballEntity = ModelEntity(mesh: .generateSphere(radius: 0.015), materials: [SimpleMaterial(color: .orange, isMetallic: false)])
                                }
                                ballEntity.position = ballARPosition
                                ballEntity.name = "ball_\(ball.id)"
                                customARView.mainAnchor.addChild(ballEntity)
                                entityMap[ball.id] = ballEntity
                            }
                            // --- End place players and ball ---

                            DispatchQueue.main.async {
                                self.modelConfirmedForPlacement = nil
                                self.placedModels.insert("hoop_court")
                                print("DEBUG: placedModels now contains: \(self.placedModels)")
                            }
                            return
                        }
                    }
                    // For chibi_kid models
                    if model.modelName.starts(with: "chibi_kid_") {
                        // Raycast from center of the screen to find a placement position
                        let center = CGPoint(x: uiView.bounds.midX, y: uiView.bounds.midY)
                        let results = customARView.raycast(from: center, allowing: .estimatedPlane, alignment: .any)
                        if let firstResult = results.first {
                            let position = SIMD3<Float>(
                                firstResult.worldTransform.columns.3.x,
                                firstResult.worldTransform.columns.3.y,
                                firstResult.worldTransform.columns.3.z
                            )
                            customARView.mainAnchor.setPosition(position, relativeTo: nil)
                            customARView.mainAnchor.addChild(clonedEntity)
                            customARView.lastPlacedEntity = clonedEntity
                            
                            // Add a number label above the chibi_kid
                            let number = model.modelName.replacingOccurrences(of: "chibi_kid_", with: "")
                            let textMesh = MeshResource.generateText(number,
                                                                   extrusionDepth: 0.02,
                                                                   font: .systemFont(ofSize: 0.1),
                                                                   containerFrame: .zero,
                                                                   alignment: .center,
                                                                   lineBreakMode: .byWordWrapping)
                            let textMaterial = SimpleMaterial(color: .red, isMetallic: false)
                            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
                            textEntity.position = SIMD3<Float>(0, 0.3, 0) // Position higher above the chibi_kid
                            clonedEntity.addChild(textEntity)
                            
                            // Store the placed chibi_kid in our dictionary
                            customARView.placedChibiKids[model.modelName] = clonedEntity
                            
                            customARView.removePreview()
                            print("DEBUG: Placed \(model.modelName) at position: \(position)")
                            
                            // Add to placed models set
                            DispatchQueue.main.async {
                                self.placedModels.insert(model.modelName)
                            }
                        } else {
                            print("DEBUG: No surface found for placement.")
                        }
                    }
                }
                if model.modelName == "hoop_court", let customARView = uiView as? CustomARView {
                    customARView.toggleFocusEntity(isVisible: false)
                }
            } else {
                print("DEBUG: unable to load modelEntity for \(model.modelName)")
            }
            DispatchQueue.main.async {
                self.modelConfirmedForPlacement = nil
            }
        }
    }
}

// MARK: - CustomARView
class CustomARView: ARView {
    var customFocusEntity: FocusEntity?
    var mainAnchor = AnchorEntity(world: .zero)
    var lastPlacedEntity: ModelEntity? // Always move this one
    private var initialDragYPosition: Float?
    // Preview support
    var previewAnchor = AnchorEntity(world: .zero)
    var previewModelEntity: ModelEntity?
    private var sceneUpdateCancellable: Cancellable?
    // Animation state
    var animationData: [UUID: ARAnimationData] = [:]
    var isAnimating: Bool = false
    // Store player/ball entities by UUID
    var entityMap: [UUID: ModelEntity] = [:]
    
    // Dictionary to track placed chibi_kids by their model name
    var placedChibiKids: [String: ModelEntity] = [:]
    
    required init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        self.scene.addAnchor(mainAnchor)
        self.setupFocusEntity()
        self.setupARView()
        self.setupGestureRecognizer()
        // Subscribe to scene updates for animation
        sceneUpdateCancellable = self.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            self?.updateAnimationIfNeeded()
            self?.updatePreviewPosition()
        }
    }
    
    deinit {
        sceneUpdateCancellable?.cancel()
    }
    
    @objc required dynamic init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        self.setupGestureRecognizer()
    }
    
    private func setupFocusEntity() {
        self.customFocusEntity = FocusEntity(on: self, focus: .classic)
    }
    
    func setupARView() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        self.session.run(config)
    }
    
    // Method to toggle focus entity visibility
    func toggleFocusEntity(isVisible: Bool) {
        self.customFocusEntity?.isEnabled = isVisible
    }
    
    // MARK: - Gesture Recognizers
    
    private func setupGestureRecognizer() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(recognizer:)))
        self.addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:)))
        self.addGestureRecognizer(tapGesture)
    }
    
    @objc func handlePan(recognizer: UIPanGestureRecognizer) {
        let location = recognizer.location(in: self)
        guard let entityToDrag = self.lastPlacedEntity else { return }
        
        switch recognizer.state {
        case .began:
            self.initialDragYPosition = entityToDrag.position(relativeTo: nil).y
        case .changed:
            guard let initialY = self.initialDragYPosition else { return }
            let results = self.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .any)
            if let firstResult = results.first {
                let newX = firstResult.worldTransform.columns.3.x
                let newZ = firstResult.worldTransform.columns.3.z
                let worldPosition = SIMD3<Float>(newX, initialY, newZ)
                entityToDrag.setPosition(worldPosition, relativeTo: nil)
            }
        case .ended, .cancelled:
            self.initialDragYPosition = nil
        default:
            break
        }
    }
    
    @objc func handleTap(recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: self)
        if let entity = self.entity(at: location) as? ModelEntity {
            // If it's a chibi_kid, make it the lastPlacedEntity
            if entity.name.starts(with: "chibi_kid_") {
                self.lastPlacedEntity = entity
                print("DEBUG: Selected chibi_kid for dragging: \(entity.name)")
            }
        }
    }
    
    // Helper to get the current position of the FocusEntity
    func focusEntityPosition() -> SIMD3<Float>? {
        return customFocusEntity?.position
    }
    
    func showPreview(for model: ARModel) {
        // Remove any existing preview
        previewModelEntity?.removeFromParent()
        // Clone and make transparent
        guard let entity = model.modelEntity?.clone(recursive: true) as? ModelEntity else { return }
        entity.name = "preview"
        // Make all materials transparent white for all slots (applies to all assets)
        if let modelComponent = entity.model {
            let transparentMaterial = SimpleMaterial(color: .white.withAlphaComponent(0.5), isMetallic: false)
            entity.model?.materials = Array(repeating: transparentMaterial, count: modelComponent.materials.count)
        }
        // Rotate the preview court by 90 degrees around Y axis
        entity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
        previewModelEntity = entity
        previewAnchor.addChild(entity)
        if !self.scene.anchors.contains(where: { $0 === previewAnchor }) {
            self.scene.addAnchor(previewAnchor)
        }
    }
    
    func removePreview() {
        previewModelEntity?.removeFromParent()
        previewModelEntity = nil
    }
    
    func updatePreviewPosition() {
        if let focusPosition = customFocusEntity?.position {
            previewAnchor.setPosition(focusPosition, relativeTo: nil)
        }
    }
    
    // Add method to find chibi_kid by model name
    func findChibiKid(withModelName modelName: String) -> ModelEntity? {
        return placedChibiKids[modelName]
    }
    
    // Add method to temporarily increase size of a chibi_kid
    func temporarilyIncreaseSize(withModelName modelName: String) {
        if let chibiKid = placedChibiKids[modelName] {
            // Store original scale
            let originalScale = chibiKid.scale
            
            // Increase size by 40%
            let newScale = SIMD3<Float>(
                originalScale.x * 1.4,
                originalScale.y * 1.4,
                originalScale.z * 1.4
            )
            chibiKid.setScale(newScale, relativeTo: nil)
            
            print("DEBUG: Increased size of chibi_kid: \(modelName)")
            
            // Return to original size after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                chibiKid.setScale(originalScale, relativeTo: nil)
                print("DEBUG: Returned chibi_kid to original size: \(modelName)")
            }
        } else {
            print("DEBUG: Could not find chibi_kid to resize: \(modelName)")
        }
    }
    
    // Animation update logic
    func updateAnimationIfNeeded() {
        guard isAnimating else { return }
        print("DEBUG: updateAnimationIfNeeded running. animationData count: \(animationData.count)")
        var allDone = true
        let now = Date()
        for (id, var anim) in animationData {
            guard anim.isAnimating, let start = anim.startTime, anim.pathPointsAR.count > 1 else { continue }
            let elapsed = now.timeIntervalSince(start)
            let progress = min(1.0, elapsed / anim.duration)
            print("DEBUG: Animating entity \(id) - progress: \(progress), position: \(anim.entity.position)")
            if let newPosition = getPointOnARPath(points: anim.pathPointsAR, progress: Float(progress)) {
                anim.entity.position = newPosition
            }
            if progress >= 1.0 {
                anim.isAnimating = false
            } else {
                allDone = false
            }
            animationData[id] = anim
        }
        if allDone {
            isAnimating = false
            print("DEBUG: All animations done. isAnimating set to false.")
        }
        print("DEBUG: Animation started or replayed. isAnimating: \(isAnimating)")
    }
    
    // New: Place players and balls from play data
    func placePlayersAndBalls(for play: Models.SavedPlay, courtSize: CGSize, arCourtWidth: Float, arCourtHeight: Float) {
        print("DEBUG: Placing players and balls for play: \(play.name)")
        entityMap.removeAll()
        // Players
        for player in play.players {
            let arPosition = map2DToAR(player.position.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight)
            let playerEntity: ModelEntity
            if let loaded = try? ModelEntity.loadModel(named: "cylinder") {
                print("DEBUG: Loaded cylinder model for player \(player.number)")
                playerEntity = loaded
                playerEntity.scale = SIMD3<Float>(repeating: 0.0002)
                playerEntity.model?.materials = [SimpleMaterial(color: .green, isMetallic: false)]
            } else {
                print("DEBUG: Failed to load cylinder model for player \(player.number), using fallback sphere.")
                playerEntity = ModelEntity(mesh: .generateSphere(radius: 0.008), materials: [SimpleMaterial(color: .green, isMetallic: false)])
            }
            playerEntity.position = arPosition
            playerEntity.name = "player_\(player.id)"
            let textMesh = MeshResource.generateText("\(player.number)", extrusionDepth: 0.02, font: .systemFont(ofSize: 0.1), containerFrame: .zero, alignment: .center, lineBreakMode: .byWordWrapping)
            let textMaterial = SimpleMaterial(color: .green, isMetallic: false)
            let textEntity = ModelEntity(mesh: textMesh, materials: [textMaterial])
            textEntity.position = SIMD3<Float>(0, 0.3, 0)
            playerEntity.addChild(textEntity)
            mainAnchor.addChild(playerEntity)
            entityMap[player.id] = playerEntity
            print("DEBUG: Added player entity for \(player.id) to entityMap.")
        }
        // Balls
        for ball in play.basketballs {
            let ballARPosition = map2DToAR(ball.position.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight)
            let ballEntity: ModelEntity
            if let loaded = try? ModelEntity.loadModel(named: "ball") {
                print("DEBUG: Loaded ball model")
                ballEntity = loaded
                ballEntity.scale = SIMD3<Float>(repeating: 0.00045)
            } else {
                print("DEBUG: Failed to load ball model, using fallback orange sphere.")
                ballEntity = ModelEntity(mesh: .generateSphere(radius: 0.015), materials: [SimpleMaterial(color: .orange, isMetallic: false)])
            }
            ballEntity.position = ballARPosition
            ballEntity.name = "ball_\(ball.id)"
            mainAnchor.addChild(ballEntity)
            entityMap[ball.id] = ballEntity
            print("DEBUG: Added ball entity for \(ball.id) to entityMap.")
        }
    }
    
    // New: Start animation for play
    func startAnimation(with play: Models.SavedPlay) {
        print("DEBUG: startAnimation called in ARView. Clearing previous animationData.")
        animationData.removeAll()
        isAnimating = false
        let courtSize = play.courtType == "full" ? CGSize(width: 300, height: 600) : CGSize(width: 300, height: 300)
        let arCourtWidth: Float = 0.15
        let arCourtHeight: Float = 0.15 * Float(courtSize.height / courtSize.width)
        // In startAnimation(with play: Models.SavedPlay) in CustomARView, before building animationData:
        print("DEBUG: --- Animation Pre-Check ---")
        let playerIDs = Set(play.players.map { $0.id })
        let ballIDs = Set(play.basketballs.map { $0.id })
        let entityMapIDs = Set(entityMap.keys)
        let sceneEntityNames = Set(mainAnchor.children.compactMap { $0.name })
        print("DEBUG: play.players IDs: \(playerIDs)")
        print("DEBUG: play.basketballs IDs: \(ballIDs)")
        print("DEBUG: entityMap keys: \(entityMapIDs)")
        print("DEBUG: mainAnchor children names: \(sceneEntityNames)")
        let missingPlayers = playerIDs.subtracting(entityMapIDs)
        let missingBalls = ballIDs.subtracting(entityMapIDs)
        if missingPlayers.isEmpty && missingBalls.isEmpty {
            print("DEBUG: All player and ball entities are present in entityMap and AR scene. Ready to animate!")
        } else {
            print("DEBUG: WARNING: Missing entities for animation. Missing players: \(missingPlayers), Missing balls: \(missingBalls)")
        }
        // Build animation data for players
        for player in play.players {
            guard let pathId = player.assignedPathId,
                  let drawing = play.drawings.first(where: { $0.id == pathId }),
                  !drawing.points.isEmpty else {
                print("DEBUG: Skipping player \(player.id) - no assigned path or empty path.")
                continue
            }
            let arPath = drawing.points.map { map2DToAR($0.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight) }
            let percent: Double = 0.8
            let count = max(2, Int(Double(arPath.count) * percent))
            let shortPath = Array(arPath.suffix(count))
            print("DEBUG: Animating player \(player.id) with path of \(arPath.count) points.")
            if let entity = entityMap[player.id] {
                let totalDistance = ARPlayView.calculateARPathLength(points: shortPath)
                let duration: TimeInterval = max(0.1, Double(totalDistance) / Double(ContentView.walkingSpeed))
                animationData[player.id] = ARAnimationData(entity: entity, pathPointsAR: shortPath, totalDistance: totalDistance, duration: duration, startTime: Date(), isAnimating: true)
            } else {
                print("DEBUG: No entity found for player \(player.id) in entityMap.")
            }
        }
        // Build animation data for balls
        for ball in play.basketballs {
            guard let pathId = ball.assignedPathId,
                  let drawing = play.drawings.first(where: { $0.id == pathId }),
                  !drawing.points.isEmpty else {
                print("DEBUG: Skipping ball \(ball.id) - no assigned path or empty path.")
                continue
            }
            let arPath = drawing.points.map { map2DToAR($0.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight) }
            let percent: Double = 0.8
            let count = max(2, Int(Double(arPath.count) * percent))
            let shortPath = Array(arPath.suffix(count))
            print("DEBUG: Animating ball \(ball.id) with path of \(arPath.count) points.")
            if let entity = entityMap[ball.id] {
                let totalDistance = ARPlayView.calculateARPathLength(points: shortPath)
                let duration: TimeInterval = max(0.1, Double(totalDistance) / Double(ContentView.walkingSpeed))
                animationData[ball.id] = ARAnimationData(entity: entity, pathPointsAR: shortPath, totalDistance: totalDistance, duration: duration, startTime: Date(), isAnimating: true)
            } else {
                print("DEBUG: No entity found for ball \(ball.id) in entityMap.")
            }
        }
        isAnimating = !animationData.isEmpty
        print("DEBUG: Animation started in ARView. animationData count: \(animationData.count), isAnimating: \(isAnimating)")
    }
    
    // Add this helper function to CustomARView:
    func getPointOnARPath(points: [SIMD3<Float>], progress: Float) -> SIMD3<Float>? {
        guard !points.isEmpty else { return nil }
        let clampedProgress = max(0.0, min(1.0, progress))
        guard clampedProgress > 0 else { return points.first }
        guard clampedProgress < 1 else { return points.last }
        // Calculate total path length
        var totalLength: Float = 0
        var segmentLengths: [Float] = []
        for i in 0..<(points.count - 1) {
            let segLen = distance(points[i], points[i+1])
            segmentLengths.append(segLen)
            totalLength += segLen
        }
        let targetDistance = totalLength * clampedProgress
        var distanceCovered: Float = 0
        for i in 0..<(points.count - 1) {
            let segLen = segmentLengths[i]
            if distanceCovered + segLen >= targetDistance {
                let remaining = targetDistance - distanceCovered
                let t = segLen > 0 ? remaining / segLen : 0
                return simd_mix(points[i], points[i+1], SIMD3<Float>(repeating: t))
            }
            distanceCovered += segLen
        }
        return points.last
    }
}

// MARK: - ModelPickerView
struct ModelPickerView: View {
    @Binding var isPlacementEnabled: Bool
    @Binding var selectedModel: ARModel?
    var models: [ARModel]
    @Binding var placedModels: Set<String>
    @State private var arView: CustomARView?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 30) {
                ForEach(0 ..< self.models.count, id: \.self) { index in
                    Button(action: {
                        let model = self.models[index]
                        print("DEBUG: selected model with name: \(model.modelName)")
                        
                        if placedModels.contains(model.modelName) {
                            // If model is already placed, just select it for movement
                            self.selectedModel = model
                            self.isPlacementEnabled = false // Don't enter placement mode
                            
                            // Temporarily increase size of the selected chibi_kid
                            if let arView = self.arView {
                                arView.temporarilyIncreaseSize(withModelName: model.modelName)
                                arView.removePreview() // Ensure preview is removed
                            }
                        } else {
                            // If model hasn't been placed, prepare for placement
                            self.selectedModel = model
                            self.isPlacementEnabled = true
                        }
                    }) {
                        ZStack {
                            Image(uiImage: self.models[index].image)
                                .resizable()
                                .frame(height: 80)
                                .aspectRatio(1/1, contentMode: .fit)
                                .background(Color.white)
                                .cornerRadius(12)
                            
                            // Add number overlay for chibi_kid models
                            if self.models[index].modelName.starts(with: "chibi_kid_") {
                                let number = self.models[index].modelName.replacingOccurrences(of: "chibi_kid_", with: "")
                                Text(number)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.red)
                                    .padding(4)
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(8)
                                    .offset(x: 30, y: -30)
                            }
                        }
                        .opacity(placedModels.contains(self.models[index].modelName) ? 0.5 : 1.0)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.5))
        .onAppear {
            // Find the ARView in the view hierarchy
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                for subview in rootViewController.view.subviews {
                    if let arView = subview as? CustomARView {
                        self.arView = arView
                        break
                    }
                }
            }
        }
    }
}

// MARK: - PlacementButtonsView
struct PlacementButtonsView: View {
    @Binding var isPlacementEnabled: Bool
    @Binding var selectedModel: ARModel?
    @Binding var modelConfirmedForPlacement: ARModel?
    @Binding var placedModels: Set<String>
    
    var body: some View {
        HStack {
            // Cancel button
            Button(action: {
                print("DEBUG: model placement canceled.")
                self.resetPlacementParameters()
            }) {
                Image(systemName: "xmark")
                    .frame(width: 60, height: 60)
                    .font(.title)
                    .background(Color.white.opacity(0.75))
                    .cornerRadius(30)
                    .padding(20)
            }
            
            // Confirm button
            Button(action: {
                print("DEBUG: model placement confirmed.")
                self.modelConfirmedForPlacement = self.selectedModel
                self.resetPlacementParameters()
            }) {
                Image(systemName: "checkmark")
                    .frame(width: 60, height: 60)
                    .font(.title)
                    .background(Color.white.opacity(0.75))
                    .cornerRadius(30)
                    .padding(20)
            }
        }
    }
    
    func resetPlacementParameters() {
        self.isPlacementEnabled = false
        self.selectedModel = nil
    }
}

// MARK: - ContentView_Previews
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(play: Models.SavedPlay(
            firestoreID: nil,
            id: UUID(),
            userID: nil,
            name: "Preview Play",
            dateCreated: Date(),
            lastModified: Date(),
            courtType: "full",
            drawings: [],
            players: [],
            basketballs: []
        ))
    }
}

// MARK: - Extensions
extension Entity {
    var hierarchyNames: [String] {
        var names: [String] = []
        var current: Entity? = self
        while let c = current {
            // Prefer ModelEntity.name if available, otherwise Entity.name
            var entityName = "Unnamed"
            if let model = c as? ModelEntity, !model.name.isEmpty {
                entityName = model.name
            } else if !c.name.isEmpty {
                entityName = c.name
            }
            names.append(entityName)
            current = c.parent
        }
        return names.reversed() // Reversed to show from root to current
    }
}

extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        SIMD3<Scalar>(x, y, z)
    }
}

func map2DToAR(_ point: CGPoint, courtSize: CGSize, arCourtWidth: Float, arCourtHeight: Float) -> SIMD3<Float> {
    let xNorm = Float(point.x / courtSize.width)
    let zNorm = Float(point.y / courtSize.height)
    let x = (xNorm - 0.5) * arCourtWidth - 0.19
    let z = (zNorm - 0.5) * arCourtHeight + 0.04
    return SIMD3<Float>(x, 0.05, z)
}

// Add exit button support
struct ARContentViewWrapper: View {
    @Environment(\.presentationMode) var presentationMode
    let play: Models.SavedPlay
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ContentView(play: play)
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
