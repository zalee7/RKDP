import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var passwordsMatch: Bool { password == confirmPassword && !password.isEmpty }

    var body: some View {
        ZStack {
            AppTheme.arenaBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Text("Create Account")
                        .font(.title.bold()).foregroundStyle(AppTheme.textPrimary)
                        .padding(.top)

                    VStack(spacing: 14) {
                        StyledTextField(placeholder: "Username", text: $username)
                        StyledTextField(placeholder: "Email", text: $email, keyboardType: .emailAddress)
                        StyledTextField(placeholder: "Password", text: $password, isSecure: true)
                        StyledTextField(placeholder: "Confirm Password", text: $confirmPassword, isSecure: true)
                    }
                    .padding(.horizontal)

                    if !confirmPassword.isEmpty && !passwordsMatch {
                        Text("Passwords don't match").foregroundStyle(.red).font(.caption)
                    }
                    if let err = auth.errorMessage {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }

                    HStack(spacing: 6) {
                        Text("🎁").font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("New players start with 500 coins!").font(.callout.bold()).foregroundStyle(AppTheme.textPrimary)
                            Text("Wager in matches and unlock titles from the daily shop.").font(.caption).foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.cardBorder, lineWidth: 1))
                    .padding(.horizontal)

                    Button {
                        guard passwordsMatch else { return }
                        Task { await auth.signUp(email: email, password: password, username: username) }
                    } label: {
                        Group {
                            if auth.isLoading { ProgressView().tint(.white) }
                            else { Text("Create Account").fontWeight(.bold) }
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(passwordsMatch ? AppTheme.brandGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: passwordsMatch ? AppTheme.accent.opacity(0.4) : .clear, radius: 8)
                    }
                    .padding(.horizontal)
                    .disabled(!passwordsMatch || auth.isLoading)
                }
            }
        }
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left").foregroundStyle(AppTheme.accentBright)
                }
            }
        }
    }
}
