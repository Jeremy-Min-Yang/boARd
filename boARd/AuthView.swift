import SwiftUI

struct AuthView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var inputError: String?
    @State private var showPassword = false
    
    var body: some View {
        VStack {
            Spacer()
            
            // Container for the form
            VStack(spacing: 20) {
                Text(isSignUp ? "Sign Up" : "Log In")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    ZStack(alignment: .trailing) {
                        Group {
                            if showPassword {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.gray)
                        }
                        .padding(.trailing, 8)
                    }
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    } else if let inputError = inputError {
                        Text(inputError)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Button(action: {
                    inputError = nil
                    let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !isValidEmail(trimmedEmail) {
                        inputError = "Please enter a valid email address."
                        return
                    }
                    if trimmedPassword.count < 6 {
                        inputError = "Password must be at least 6 characters."
                        return
                    }
                    if isSignUp {
                        viewModel.signUp(email: trimmedEmail, password: trimmedPassword)
                    } else {
                        viewModel.signIn(email: trimmedEmail, password: trimmedPassword)
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text(isSignUp ? "Sign Up" : "Log In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .disabled(email.isEmpty || password.isEmpty)
                
                Button(action: {
                    viewModel.signInAnonymously()
                }) {
                    Text("Continue as Guest")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    isSignUp.toggle()
                }) {
                    Text(isSignUp ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                        .font(.footnote)
                        .foregroundColor(.blue)
                }
            }
            .frame(width: 300)
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 8)
            
            Spacer()
        }
        .padding()
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView().environmentObject(AuthViewModel())
    }
} 