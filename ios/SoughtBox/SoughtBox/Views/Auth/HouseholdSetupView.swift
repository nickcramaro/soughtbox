import SwiftUI

struct HouseholdSetupView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var mode: SetupMode = .choice

    enum SetupMode {
        case choice
        case create
        case join
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text("Welcome, \(viewModel.user?.name ?? "")!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Set up your household to get started")
                    .foregroundStyle(.secondary)

                Spacer()

                switch mode {
                case .choice:
                    choiceView
                case .create:
                    createView
                case .join:
                    joinView
                }

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") {
                        Task {
                            await viewModel.logout()
                        }
                    }
                }
            }
        }
    }

    private var choiceView: some View {
        VStack(spacing: 16) {
            Button {
                withAnimation {
                    mode = .create
                }
            } label: {
                VStack {
                    Image(systemName: "house.fill")
                        .font(.largeTitle)
                    Text("Create Household")
                        .font(.headline)
                    Text("Start a new household and invite your partner")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button {
                withAnimation {
                    mode = .join
                }
            } label: {
                VStack {
                    Image(systemName: "envelope.fill")
                        .font(.largeTitle)
                    Text("Join Household")
                        .font(.headline)
                    Text("Enter an invite code from your partner")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    private var createView: some View {
        VStack(spacing: 16) {
            TextField("Household Name", text: $viewModel.householdName)
                .textFieldStyle(.roundedBorder)

            if let error = viewModel.error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button {
                Task {
                    await viewModel.createHousehold()
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            Button("Back") {
                withAnimation {
                    mode = .choice
                    viewModel.error = nil
                }
            }
        }
        .padding(.horizontal)
    }

    private var joinView: some View {
        VStack(spacing: 16) {
            TextField("Invite Code", text: $viewModel.inviteToken)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .autocorrectionDisabled()

            if let error = viewModel.error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            Button {
                Task {
                    await viewModel.acceptInvite()
                }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Join")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            Button("Back") {
                withAnimation {
                    mode = .choice
                    viewModel.error = nil
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    let viewModel = AuthViewModel()
    viewModel.user = User(id: "1", email: "test@test.com", name: "Nick", householdId: nil)
    return HouseholdSetupView(viewModel: viewModel)
}
