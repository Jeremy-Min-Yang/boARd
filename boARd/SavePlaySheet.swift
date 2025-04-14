import SwiftUI

struct SavePlaySheet: View {
    @Environment(\.dismiss) var dismiss // Environment value to dismiss the sheet

    @Binding var playNameInput: String // Binding to the text field input from the parent
    var onSave: () -> Void // Closure to execute when save is tapped

    var body: some View {
        NavigationView { // Embed in NavigationView for title and potential future buttons
            VStack(spacing: 20) {
                Text("Enter a name for your play:")
                    .font(.headline)
                    .padding(.top)

                TextField("Play Name", text: $playNameInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .autocapitalization(.words)

                Spacer() // Push buttons to the bottom

                HStack {
                    Button("Cancel") {
                        playNameInput = "" // Clear input on cancel
                        dismiss() // Dismiss the sheet
                    }
                    .padding()
                    .buttonStyle(.bordered) // Use bordered style

                    Spacer()

                    Button("Save") {
                        // Perform the save action passed from the parent
                        onSave()
                        // Dismiss the sheet automatically after save action
                        // dismiss() // saveCurrentPlay will set the binding, dismissing it.
                    }
                    .padding()
                    .buttonStyle(.borderedProminent) // Use prominent style for save
                    .disabled(playNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) // Disable if name is empty
                }
                .padding()
            }
            .navigationTitle("Save Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { // Add explicit cancel button in toolbar as well (good practice)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                         playNameInput = ""
                         dismiss()
                    }
                }
            }
        }
    }
}

// Optional: Preview Provider for SavePlaySheet
struct SavePlaySheet_Previews: PreviewProvider {
    static var previews: some View {
        // Provide dummy state and action for preview
        SavePlaySheet(playNameInput: .constant("My Awesome Play"), onSave: { print("Preview Save Tapped") })
    }
} 