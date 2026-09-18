import SwiftUI

// MARK: - Profile Screen  (Tab 4)

struct ProfileView: View {
    // Resetting this to false sends the user back to OnboardingFlow via ContentView
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    var body: some View {
        NavigationView {
            List {
                // ── Account Section ──────────────────────────────
                Section("Account") {
                    NavigationLink("User Profile") {
                        Text("User Profile")
                            .navigationTitle("User Profile")
                    }
                    NavigationLink("Accessibility Settings") {
                        Text("Accessibility Settings")
                            .navigationTitle("Accessibility")
                    }
                }

                // ── Log Out ──────────────────────────────────────
                Section {
                    Button(role: .destructive) {
                        CognitoAuthManager.shared.signOut()
                        hasCompletedOnboarding = false
                    } label: {
                        Text("Log Out")
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
}
