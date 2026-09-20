import Foundation
import SwiftData

enum LessonSourceType: String, Codable {
    case liveCaptureAudio
    case importedAudio
    case importedVideo
}

enum LessonStatus: String, Codable {
    case local = "LOCAL"
    case queued = "QUEUED"
    case uploading = "UPLOADING"
    case processing = "PROCESSING"
    case complete = "COMPLETE"
    case failed = "FAILED"
}

// MARK: - Course

@Model
final class Course {
    var id: String
    var name: String
    var instructor: String
    var thumbnailIndex: Int   // 1-4 → maps to "Design 1" … "Design 4"
    var lastInteractedAt: Date?
    @Relationship(deleteRule: .cascade) var lessons: [Lesson]

    // MARK: Computed helpers

    var sortedLessons: [Lesson] {
        lessons.sorted { $0.lectureNumber < $1.lectureNumber }
    }

    /// Last lesson with any progress, or the first lesson if none started.
    var activeLesson: Lesson? {
        sortedLessons.last(where: { $0.progress > 0 }) ?? sortedLessons.first
    }

    /// 0-1 average across all lessons.
    var overallProgress: Double {
        guard !lessons.isEmpty else { return 0 }
        return lessons.reduce(0.0) { $0 + $1.progress } / Double(lessons.count)
    }

    init(id: String = UUID().uuidString,
         name: String,
         instructor: String,
         thumbnailIndex: Int = Int.random(in: 1...5)) {
        self.id = id
        self.name = name
        self.instructor = instructor
        self.thumbnailIndex = thumbnailIndex
        self.lessons = []
    }
}

// MARK: - Lesson

@Model
final class Lesson {
    var id: String
    var title: String
    var date: Date
    var durationMinutes: Int
    var progress: Double        // 0.0 – 1.0 (Playback)
    var uploadProgress: Double = 0.0 // 0.0 - 1.0 (Backend Processing)
    var lectureNumber: Int
    var notesMarkdown: String
    var rawTranscript: String
    var summary: String = ""
    var topics: String = ""
    
    // Translation & AI additions
    var translatedNotesMarkdown: String?
    var translatedRawTranscript: String?
    var translatedSummary: String?
    var translatedTopics: String?
    var targetLanguage: String?
    var audioRecapURL: URL?
    var flashcardsData: Data?

    var sourceTypeRaw: String = LessonSourceType.liveCaptureAudio.rawValue
    var statusRaw: String = LessonStatus.local.rawValue
    var localRawFileURL: URL?

    var sourceType: LessonSourceType {
        get { LessonSourceType(rawValue: sourceTypeRaw) ?? .liveCaptureAudio }
        set { sourceTypeRaw = newValue.rawValue }
    }
    var status: LessonStatus {
        get { LessonStatus(rawValue: statusRaw) ?? .local }
        set { statusRaw = newValue.rawValue }
    }

    @Relationship(inverse: \Course.lessons) var course: Course?

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    var parsedTranscript: [TranscriptLine] {
        rawTranscript.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "|", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return TranscriptLine(timestamp: String(parts[0]), text: String(parts[1]))
        }
    }

    init(id: String = UUID().uuidString,
         title: String,
         date: Date,
         durationMinutes: Int,
         progress: Double = 0.0,
         lectureNumber: Int,
         notesMarkdown: String = "",
         rawTranscript: String = "",
         sourceType: LessonSourceType = .liveCaptureAudio,
         status: LessonStatus = .complete,
         localRawFileURL: URL? = nil) {
        self.id = id
        self.title = title
        self.date = date
        self.durationMinutes = durationMinutes
        self.progress = progress
        self.lectureNumber = lectureNumber
        self.notesMarkdown = notesMarkdown
        self.rawTranscript = rawTranscript
        self.sourceTypeRaw = sourceType.rawValue
        self.statusRaw = status.rawValue
        self.localRawFileURL = localRawFileURL
    }
}

// MARK: - TranscriptLine (in-memory only)

struct TranscriptLine: Identifiable, Hashable {
    let id = UUID()
    let timestamp: String
    let text: String
    var isChapter: Bool = false
}

// MARK: - Flashcard

struct Flashcard: Identifiable, Codable, Hashable {
    var id = UUID()
    let question: String
    let options: [String]
    let correctAnswer: Int
    
    enum CodingKeys: String, CodingKey {
        case question
        case options
        case correctAnswer
    }
}
