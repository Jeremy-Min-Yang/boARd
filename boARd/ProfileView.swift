import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.crop.circle")
                .resizable()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            if let user = authViewModel.user {
                if user.isAnonymous {
                    Text("Guest")
                        .font(.title2)
                        .foregroundColor(.gray)
                } else {
                    Text(user.email ?? "Unknown")
                        .font(.title2)
                }
                Text("User ID: \(user.uid)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Button(action: {
                authViewModel.signOut()
            }) {
                Text("Sign Out")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Profile")
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView().environmentObject(AuthViewModel())
    }
} 