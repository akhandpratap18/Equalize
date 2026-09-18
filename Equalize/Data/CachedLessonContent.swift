import Foundation
import SwiftData

@Model
final class CachedLessonContent {
    var lessonId: String
    var notesText: String
    var cachedAt: Date

    init(lessonId: String, notesText: String) {
        self.lessonId = lessonId
        self.notesText = notesText
        self.cachedAt = .now
    }
}
