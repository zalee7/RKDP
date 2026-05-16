import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // Logo
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.brandGradient)
                                .frame(width: 90, height: 90)
                                .shadow(color: AppTheme.accent.opacity(0.6), radius: 20)
                            Image(systemName: "puzzlepiece.extension.fill")
                                .font(.system(size: 38))
                                .foregroundStyle(.white)
                        }
                        Text("Grid Duel")
                            .font(.system(size: 36, weight: .black))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Ranked Puzzle Arena")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.accentBright)
                    }

                    // Fields
                    VStack(spacing: 14) {
                        StyledTextField(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                        StyledTextField(placeholder: "Password", text: $password, isSecure: true)
                    }
                    .padding(.horizontal)

                    if let err = auth.errorMessage {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }

                    Button {
                        Task { await auth.signIn(email: email, password: password) }
                    } label: {
                        Group {
                            if auth.isLoading { ProgressView().tint(.white) }
                            else { Text("Sign In").fontWeight(.bold) }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(AppTheme.brandGradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: AppTheme.accent.opacity(0.4), radius: 8)
                    }
                    .padding(.horizontal)
                    .disabled(auth.isLoading)

                    Button("Don't have an account? Sign Up") { showSignUp = true }
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.accentBright)

                    Spacer()
                }
            }
            .navigationDestination(isPresented: $showSignUp) { SignUpView() }
        }
    }
}

struct StyledTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isSecure = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
            }
        }
        .padding()
        .background(Color.white.opacity(0.09))
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}
