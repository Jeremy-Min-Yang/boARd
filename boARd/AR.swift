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
import simd

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
            self.image = UIImage(named: "cylinder") ?? UIImage(systemName: "person.fill")!
        } else if modelName == "football" {
            self.image = UIImage(named: "football.png") ?? UIImage(systemName: "soccerball")!
        } else if modelName == "soccerball" {
            self.image = UIImage(named: "soccerball.png") ?? UIImage(systemName: "soccerball")!
        } else {
            self.image = UIImage(named: modelName) ?? UIImage(systemName: "cube.fill")!
        }
        
        // For chibi_kid variants, use the same USDZ file
        let filename: String
        if modelName.starts(with: "cylinder_") {
            filename = "cylinder.usdz"
        } else if modelName == "soccerfield" {
            filename = "soccerfield.usdz"
        } else if modelName == "footballfield" {
            filename = "footballfield.usdz"
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
                    // Restore original orientation (no rotation or .pi/2 around Y)
                    modelEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
                    print("DEBUG: Applied scaling and orientation to hoop_court.")
                case "soccerfield":
                    modelEntity.scale = SIMD3<Float>(repeating: 0.008)
                    modelEntity.setPosition(.zero, relativeTo: nil)
                    modelEntity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
                    print("DEBUG: Applied scaling and orientation to soccerfield.")
                case "footballfield":
                    modelEntity.scale = SIMD3<Float>(repeating: 0.008)
                    modelEntity.setPosition(.zero, relativeTo: nil)
                    modelEntity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
                    print("DEBUG: Applied scaling and orientation to footballfield.")
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
    @State private var isCourtAdjustmentModeEnabled = false // New state for adjustment mode
    @State private var showModelPlacementError = false // <-- Add this state
    @State private var modelPlacementErrorMessage = "" // <-- Add this state

    static let walkingSpeed: Float = 0.2 // meters per second (adjust as needed)

    private var models: [ARModel] {
        var availableModels: [ARModel] = []
        let filemanager = FileManager.default
        if let path = Bundle.main.resourcePath, let files = try? filemanager.contentsOfDirectory(atPath: path) {
            switch play.courtType {
            case "Full Court", "Half Court":
                if files.contains("hoop_court.usdz") {
                    availableModels.append(ARModel(modelName: "hoop_court"))
                }
                if files.contains("ball.usdz") {
                    availableModels.append(ARModel(modelName: "ball"))
                }
            case "Soccer Pitch":
                if files.contains("soccerfield.usdz") {
                    availableModels.append(ARModel(modelName: "soccerfield"))
                }
                if files.contains("soccerball.usdz") {
                    availableModels.append(ARModel(modelName: "soccerball"))
                }
            case "Football Field":
                if files.contains("footballfield.usdz") {
                    availableModels.append(ARModel(modelName: "footballfield"))
                }
                if files.contains("football.usdz") {
                    availableModels.append(ARModel(modelName: "football"))
                }
            default:
                break
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
                arViewInstance: self.$arViewInstance,
                showModelPlacementError: self.$showModelPlacementError, // <-- Pass binding
                modelPlacementErrorMessage: self.$modelPlacementErrorMessage // <-- Pass binding
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
            // Button to toggle court adjustment mode
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        isCourtAdjustmentModeEnabled.toggle()
                        // Optionally provide feedback to CustomARView about the mode change
                        arViewInstance?.isCourtAdjustmentModeEnabled = isCourtAdjustmentModeEnabled
                        print("DEBUG: Court Adjustment Mode: \(isCourtAdjustmentModeEnabled)")
                    }) {
                        Image(systemName: isCourtAdjustmentModeEnabled ? "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left" : "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.title)
                            .padding()
                            .background(isCourtAdjustmentModeEnabled ? Color.blue.opacity(0.7) : Color.white.opacity(0.7))
                            .foregroundColor(isCourtAdjustmentModeEnabled ? .white : .blue)
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, placedModels.contains("hoop_court") ? 100 : 20) // Adjust bottom padding if play button is visible
                }
            }
            // Play button
            let _ = { print("DEBUG: Play button condition - placedModels: \(placedModels), isAnimating: \(isAnimating)") }()
            if placedModels.contains("hoop_court") || placedModels.contains("soccerfield") || placedModels.contains("footballfield") {
                Button(action: {
                    print("DEBUG: Play button pressed.")
                    guard let arView = arViewInstance else {
                        print("DEBUG: Could not find CustomARView instance.")
                        return
                    }
                    // Entities should already be placed when the court was. Only start animation.
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
        .alert(isPresented: $showModelPlacementError) {
            Alert(title: Text("Model Placement Failed"), message: Text(modelPlacementErrorMessage), dismissButton: .default(Text("OK")))
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
            let arPath = drawing.points.map { map2DToAR($0.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight, courtType: play.courtType) }
            let percent: Double = 0.8
            let count = max(2, Int(Double(arPath.count) * percent))
            let shortPath = Array(arPath.suffix(count))
            print("DEBUG: Animating player \(player.id) with path of \(arPath.count) points.")
            let totalDistance = ARPlayView.calculateARPathLength(points: shortPath)
            let duration: TimeInterval = max(0.1, Double(totalDistance) / Double(ARPlayView.walkingSpeed))
            if let entity = entityMap[player.id] as? ModelEntity {
                newAnimationData[player.id] = ARAnimationData(entity: entity, pathPointsAR: shortPath, totalDistance: totalDistance, duration: duration, startTime: Date(), isAnimating: true)
            } else {
                print("DEBUG: No entity found for player \(player.id) in entityMap.")
            }
        }
        // Balls
        for ball in play.balls {
            guard let pathId = ball.assignedPathId,
                  let drawing = play.drawings.first(where: { $0.id == pathId }),
                  !drawing.points.isEmpty else {
                print("DEBUG: Skipping ball \(ball.id) - no assigned path or empty path.")
                continue
            }
            let arPath = drawing.points.map { map2DToAR($0.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight, courtType: play.courtType) }
            let percent: Double = 0.8
            let count = max(2, Int(Double(arPath.count) * percent))
            let shortPath = Array(arPath.suffix(count))
            print("DEBUG: Animating ball \(ball.id) with path of \(arPath.count) points.")
            let totalDistance = ARPlayView.calculateARPathLength(points: shortPath)
            let duration: TimeInterval = max(0.1, Double(totalDistance) / Double(ARPlayView.walkingSpeed))
            if let entity = entityMap[ball.id] as? ModelEntity {
                newAnimationData[ball.id] = ARAnimationData(entity: entity, pathPointsAR: shortPath, totalDistance: totalDistance, duration: duration, startTime: Date(), isAnimating: true)
            } else {
                print("DEBUG: No entity found for ball \(ball.id) in entityMap.")
            }
        }
        // Opponents
        for opponent in play.opponents {
            let arPosition2D = map2DToAR(opponent.position.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight, courtType: play.courtType)
            let arPosition = SIMD3<Float>(arPosition2D.x, 0.05, arPosition2D.z) // Set Y to 0.05 to keep above court
            let opponentEntity: ModelEntity
            if let loaded = try? ModelEntity.loadModel(named: "cylinder") {
                print("DEBUG: Loaded cylinder model for opponent \(opponent.number)")
                opponentEntity = loaded
                opponentEntity.scale = SIMD3<Float>(repeating: 0.0002)
                
                let opponentMaterial = SimpleMaterial(color: .red, isMetallic: false)
                opponentEntity.model?.materials = [opponentMaterial]
                
                // Create a MUCH bigger collision shape for easier selection
                let collisionBox = CollisionComponent(
                    shapes: [.generateBox(size: [0.3, 0.3, 0.3])],
                    mode: .trigger,
                    filter: .sensor
                )
                opponentEntity.collision = collisionBox
            } else {
                print("DEBUG: Failed to load cylinder model for opponent \(opponent.number), using fallback sphere.")
                opponentEntity = ModelEntity(mesh: .generateSphere(radius: 0.008), materials: [SimpleMaterial(color: .red, isMetallic: false)])
                
                // Create a MUCH bigger collision shape for easier selection
                let collisionSphere = CollisionComponent(
                    shapes: [.generateSphere(radius: 0.3)],
                    mode: .trigger,
                    filter: .sensor
                )
                opponentEntity.collision = collisionSphere
            }
            
            opponentEntity.position = arPosition
            opponentEntity.name = "opponent_\(opponent.id)"
            self.mainAnchor().addChild(opponentEntity)
            self.entityMap[opponent.id] = opponentEntity
            if let arView = self.arViewInstance {
                arView.originalPositions[opponent.id] = arPosition
            }
            
            // Make entity draggable
            opponentEntity.generateCollisionShapes(recursive: false)
        }
        // Print camera and entity positions for debugging
        if let cameraPosition = cameraPosition() {
            print("[DEBUG] Camera position: \(cameraPosition)")
        }
        for (id, entity) in self.entityMap {
            print("[DEBUG] Entity \(entity.name) position: \(entity.position)")
        }
        self.printEntityHierarchy()
    }
    func findEntityByName(_ name: String) -> ModelEntity? {
        // Search in the ARView's mainAnchor for an entity with the given name
        let children = mainAnchorChildren()
        return children.compactMap { $0 as? ModelEntity }.first(where: { $0.name == name })
    }

    // Add a method to ContentView to access CustomARView's mainAnchor
    func mainAnchor() -> AnchorEntity {
        return arViewInstance?.mainAnchor ?? AnchorEntity(world: .zero)
    }

    // Add a method to ContentView to access CustomARView's session
    func session() -> ARSession? {
        return arViewInstance?.session
    }

    // Add a method to get the camera position
    func cameraPosition() -> SIMD3<Float>? {
        return arViewInstance?.session.currentFrame?.camera.transform.columns.3.xyz
    }

    // Add a method to ContentView to access CustomARView's printEntityHierarchy
    func printEntityHierarchy() {
        arViewInstance?.printEntityHierarchy()
    }

    // Add a method to ContentView to access CustomARView's originalPositions
    func originalPositions() -> [UUID: SIMD3<Float>]? {
        return arViewInstance?.originalPositions
    }

    // Add a method to ContentView to set a value in CustomARView's originalPositions
    func setOriginalPosition(for id: UUID, position: SIMD3<Float>) {
        arViewInstance?.originalPositions[id] = position
    }

    // Add a method to ContentView to access CustomARView's mainAnchor.children
    func mainAnchorChildren() -> [Entity] {
        guard let childrenCollection = arViewInstance?.mainAnchor.children else { return [] }
        return Array(childrenCollection)
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
    @Binding var showModelPlacementError: Bool
    @Binding var modelPlacementErrorMessage: String
    
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
                    if model.modelName == "hoop_court" || model.modelName == "soccerfield" || model.modelName == "footballfield" {
                        if let focusPosition = customARView.focusEntityPosition() {
                            customARView.mainAnchor.setPosition(focusPosition, relativeTo: nil)
                            print("[DEBUG] Court anchor placed at: \(customARView.mainAnchor.position(relativeTo: nil))")
                            print("[DEBUG] Focus position: \(focusPosition)")
                            if let camPos = customARView.session.currentFrame?.camera.transform.columns.3 {
                                print("[DEBUG] Camera position: \(camPos)")
                            }
                            clonedEntity.setPosition(.zero, relativeTo: nil)
                            // Always set the same fixed rotation
                            if model.modelName == "soccerfield" || model.modelName == "footballfield" {
                                clonedEntity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
                            } else if model.modelName == "hoop_court" {
                                clonedEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
                            }
                            customARView.mainAnchor.addChild(clonedEntity)
                            customARView.lastPlacedEntity = nil // Prevent selection for dragging
                            customARView.toggleFocusEntity(isVisible: false)
                            customARView.removePreview()
                            // Remove collision shapes from ModelEntity children of mainAnchor to prevent hit-testing
                            for child in customARView.mainAnchor.children {
                                if let model = child as? ModelEntity {
                                    model.collision = nil
                                }
                            }
                            // Call placePlayersAndBalls once to add all assets
                            let courtSize = play.courtType == "full" ? CGSize(width: 300, height: 600) : CGSize(width: 300, height: 300)
                            let arCourtWidth: Float = 0.15
                            let arCourtHeight: Float = 0.15 * Float(courtSize.height / courtSize.width)
                            customARView.placePlayersAndBalls(for: play, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight)
                            customARView.printEntityHierarchy()
                            DispatchQueue.main.async {
                                self.modelConfirmedForPlacement = nil
                                self.placedModels.insert(model.modelName)
                                print("DEBUG: placedModels now contains: \(self.placedModels)")
                            }
                            // After adding all player entities in placePlayersAndBalls:
                            let children = Array(customARView.mainAnchor.children)
                            if let testPlayer = children.first(where: { $0.name == "player_44627A68-B4D7-411A-806E-47A4398AD10A" }) as? ModelEntity {
                                customARView.lastPlacedEntity = testPlayer
                                print("[DEBUG] lastPlacedEntity set automatically to: \(testPlayer.name), position: \(testPlayer.position)")
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
                    // General placement for all other models (soccerfield, footballfield, soccerball, football, etc.)
                    if let focusPosition = customARView.focusEntityPosition() {
                        customARView.mainAnchor.setPosition(focusPosition, relativeTo: nil)
                        clonedEntity.setPosition(.zero, relativeTo: nil)
                        // Optionally set orientation if needed
                        // clonedEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
                        customARView.mainAnchor.addChild(clonedEntity)
                        customARView.lastPlacedEntity = nil
                        customARView.toggleFocusEntity(isVisible: false)
                        customARView.removePreview()
                        DispatchQueue.main.async {
                            self.placedModels.insert(model.modelName)
                        }
                    }
                }
                if model.modelName == "hoop_court", let customARView = uiView as? CustomARView {
                    customARView.toggleFocusEntity(isVisible: false)
                }
            } else {
                print("DEBUG: unable to load modelEntity for \(model.modelName)")
                // Show error to user
                DispatchQueue.main.async {
                    self.modelPlacementErrorMessage = "The 3D model for \(model.modelName) could not be loaded. Please try again or check the model file."
                    self.showModelPlacementError = true
                    self.modelConfirmedForPlacement = nil
                }
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
    var mainAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, -2.0))
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
    var isCourtAdjustmentModeEnabled: Bool = false // Property to control adjustment mode
    private var initialMainAnchorScale: SIMD3<Float>? // To store scale at gesture start
    private var initialMainAnchorOrientation: simd_quatf?
    
    // Dictionary to track placed chibi_kids by their model name
    var placedChibiKids: [String: ModelEntity] = [:]
    
    // Add these properties to CustomARView
    private var initialDragXPosition: Float?
    private var initialDragZPosition: Float?
    // Add this property to CustomARView
    private var draggedEntity: ModelEntity?
    private var draggedEntityOriginalMaterials: [SimpleMaterial]?
    private var initialDragScreenPosition: CGPoint?
    private var initialEntityPosition: SIMD3<Float>?
    private var draggedEntityOriginalScale: SIMD3<Float>?
    
    // Store original positions for all moveable entities (players, balls, opponents)
    var originalPositions: [UUID: SIMD3<Float>] = [:]
    
    private let movableNames = [
        "player_44627A68-B4D7-411A-806E-47A4398AD10A",
        "player_64CA0E6B-9277-42AC-B150-0646700D7CC5",
        "player_014C329D-B943-4D0D-9273-1E400B5D0739",
        "ball_14C056EC-591C-4B9D-BF26-A336668BB9AA"
    ]
    
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
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleCustomPan(recognizer:)))
        self.addGestureRecognizer(panGesture)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:)))
        self.addGestureRecognizer(tapGesture)

        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(recognizer:))) // Add pinch gesture
        self.addGestureRecognizer(pinchGesture)

        // Add rotation gesture
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(recognizer:)))
        self.addGestureRecognizer(rotationGesture)
    }
    
    @objc func handleCustomPan(recognizer: UIPanGestureRecognizer) {
        let location = recognizer.location(in: self)
        print("[DEBUG] handleCustomPan state: \(recognizer.state.rawValue), location: \(location)")
        
        switch recognizer.state {
        case .began:
            // When pan begins, find the entity to drag
            let hits = self.hitTest(location)
            print("[DEBUG] Pan began hits count: \(hits.count)")
            for hit in hits {
                print("[DEBUG] Hit entity: \(hit.entity.name)")
            }
            
            // Try direct hitTest
            if let hit = hits.first, let entity = hit.entity as? ModelEntity {
                if entity.name.hasPrefix("player_") || entity.name.hasPrefix("ball_") || entity.name.hasPrefix("opponent_") {
                    print("[DEBUG] Found draggable entity: \(entity.name)")
                    draggedEntity = entity
                    initialDragYPosition = entity.position(relativeTo: nil).y
                    
                    // Store original scale to restore later
                    draggedEntityOriginalScale = entity.scale
                    
                    // Add more obvious visual indicator - change color temporarily
                    if let model = entity.model {
                        // Store original materials for restoration later
                        let originalMaterials = model.materials.compactMap { $0 as? SimpleMaterial }
                        
                        // Make the entity glow/highlight
                        let highlightMaterial = SimpleMaterial(
                            color: entity.name.hasPrefix("player_") ? .yellow : .cyan, 
                            isMetallic: false
                        )
                        entity.model?.materials = [highlightMaterial]
                        
                        // Store original materials to restore later
                        self.draggedEntityOriginalMaterials = originalMaterials
                    }
                    
                    // Scale up for emphasis
                    let originalScale = entity.scale
                    let highlightScale = SIMD3<Float>(
                        originalScale.x * 1.5,
                        originalScale.y * 1.5,
                        originalScale.z * 1.5
                    )
                    entity.scale = highlightScale
                    
                    // Save initial screen location for drag tracking
                    initialDragScreenPosition = location
                    
                    // Save initial entity world position
                    initialEntityPosition = entity.position(relativeTo: nil)
                }
            } else {
                // If no hit, try a brute force method
                print("[DEBUG] No direct hit found, trying manual proximity check")
                
                // Manually check all player, ball, and opponent entities
                var closestEntity: ModelEntity? = nil
                var closestDistance: Float = Float.greatestFiniteMagnitude
                
                for anchor in self.scene.anchors {
                    for child in anchor.children {
                        if let entity = child as? ModelEntity,
                           (entity.name.hasPrefix("player_") || entity.name.hasPrefix("ball_") || entity.name.hasPrefix("opponent_")) {
                            
                            if let screenPos = self.project(entity.position(relativeTo: nil)) {
                                let dx = Float(location.x - screenPos.x)
                                let dy = Float(location.y - screenPos.y)
                                let distance = sqrt(dx*dx + dy*dy)
                                
                                print("[DEBUG] Entity \(entity.name) screen pos: \(screenPos), distance: \(distance)")
                                
                                // Use a large threshold (150 points) to make selection easier
                                if distance < 150 && distance < closestDistance {
                                    closestEntity = entity
                                    closestDistance = distance
                                }
                            }
                        }
                    }
                }
                
                if let entity = closestEntity {
                    print("[DEBUG] Found entity by proximity: \(entity.name) at distance \(closestDistance)")
                    draggedEntity = entity
                    initialDragYPosition = entity.position(relativeTo: nil).y
                    
                    // Store original scale to restore later
                    draggedEntityOriginalScale = entity.scale
                    
                    // Add more obvious visual indicator - change color temporarily
                    if let model = entity.model {
                        // Store original materials for restoration later
                        let originalMaterials = model.materials.compactMap { $0 as? SimpleMaterial }
                        
                        // Make the entity glow/highlight
                        let highlightMaterial = SimpleMaterial(
                            color: entity.name.hasPrefix("player_") ? .yellow : .cyan, 
                            isMetallic: false
                        )
                        entity.model?.materials = [highlightMaterial]
                        
                        // Store original materials to restore later
                        self.draggedEntityOriginalMaterials = originalMaterials
                    }
                    
                    // Scale up for emphasis
                    let originalScale = entity.scale
                    let highlightScale = SIMD3<Float>(
                        originalScale.x * 1.5,
                        originalScale.y * 1.5,
                        originalScale.z * 1.5
                    )
                    entity.scale = highlightScale
                    
                    // Save initial screen location for drag tracking
                    initialDragScreenPosition = location
                    
                    // Save initial entity world position
                    initialEntityPosition = entity.position(relativeTo: nil)
                } else {
                    print("[DEBUG] No draggable entity found near touch point")
                }
            }
            
        case .changed:
            guard let entity = draggedEntity else { return } // This entity is a child of mainAnchor
            let location = recognizer.location(in: self)

            if let hitPointOnCourtPlane_World = projectScreenPointToCourt(location) { // This is a WORLD space point
                // Calculate the target Y in WORLD space, relative to the mainAnchor's base
                let targetEntityY_World = mainAnchor.position(relativeTo: nil).y + 0.01 // Or your desired offset

                // Construct the full target position in WORLD coordinates
                let targetWorldPosition = SIMD3<Float>(hitPointOnCourtPlane_World.x,
                                                     targetEntityY_World,
                                                     hitPointOnCourtPlane_World.z)

                // Convert the target WORLD position to the LOCAL coordinate system of the mainAnchor
                // 'from: nil' means the provided position is in world coordinates.
                let targetLocalPosition = mainAnchor.convert(position: targetWorldPosition, from: nil)

                // Now set the entity's position using these LOCAL coordinates
                entity.position = targetLocalPosition
                
                print("[DEBUG] Dragged entity (local pos): \(entity.position) from World Target: \(targetWorldPosition)")
            }
            
        case .ended, .cancelled:
            print("[DEBUG] Pan ended/cancelled")
            
            // Restore original appearance of the dragged entity
            if let entity = draggedEntity {
                // Restore original scale if available
                if let originalScale = draggedEntityOriginalScale {
                    entity.scale = originalScale
                }
                
                // Restore original materials
                if let originalMaterials = draggedEntityOriginalMaterials, !originalMaterials.isEmpty {
                    entity.model?.materials = originalMaterials
                }
                
                // Ensure position's Y coordinate stays above the court
                var pos = entity.position
                if pos.y < 0.05 {
                    pos.y = 0.05
                    entity.position = pos
                }
            }
            
            // Clear all saved state
            draggedEntity = nil
            initialDragYPosition = nil
            initialDragScreenPosition = nil
            initialEntityPosition = nil
            draggedEntityOriginalMaterials = nil
            draggedEntityOriginalScale = nil
            
        default:
            break
        }
    }
    
    @objc func handleTap(recognizer: UITapGestureRecognizer) {
        let location = recognizer.location(in: self)
        print("[DEBUG] Tap at screen location: \(location)")
        // Print all entities hit at the tap location
        let hits = self.hitTest(location)
        for hit in hits {
            print("[DEBUG] Hit entity: \(hit.entity.name), position: \(hit.entity.position), bounds: \(hit.entity.visualBounds(relativeTo: nil))")
        }
        if let entity = self.entity(at: location) as? ModelEntity {
            print("[DEBUG] entity(at:) returned: \(entity.name)")
            // Allow any ModelEntity except hoop_court to be selected for dragging
            if entity.name != "hoop_court" {
                self.lastPlacedEntity = entity
                print("[DEBUG] lastPlacedEntity set to: \(entity.name), position: \(entity.position)")
                // Visual feedback: scale up briefly
                let originalScale = entity.scale
                let newScale = SIMD3<Float>(originalScale.x * 1.3, originalScale.y * 1.3, originalScale.z * 1.3)
                entity.setScale(newScale, relativeTo: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    entity.setScale(originalScale, relativeTo: nil)
                }
            }
        } else {
            print("[DEBUG] entity(at:) returned nil")
        }
        self.printEntityHierarchy()
    }

    @objc func handlePinch(recognizer: UIPinchGestureRecognizer) { // Pinch gesture handler
        guard isCourtAdjustmentModeEnabled else { return }

        switch recognizer.state {
        case .began:
            // Store the initial scale of the mainAnchor when the gesture starts
            initialMainAnchorScale = self.mainAnchor.scale
        case .changed:
            if let initialScale = initialMainAnchorScale {
                let newScale = initialScale * Float(recognizer.scale)
                self.mainAnchor.scale = newScale
            }
        case .ended, .cancelled:
            // Reset initial scale for the next gesture
            initialMainAnchorScale = nil
        default:
            break
        }
    }
    
    @objc func handleRotation(recognizer: UIRotationGestureRecognizer) {
        guard isCourtAdjustmentModeEnabled else { return }
        switch recognizer.state {
        case .began:
            initialMainAnchorOrientation = mainAnchor.orientation
        case .changed:
            guard let initialOrientation = initialMainAnchorOrientation else { return }
            let rotation = Float(recognizer.rotation)
            let deltaRotation = simd_quatf(angle: rotation, axis: [0, 1, 0])
            mainAnchor.orientation = initialOrientation * deltaRotation
        case .ended, .cancelled:
            initialMainAnchorOrientation = nil
        default:
            break
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
            let materialCount = modelComponent.materials.count
            entity.model?.materials = Array(repeating: transparentMaterial, count: max(1, materialCount))
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
        // originalPositions.removeAll() // Also clear original positions if re-placing everything

        // Remove court collision to prevent blocking hit tests
        if let courtEntity = mainAnchor.children.first(where: { $0.name == "hoop_court" }) as? ModelEntity {
            courtEntity.collision = nil
            print("[DEBUG] Set hoop_court collision to nil")
        }
        // Players
        for player in play.players {
            let arPosition2D = map2DToAR(player.position.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight, courtType: play.courtType)
            let arPosition = SIMD3<Float>(arPosition2D.x, 0.05, arPosition2D.z) // Set Y to 0.05 to keep above court
            let playerEntity: ModelEntity
            if let loaded = try? ModelEntity.loadModel(named: "cylinder") {
                print("DEBUG: Loaded cylinder model for player \(player.number)")
                playerEntity = loaded
                playerEntity.scale = SIMD3<Float>(repeating: 0.0002)
                
                let playerMaterial = SimpleMaterial(color: .green, isMetallic: false)
                playerEntity.model?.materials = [playerMaterial]
                
                // Create a MUCH bigger collision shape for easier selection
                let collisionBox = CollisionComponent(
                    shapes: [.generateBox(size: [0.3, 0.3, 0.3])],
                    mode: .trigger,
                    filter: .sensor
                )
                playerEntity.collision = collisionBox
            } else {
                print("DEBUG: Failed to load cylinder model for player \(player.number), using fallback sphere.")
                playerEntity = ModelEntity(mesh: .generateSphere(radius: 0.008), materials: [SimpleMaterial(color: .green, isMetallic: false)])
                
                // Create a MUCH bigger collision shape for easier selection
                let collisionSphere = CollisionComponent(
                    shapes: [.generateSphere(radius: 0.3)],
                    mode: .trigger,
                    filter: .sensor
                )
                playerEntity.collision = collisionSphere
            }
            
            playerEntity.position = arPosition
            playerEntity.name = "player_\(player.id)"
            self.mainAnchor.addChild(playerEntity)
            self.entityMap[player.id] = playerEntity
            self.originalPositions[player.id] = playerEntity.position(relativeTo: nil) // Store WORLD position
            
            // Make entity draggable
            playerEntity.generateCollisionShapes(recursive: false)
        }
        // Balls
        for ball in play.balls {
            let arPosition2D = map2DToAR(ball.position.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight, courtType: play.courtType)
            let ballARPosition = SIMD3<Float>(arPosition2D.x, 0.05, arPosition2D.z) // Set Y to 0.05 to keep above court
            let ballEntity: ModelEntity
            if let loaded = try? ModelEntity.loadModel(named: "ball") {
                print("DEBUG: Loaded ball model")
                ballEntity = loaded
                ballEntity.scale = SIMD3<Float>(repeating: 0.00045)
                
                // Create a MUCH bigger collision shape for easier selection
                let collisionSphere = CollisionComponent(
                    shapes: [.generateSphere(radius: 0.3)],
                    mode: .trigger,
                    filter: .sensor
                )
                ballEntity.collision = collisionSphere
            } else {
                print("DEBUG: Failed to load ball model, using fallback orange sphere.")
                let ballMaterial = SimpleMaterial(color: .orange, isMetallic: false)
                ballEntity = ModelEntity(mesh: .generateSphere(radius: 0.015), materials: [ballMaterial])
                
                // Create a MUCH bigger collision shape for easier selection
                let collisionSphere = CollisionComponent(
                    shapes: [.generateSphere(radius: 0.3)],
                    mode: .trigger,
                    filter: .sensor
                )
                ballEntity.collision = collisionSphere
            }
            
            ballEntity.position = ballARPosition
            ballEntity.name = "ball_\(ball.id)"
            self.mainAnchor.addChild(ballEntity)
            self.entityMap[ball.id] = ballEntity
            self.originalPositions[ball.id] = ballEntity.position(relativeTo: nil) // Store WORLD position
            
            // Make entity draggable
            ballEntity.generateCollisionShapes(recursive: false)
        }
        // Opponents
        for opponent in play.opponents {
            let arPosition2D = map2DToAR(opponent.position.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight, courtType: play.courtType)
            let arPosition = SIMD3<Float>(arPosition2D.x, 0.05, arPosition2D.z) // Set Y to 0.05 to keep above court
            let opponentEntity: ModelEntity
            if let loaded = try? ModelEntity.loadModel(named: "cylinder") {
                print("DEBUG: Loaded cylinder model for opponent \(opponent.number)")
                opponentEntity = loaded
                opponentEntity.scale = SIMD3<Float>(repeating: 0.0002)
                
                let opponentMaterial = SimpleMaterial(color: .red, isMetallic: false)
                opponentEntity.model?.materials = [opponentMaterial]
                
                // Create a MUCH bigger collision shape for easier selection
                let collisionBox = CollisionComponent(
                    shapes: [.generateBox(size: [0.3, 0.3, 0.3])],
                    mode: .trigger,
                    filter: .sensor
                )
                opponentEntity.collision = collisionBox
            } else {
                print("DEBUG: Failed to load cylinder model for opponent \(opponent.number), using fallback sphere.")
                opponentEntity = ModelEntity(mesh: .generateSphere(radius: 0.008), materials: [SimpleMaterial(color: .red, isMetallic: false)])
                
                // Create a MUCH bigger collision shape for easier selection
                let collisionSphere = CollisionComponent(
                    shapes: [.generateSphere(radius: 0.3)],
                    mode: .trigger,
                    filter: .sensor
                )
                opponentEntity.collision = collisionSphere
            }
            
            opponentEntity.position = arPosition
            opponentEntity.name = "opponent_\(opponent.id)"
            self.mainAnchor.addChild(opponentEntity)
            self.entityMap[opponent.id] = opponentEntity
            self.originalPositions[opponent.id] = opponentEntity.position(relativeTo: nil) // Store WORLD position
            
            // Make entity draggable
            opponentEntity.generateCollisionShapes(recursive: false)
        }
        // Print camera and entity positions for debugging
        if let cameraPosition = cameraPosition() {
            print("[DEBUG] Camera position: \(cameraPosition)")
        }
        for (id, entity) in self.entityMap {
            if let modelEntity = entity as? ModelEntity {
                print("DEBUG: entityMap entry: ID \(id), Entity Name: \(modelEntity.name)")
            } else {
                print("DEBUG: entityMap entry: ID \(id), Entity Type: \(type(of: entity))")
            }
        }
        // Define missingPlayers and missingBalls for debug print
        let missingPlayers = play.players.filter { self.entityMap[$0.id] == nil }
        let missingBalls = play.balls.filter { self.entityMap[$0.id] == nil }
        print("DEBUG: WARNING: Missing entities for animation. Missing players: \(missingPlayers), Missing balls: \(missingBalls)")
        // Build animation data for players
        for player in play.players {
            guard let pathId = player.assignedPathId,
                  let drawing = play.drawings.first(where: { $0.id == pathId }),
                  !drawing.points.isEmpty else {
                print("DEBUG: Skipping player \(player.id) - no assigned path or empty path.")
                continue
            }
            let arPath = drawing.points.map { map2DToAR($0.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight, courtType: play.courtType) }
            let percent: Double = 0.8
            let count = max(2, Int(Double(arPath.count) * percent))
            let shortPath = Array(arPath.suffix(count))
            print("DEBUG: Animating player \(player.id) with path of \(arPath.count) points.")
            let totalDistance = ARPlayView.calculateARPathLength(points: shortPath)
            let duration: TimeInterval = max(0.1, Double(totalDistance) / Double(ARPlayView.walkingSpeed))
            if let entity = entityMap[player.id] as? ModelEntity {
                animationData[player.id] = ARAnimationData(entity: entity, pathPointsAR: shortPath, totalDistance: totalDistance, duration: duration, startTime: Date(), isAnimating: true)
            } else {
                print("DEBUG: No entity found for player \(player.id) in entityMap.")
            }
        }
        // Build animation data for balls
        for ball in play.balls {
            guard let pathId = ball.assignedPathId,
                  let drawing = play.drawings.first(where: { $0.id == pathId }),
                  !drawing.points.isEmpty else {
                print("DEBUG: Skipping ball \(ball.id) - no assigned path or empty path.")
                continue
            }
            let arPath = drawing.points.map { map2DToAR($0.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight, courtType: play.courtType) }
            let percent: Double = 0.8
            let count = max(2, Int(Double(arPath.count) * percent))
            let shortPath = Array(arPath.suffix(count))
            print("DEBUG: Animating ball \(ball.id) with path of \(arPath.count) points.")
            let totalDistance = ARPlayView.calculateARPathLength(points: shortPath)
            let duration: TimeInterval = max(0.1, Double(totalDistance) / Double(ARPlayView.walkingSpeed))
            if let entity = entityMap[ball.id] as? ModelEntity {
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

    // Add this helper function to CustomARView
    func textGen(textString: String) -> ModelEntity {
        let materialVar = SimpleMaterial(color: .white, roughness: 0.0, isMetallic: false)
        let depthVar: Float = 0.05 // much thicker
        let fontVar = UIFont.systemFont(ofSize: 0.3) // much larger font
        let containerFrameVar = CGRect(x: -0.3, y: -0.3, width: 0.6, height: 0.6)
        let alignmentVar: CTTextAlignment = .center
        let lineBreakModeVar : CTLineBreakMode = .byWordWrapping
        let textMeshResource : MeshResource = .generateText(textString,
                                           extrusionDepth: depthVar,
                                           font: fontVar,
                                           containerFrame: containerFrameVar,
                                           alignment: alignmentVar,
                                           lineBreakMode: lineBreakModeVar)
        let textEntity = ModelEntity(mesh: textMeshResource, materials: [materialVar])
        return textEntity
    }

    // Add this debug function to CustomARView
    func printEntityHierarchy() {
        print("--- Entity Hierarchy under mainAnchor ---")
        for child in mainAnchor.children {
            print("- \(child.name) [\(type(of: child))]")
            for grandchild in child.children {
                print("  - \(grandchild.name) [\(type(of: grandchild))]")
            }
        }
        print("----------------------------------------")
    }

    func startAnimation(with play: Models.SavedPlay) {
        print("!!! [CRITICAL DEBUG] START OF CustomARView.startAnimation. Attempting to revert entities. !!!")

        // Revert all moveable entities to their original positions before animating
        print("[DEBUG] Reverting entities. entityMap count: \(entityMap.count). originalPositions count: \(originalPositions.count).")
        if entityMap.isEmpty {
            print("[DEBUG] entityMap is EMPTY during reset attempt.")
        } else {
            for (id, entity) in entityMap {
                guard let modelEntity = entity as? ModelEntity else {
                    print("[DEBUG] Entity with ID \(id) in entityMap is NOT a ModelEntity. Type: \(type(of: entity)). Skipping reset.")
                    continue
                }

                if let originalWorldPos = originalPositions[id] {
                    let originalLocalPos = mainAnchor.convert(position: originalWorldPos, from: nil)
                    var newLocalPos = originalLocalPos
                    newLocalPos.y = max(0.01, originalLocalPos.y) // Ensure slightly above anchor's local origin plane

                    modelEntity.position = newLocalPos // Set the position

                    if modelEntity.name.starts(with: "opponent_") {
                        print("[DEBUG] OPPONENT RESET: \(modelEntity.name) (ID: \(id)) to localPos: \(newLocalPos) (from worldPos: \(originalWorldPos))")
                    } else {
                        print("[DEBUG] ENTITY RESET: \(modelEntity.name) (ID: \(id)) to localPos: \(newLocalPos) (from worldPos: \(originalWorldPos))")
                    }
                } else {
                    print("[DEBUG] NO OriginalPosition found for \(modelEntity.name) (ID: \(id)) in originalPositions. Skipping reset.")
                }
            }
        }
        print("[DEBUG] Entity reversion process COMPLETED.")

        // ----- Original start of animation setup -----
        print("DEBUG: CustomARView.startAnimation called. Clearing previous animationData.")
        animationData.removeAll()
        isAnimating = false // Reset animation state before starting new one

        print("DEBUG: Current entityMap count: \(entityMap.count)")
        for (id, entity) in entityMap {
            if let modelEntity = entity as? ModelEntity {
                print("DEBUG: entityMap entry: ID \(id), Entity Name: \(modelEntity.name)")
            } else {
                print("DEBUG: entityMap entry: ID \(id), Entity Type: \(type(of: entity))")
            }
        }
        print("DEBUG: mainAnchor children count: \(self.mainAnchor.children.count)")
        let children = self.mainAnchor.children
        for child in children {
            print("DEBUG: mainAnchor child: Name \(child.name), ID \(child.id)")
        }

        let courtSize = play.courtType == "full" ? CGSize(width: 300, height: 600) : CGSize(width: 300, height: 300)
        let arCourtWidth: Float = 0.15
        let arCourtHeight: Float = 0.15 * Float(courtSize.height / courtSize.width)
        // Build animation data for players
        for player in play.players {
            guard let pathId = player.assignedPathId,
                  let drawing = play.drawings.first(where: { $0.id == pathId }),
                  !drawing.points.isEmpty else {
                print("DEBUG: Skipping player \(player.id) - no assigned path or empty path.")
                continue
            }
            let arPath = drawing.points.map { map2DToAR($0.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight, courtType: play.courtType) }
            let percent: Double = 0.8
            let count = max(2, Int(Double(arPath.count) * percent))
            let shortPath = Array(arPath.suffix(count))
            print("DEBUG: Animating player \(player.id) with path of \(arPath.count) points.")
            let totalDistance = ARPlayView.calculateARPathLength(points: shortPath)
            let duration: TimeInterval = max(0.1, Double(totalDistance) / Double(ARPlayView.walkingSpeed))
            if let entity = entityMap[player.id] as? ModelEntity {
                animationData[player.id] = ARAnimationData(entity: entity, pathPointsAR: shortPath, totalDistance: totalDistance, duration: duration, startTime: Date(), isAnimating: true)
            } else {
                print("DEBUG: No entity found for player \(player.id) in entityMap.")
            }
        }
        // Build animation data for balls
        for ball in play.balls {
            guard let pathId = ball.assignedPathId,
                  let drawing = play.drawings.first(where: { $0.id == pathId }),
                  !drawing.points.isEmpty else {
                print("DEBUG: Skipping ball \(ball.id) - no assigned path or empty path.")
                continue
            }
            let arPath = drawing.points.map { map2DToAR($0.cgPoint, courtSize: courtSize, arCourtWidth: arCourtWidth, arCourtHeight: arCourtHeight, courtType: play.courtType) }
            let percent: Double = 0.8
            let count = max(2, Int(Double(arPath.count) * percent))
            let shortPath = Array(arPath.suffix(count))
            print("DEBUG: Animating ball \(ball.id) with path of \(arPath.count) points.")
            let totalDistance = ARPlayView.calculateARPathLength(points: shortPath)
            let duration: TimeInterval = max(0.1, Double(totalDistance) / Double(ARPlayView.walkingSpeed))
            if let entity = entityMap[ball.id] as? ModelEntity {
                animationData[ball.id] = ARAnimationData(entity: entity, pathPointsAR: shortPath, totalDistance: totalDistance, duration: duration, startTime: Date(), isAnimating: true)
            } else {
                print("DEBUG: No entity found for ball \(ball.id) in entityMap.")
            }
        }
        isAnimating = !animationData.isEmpty
        print("DEBUG: Animation started in ARView. animationData count: \(animationData.count), isAnimating: \(isAnimating)")
    }

    // Add this function to CustomARView
    func cameraPosition() -> SIMD3<Float>? {
        return self.session.currentFrame?.camera.transform.columns.3.xyz
    }

    // Add this helper to CustomARView
    func projectScreenPointToCourt(_ point: CGPoint) -> SIMD3<Float>? {
        guard let ray = self.ray(through: point) else { return nil }
        let courtOrigin = mainAnchor.position(relativeTo: nil)
        let courtNormal = mainAnchor.transform.matrix.columns.1.xyz // Y axis
        let denom = simd_dot(ray.direction, courtNormal)
        if abs(denom) < 1e-6 { return nil } // Parallel, no intersection
        let t = simd_dot(courtOrigin - ray.origin, courtNormal) / denom
        if t < 0 { return nil } // Intersection behind camera
        return ray.origin + t * ray.direction
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
            name: "Preview Play",
            dateCreated: Date(),
            lastModified: Date(),
            courtType: "full",
            drawings: [],
            players: [],
            balls: [],
            opponents: []
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

func map2DToAR(_ point: CGPoint, courtSize: CGSize, arCourtWidth: Float, arCourtHeight: Float, courtType: String = "") -> SIMD3<Float> {
    let xNorm = Float(point.x / courtSize.width)
    let zNorm = Float(point.y / courtSize.height)
    if courtType == "Soccer Pitch" || courtType == "Football Field" {
        // Swap and flip axes for correct orientation
        let x = (zNorm - 0.5) * arCourtWidth - 0.19
        let z = (0.5 - xNorm) * arCourtHeight + 0.02
        return SIMD3<Float>(x, 0.05, z)
    } else {
        // Default (basketball)
        let x = (xNorm - 0.5) * arCourtWidth - 0.19
        let z = (zNorm - 0.5) * arCourtHeight + 0.02
        return SIMD3<Float>(x, 0.05, z)
    }
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

// here is end

