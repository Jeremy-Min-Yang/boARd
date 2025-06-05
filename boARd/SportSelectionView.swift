import SwiftUI

// Assuming CourtType enum exists and has cases like .full, .half, .soccer, .football
// For the purpose of this view, we'll use a temporary local enum or rely on specific cases.

struct SportSelectionView: View {
    @Binding var isPresented: Bool
    var onSportSelected: (CourtType) -> Void // Callback with the chosen sport's CourtType

    var body: some View {
        NavigationView { // Wrap in NavigationView for a title and cleaner presentation
            VStack(spacing: 20) {
                Text("Select a Sport")
                    .font(.title2)
                    .padding(.top)

                Button(action: {
                    isPresented = false
                    // This will trigger the CourtSelectionView in HomeScreen for full/half
                    onSportSelected(.full) // Or a generic .basketball if you have it
                }) {
                    SportOptionCard(title: "Basketball", imageName: "basketball_icon_large") // Placeholder image
                }

                Button(action: {
                    isPresented = false
                    onSportSelected(.soccer)
                }) {
                    SportOptionCard(title: "Soccer", imageName: "soccer_icon_large") // Placeholder image
                }

                Button(action: {
                    isPresented = false
                    onSportSelected(.football)
                }) {
                    SportOptionCard(title: "Football", imageName: "football_icon_large") // Placeholder image
                }
                
                Spacer()
                
                Button(action: {
                    isPresented = false // Just dismiss the sheet
                }) {
                    Text("Cancel")
                        .foregroundColor(.red)
                        .padding()
                }
                .padding(.bottom)
            }
            .navigationTitle("New Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct SportOptionCard: View {
    var title: String
    var imageName: String // You'll need to add these images to your assets

    var body: some View {
        HStack {
            Image(imageName) // Make sure these images exist in your assets
                .resizable()
                .renderingMode(.template) // if they are single color icons
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .foregroundColor(.primary)
                .padding(.leading)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .padding(.trailing)
        }
        .padding(.vertical, 15)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct SportSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        SportSelectionView(isPresented: .constant(true), onSportSelected: { sport in
            print("Selected sport: \(sport)")
        })
    }
} 