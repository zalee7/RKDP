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
        ScrollView {
            VStack(spacing: 24) {
                Text("Create Account").font(.title.bold()).padding(.top)

                VStack(spacing: 14) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)

                if !confirmPassword.isEmpty && !passwordsMatch {
                    Text("Passwords don't match").foregroundStyle(.red).font(.caption)
                }

                if let err = auth.errorMessage {
                    Text(err).foregroundStyle(.red).font(.caption)
                }

                VStack(spacing: 8) {
                    Text("🎁 New players start with 500 coins!")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("Use coins to wager in matches and unlock cosmetics.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    guard passwordsMatch else { return }
                    Task { await auth.signUp(email: email, password: password, username: username) }
                } label: {
                    Group {
                        if auth.isLoading { ProgressView() }
                        else { Text("Create Account").fontWeight(.semibold) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(passwordsMatch ? Color.blue : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .disabled(!passwordsMatch || auth.isLoading)
            }
        }
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
    }
}
