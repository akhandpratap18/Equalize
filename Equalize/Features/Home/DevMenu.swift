import SwiftUI
import SwiftData

struct DevMenu: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Danger Zone") {
                    Button(role: .destructive) {
                        try? modelContext.delete(model: Course.self)
                        try? modelContext.delete(model: Lesson.self)
                        try? modelContext.delete(model: QueuedUpload.self)
                        try? modelContext.delete(model: CachedLessonContent.self)
                        try? modelContext.save()
                        
                        // Clear Documents Directory
                        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                        if let files = try? FileManager.default.contentsOfDirectory(at: docDir, includingPropertiesForKeys: nil) {
                            for file in files {
                                try? FileManager.default.removeItem(at: file)
                            }
                        }
                        dismiss()
                    } label: {
                        Text("Wipe All Local Data")
                    }
                }
            }
            .navigationTitle("Developer Tools")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
