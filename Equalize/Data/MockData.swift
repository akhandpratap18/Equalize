import SwiftUI
import SwiftData

// MARK: - Seed data matching the mockup exactly

@MainActor
final class MockData {
    static let shared = MockData()
    private init() {}

    func populate(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Course>()
        guard let existing = try? modelContext.fetch(descriptor), existing.isEmpty else { return }

        let cal = Calendar.current
        func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: d))!
        }

        let mlNotes = """
**Key Concepts**

• Definition of Machine Learning
• Types: Supervised, Unsupervised, Reinforcement
• Real-world applications
• Bias-Variance tradeoff

**Important Formulas**

y = wᵀx + b

• Linear model for regression
• w = weights, x = input, b = bias

**Summary**

Machine learning enables computers to learn patterns from data and make predictions or decisions without being explicitly programmed.
"""
        let mlTranscript = """
00:00|Welcome everyone to today's lecture...
00:32|Let's begin with the definition of machine learning...
02:17|In supervised learning, we use labeled data...
05:03|Linear regression is one of the simplest models...
07:26|The cost function measures...
10:14|Gradient descent helps us...
"""

        // ── Machine Learning ──────────────────────────────────
        let ml = Course(name: "Machine Learning", instructor: "Prof. Sarah", thumbnailIndex: 1)
        let mlLessons: [Lesson] = [
            Lesson(title: "Lecture 1 – Introduction",      date: date(2026, 9, 4),  durationMinutes: 45, progress: 1.0, lectureNumber: 1, notesMarkdown: mlNotes, rawTranscript: mlTranscript),
            Lesson(title: "Lecture 2 – Linear Regression", date: date(2026, 9, 6),  durationMinutes: 50, progress: 0.9, lectureNumber: 2, notesMarkdown: mlNotes, rawTranscript: mlTranscript),
            Lesson(title: "Lecture 3 – Gradient Descent",  date: date(2026, 9, 9),  durationMinutes: 48, progress: 0.4, lectureNumber: 3, notesMarkdown: mlNotes, rawTranscript: mlTranscript),
            Lesson(title: "Lecture 4 – Neural Networks",   date: date(2026, 9, 11), durationMinutes: 52, progress: 0.0, lectureNumber: 4, notesMarkdown: mlNotes, rawTranscript: mlTranscript),
        ]
        mlLessons.forEach { $0.course = ml; modelContext.insert($0) }
        modelContext.insert(ml)

        // ── Data Structures ────────────────────────────────────
        let ds = Course(name: "Data Structures", instructor: "Prof. Alan", thumbnailIndex: 2)
        let dsLessons: [Lesson] = [
            Lesson(title: "Lecture 1 – Arrays & Lists",   date: date(2026, 9, 4), durationMinutes: 38, progress: 1.0, lectureNumber: 1),
            Lesson(title: "Lecture 2 – Stacks & Queues",  date: date(2026, 9, 7), durationMinutes: 42, progress: 0.5, lectureNumber: 2),
        ]
        dsLessons.forEach { $0.course = ds; modelContext.insert($0) }
        modelContext.insert(ds)

        // ── Operating Systems ──────────────────────────────────
        let os = Course(name: "Operating Systems", instructor: "Prof. Michael", thumbnailIndex: 3)
        let osLessons: [Lesson] = [
            Lesson(title: "Lecture 1 – Intro to OS",          date: date(2026, 9, 4), durationMinutes: 45, progress: 1.0, lectureNumber: 1),
            Lesson(title: "Lecture 2 – Processes",             date: date(2026, 9, 6), durationMinutes: 48, progress: 0.9, lectureNumber: 2),
            Lesson(title: "Lecture 3 – Threads",               date: date(2026, 9, 8), durationMinutes: 44, progress: 0.5, lectureNumber: 3),
            Lesson(title: "Lecture 4 – Memory Management",     date: date(2026, 9, 10), durationMinutes: 50, progress: 0.1, lectureNumber: 4),
        ]
        osLessons.forEach { $0.course = os; modelContext.insert($0) }
        modelContext.insert(os)

        // ── Computer Networks ─────────────────────────────────
        let cn = Course(name: "Computer Networks", instructor: "Prof. Lisa", thumbnailIndex: 4)
        let cnLessons: [Lesson] = [
            Lesson(title: "Lecture 1 – Network Basics", date: date(2026, 9, 4), durationMinutes: 48, progress: 0.1, lectureNumber: 1),
        ]
        cnLessons.forEach { $0.course = cn; modelContext.insert($0) }
        modelContext.insert(cn)
    }
}
