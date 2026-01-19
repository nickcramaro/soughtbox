import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var isSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text("SoughtBox")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Organize your life together")
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(spacing: 16) {
                    if isSignUp {
                        TextField("Name", text: $viewModel.name)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                    }

                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUp ? .newPassword : .password)
                }
                .padding(.horizontal)

                if let error = viewModel.error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Button {
                    Task {
                        if isSignUp {
                            await viewModel.signUp()
                        } else {
                            await viewModel.login()
                        }
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(isSignUp ? "Sign Up" : "Log In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
                .padding(.horizontal)

                Button {
                    withAnimation {
                        isSignUp.toggle()
                        viewModel.error = nil
                    }
                } label: {
                    Text(isSignUp ? "Already have an account? Log in" : "Don't have an account? Sign up")
                        .font(.footnote)
                }

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel())
}
