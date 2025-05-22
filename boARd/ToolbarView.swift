import SwiftUI

struct ToolbarView: View {
    @Binding var selectedTool: DrawingTool
    @Binding var selectedPenStyle: PenStyle
    @Binding var playbackState: PlaybackState
    @Binding var isPathAssignmentMode: Bool
    let pathCount: Int
    let isEditable: Bool
    let onAddPlayer: () -> Void
    let onAddBasketball: () -> Void
    let onAddOpponent: () -> Void
    let onUndo: () -> Void
    let onClear: () -> Void
    let onPlayAnimation: () -> Void
    let onPauseAnimation: () -> Void
    let onAssignPath: () -> Void
    let onAssignBall: () -> Void
    let isAssigningBall: Bool
    let onToolChange: (DrawingTool) -> Void
    let onSave: () -> Void
    var body: some View {
        HStack(spacing: 20) {
            if isEditable {
                ToolButton(icon: "pencil.tip", selectedTool: $selectedTool, currentTool: .pen, action: { onToolChange(.pen) })
                ToolButton(icon: "arrow.right", selectedTool: $selectedTool, currentTool: .arrow, action: { onToolChange(.arrow) })
                ToolButton(icon: "hand.point.up.left", selectedTool: $selectedTool, currentTool: .move, action: { onToolChange(.move) })
                Button(action: onAddPlayer) {
                    Image(systemName: "person.fill").font(.title2).frame(width: 44, height: 44).foregroundColor(.green)
                }
                Button(action: onAddOpponent) {
                    Image(systemName: "person.fill").font(.title2).frame(width: 44, height: 44).foregroundColor(.red)
                }
                Button(action: onAddBasketball) {
                    Image(systemName: "basketball.fill").font(.title2).frame(width: 44, height: 44).foregroundColor(.orange)
                }
                Spacer()
                Button(action: onAssignPath) {
                    HStack {
                        Image(systemName: isPathAssignmentMode ? "arrow.triangle.pull.fill" : "arrow.triangle.pull")
                        Text("\(pathCount)")
                    }
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .background(isPathAssignmentMode ? Color.blue.opacity(0.7) : Color.gray.opacity(0.2))
                    .foregroundColor(isPathAssignmentMode ? .white : .primary)
                    .cornerRadius(8)
                }
                Button(action: onAssignBall) {
                    Image(systemName: "basketball.fill")
                        .font(.title2)
                        .foregroundColor(isAssigningBall ? .white : .primary)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isAssigningBall ? Color.blue.opacity(0.7) : Color.gray.opacity(0.2))
                        )
                }
                .padding(.leading, 0)
                playbackControls
                Spacer()
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward").font(.title2).frame(width: 44, height: 44)
                }
                Button(action: onClear) {
                    Image(systemName: "trash").font(.title2).frame(width: 44, height: 44).foregroundColor(.red)
                }
                Button(action: onSave) {
                    Image(systemName: "square.and.arrow.down").font(.title2).frame(width: 44, height: 44)
                }
            }
        }
        .padding()
        .frame(height: 50)
    }
    @ViewBuilder
    private var playbackControls: some View {
        if playbackState == .playing {
            Button(action: onPauseAnimation) {
                Image(systemName: "pause.fill").font(.title2).frame(width: 44, height: 44).foregroundColor(.red)
            }
        } else {
            Button(action: onPlayAnimation) {
                Image(systemName: "play.fill").font(.title2).frame(width: 44, height: 44).foregroundColor(.green)
            }
        }
    }
}

struct ToolButton: View {
    let icon: String
    @Binding var selectedTool: DrawingTool
    let currentTool: DrawingTool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(selectedTool == currentTool ? .blue : .gray)
                .frame(width: 44, height: 44)
                .background(selectedTool == currentTool ? Color.blue.opacity(0.2) : Color.clear)
                .cornerRadius(8)
        }
    }
} 