struct AuthView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var inputError: String?
    @State private var showPassword = false

    var body: some View {
        // Rest of the view code...
    }
} 