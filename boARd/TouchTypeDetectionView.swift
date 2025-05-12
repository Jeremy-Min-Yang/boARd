import SwiftUI

struct TouchTypeDetectionView: UIViewRepresentable {
    var onTouchesChanged: (TouchInputType, [CGPoint]) -> Void
    var onTouchesEnded: (TouchInputType) -> Void
    var onMove: ((CGPoint) -> Void)?
    var selectedTool: DrawingTool
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
        if uiView.selectedTool != selectedTool {
            uiView.selectedTool = selectedTool
            uiView.resetInternalState()
        }
    }
    class TouchDetectionView: UIView {
        var onTouchesChanged: ((TouchInputType, [CGPoint]) -> Void)?
        var onTouchesEnded: ((TouchInputType) -> Void)?
        var onMove: ((CGPoint) -> Void)?
        var selectedTool: DrawingTool = .pen
        private var currentTouch: UITouch?
        func resetInternalState() {
            currentTouch = nil
        }
        override init(frame: CGRect) {
            super.init(frame: frame)
            isMultipleTouchEnabled = true
            backgroundColor = .clear
        }
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let touch = touches.first else { return }
            currentTouch = touch
            if selectedTool == .move {
                let location = touch.location(in: self)
                onMove?(location)
            } else {
                processTouches(touches, with: event)
            }
        }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            if currentTouch != nil, let updatedTouch = touches.first {
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
            var locations: [CGPoint] = []
            let allTouches = event.coalescedTouches(for: touch) ?? [touch]
            for t in allTouches {
                if #available(iOS 13.4, *), t.type == .pencil {
                    locations.append(t.preciseLocation(in: self))
                } else {
                    locations.append(t.location(in: self))
                }
            }
            onTouchesChanged?(touchType, locations)
        }
    }
} 