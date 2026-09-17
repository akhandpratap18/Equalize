import SwiftUI
import SwiftData

// MARK: - Root ContentView
//
// Flow:
//   First launch   → OnboardingFlow (Starts at page 0)
//   Returning user → auth.restoreSession() attempts to log in
//                    If valid, shows MainTabView()
//                    If invalid, shows OnboardingFlow (Starts at page 3 / SignInPage)

struct ContentView: View {
    @State private var auth = CognitoAuthManager.shared

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainTabView()
            } else {
                // Handles both first-time tutorial and returning sign-in screen
                OnboardingFlow()
            }
        }
        .onAppear {
            auth.restoreSession()
        }
        .animation(.easeInOut(duration: 0.35), value: auth.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Course.self, Lesson.self], inMemory: true)
}
