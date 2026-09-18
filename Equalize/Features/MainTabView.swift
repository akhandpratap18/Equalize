import SwiftUI
import SwiftData

// MARK: - Main Tab Bar
// Four persistent tabs: Home | Record | Ask | Profile

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            RecordView()
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }
        }
        .tint(.blue)   // selected-tab accent
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Course.self, Lesson.self], inMemory: true)
}
