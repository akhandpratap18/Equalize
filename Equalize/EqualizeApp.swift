import SwiftUI
import SwiftData

@main
struct EqualizeApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Course.self, Lesson.self, QueuedUpload.self, CachedLessonContent.self])
        
        // Ensure Application Support directory exists to prevent CoreData error 2
        let fileManager = FileManager.default
        if let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            if !fileManager.fileExists(atPath: appSupportDir.path) {
                try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true, attributes: nil)
            }
        }
        
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }
        let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [fallback])
    }()

    @State private var syncManager: SyncManager

    init() {
        let container = sharedModelContainer
        _syncManager = State(initialValue: SyncManager(container: container))
    }

    var body: some Scene {
        WindowGroup { 
            ContentView() 
        }
        .modelContainer(sharedModelContainer)
        .environment(syncManager)
    }
}
