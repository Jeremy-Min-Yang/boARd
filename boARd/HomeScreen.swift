import SwiftUI

struct HomeScreen: View {
    @State private var showCourtOptions = false
    @State private var selectedCourtType: CourtType?
    @State private var navigateToWhiteboard = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                // App title
                VStack {
                    Text("boARd")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 50)
                    
                    Spacer()
                    
                    // Empty state message
                    Text("Create a new whiteboard session")
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                
                // Floating action button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showCourtOptions.toggle()
                        }) {
                            Image(systemName: "plus")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding(25)
                    }
                }
                
                // Court selection overlay
                if showCourtOptions {
                    CourtSelectionView(isPresented: $showCourtOptions, onCourtSelected: { courtType in
                        selectedCourtType = courtType
                        navigateToWhiteboard = true
                    })
                }
                
                // Navigation link (hidden)
                NavigationLink(
                    destination: selectedCourtType.map { WhiteboardView(courtType: $0) },
                    isActive: $navigateToWhiteboard,
                    label: { EmptyView() }
                )
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct CourtSelectionView: View {
    @Binding var isPresented: Bool
    var onCourtSelected: (CourtType) -> Void
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }
            
            // Court options
            VStack(spacing: 20) {
                Text("Select Court Type")
                    .font(.headline)
                    .padding(.top)
                
                Button(action: {
                    isPresented = false
                    onCourtSelected(.full)
                }) {
                    CourtOptionCard(title: "Full Court", imageName: "fullcourt")
                }
                
                Button(action: {
                    isPresented = false
                    onCourtSelected(.half)
                }) {
                    CourtOptionCard(title: "Half Court", imageName: "halfcourt")
                }
                
                Button(action: {
                    isPresented = false
                }) {
                    Text("Cancel")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .frame(width: 300)
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 10)
        }
    }
}

struct CourtOptionCard: View {
    var title: String
    var imageName: String
    
    var body: some View {
        HStack {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 60)
                .cornerRadius(8)
            
            Text(title)
                .font(.title2)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .frame(width: 280, height: 80)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreen()
    }
} 