import Foundation
import FoundationModels

// MARK: - CourseIntelligenceService
//
// HYBRID ARCHITECTURE:
// AWS processes the lecture (Transcribe + Claude) → generates structured notes → stored in SwiftData.
// This service takes those cached notes and feeds them as context to Apple Intelligence.
// Every Q&A question is answered on-device, for FREE, with no AWS Bedrock cost per query.

@Observable
@MainActor
@available(iOS 26.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
final class CourseIntelligenceService {
    var error: Error?

    // One session per lesson — reused across the Q&A conversation for that lesson
    private var session: LanguageModelSession?
    private var currentLessonId: String?

    // MARK: - Stream a response

    func generateStream(for userPrompt: String, lesson: Lesson?, course: Course?) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    if let lesson {
                        try await self.streamSingleLesson(userPrompt, lesson: lesson, continuation: continuation)
                    } else if let course {
                        try await self.streamCourseWide(userPrompt, course: course, continuation: continuation)
                    } else {
                        continuation.yield("Please select a course or lesson to ask about.")
                        continuation.finish()
                    }
                } catch {
                    Task { @MainActor in self.error = error }
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func streamSingleLesson(_ userPrompt: String, lesson: Lesson, continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        // Reset session if lesson changed
        if lesson.id != self.currentLessonId {
            self.session = nil
            self.currentLessonId = lesson.id
        }

        if self.session == nil {
            let context = self.buildContext(for: lesson)
            let instructions = """
            You are a helpful, intelligent course assistant for a student.

            \(context)

            RULES:
            1. Answer questions ONLY based on the lecture material provided above.
            2. Keep answers clear, concise, and educational.
            3. If a question is clearly outside this lecture's scope, politely say so.
            4. Use the transcript timestamps (e.g. 02:30) to reference specific moments if helpful.
            5. NEVER use Markdown block formatting like headers (###) or bullet points (-). Instead, use bold (**text**) and simple paragraphs.
            """
            self.session = LanguageModelSession(instructions: instructions)
        }

        guard let session = self.session else {
            continuation.finish()
            return
        }

        let stream = session.streamResponse { userPrompt }
        for try await chunk in stream {
            continuation.yield(chunk.content)
        }
        continuation.finish()
    }

    private func streamCourseWide(_ userPrompt: String, course: Course, continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let retrieved: APIClient.RetrieveResponse
        do {
            retrieved = try await APIClient.retrieveContext(question: userPrompt, scope: "course", courseId: course.id)
        } catch {
            continuation.yield("I couldn't search across \(course.name) right now — check your connection and try again.")
            continuation.finish()
            return
        }

        guard !retrieved.citations.isEmpty else {
            continuation.yield("I couldn't find anything in \(course.name) related to that question yet.")
            continuation.finish()
            return
        }

        let excerptsText = retrieved.citations.enumerated().map { i, c in
            "[Excerpt \(i + 1)] (\(Int(c.startTimeSec))s into a lesson): \(c.text)"
        }.joined(separator: "\n\n")

        let instructions = """
        You are a helpful course assistant. Answer the student's question using ONLY
        the excerpts below, pulled from across their course "\(course.name)". If the
        excerpts don't contain the answer, say so honestly rather than guessing.
        Reference which excerpt number(s) you used.
        NEVER use Markdown block formatting like headers (###) or bullet points (-). Instead, use bold (**text**) and simple paragraphs.

        EXCERPTS:
        \(excerptsText)
        """
        let session = LanguageModelSession(instructions: instructions)
        let stream = session.streamResponse { userPrompt }
        for try await chunk in stream {
            continuation.yield(chunk.content)
        }
        continuation.finish()
    }

    func resetSession() {
        session = nil
        currentLessonId = nil
    }

    // MARK: - Build context from cached notes

    private func buildContext(for lesson: Lesson?) -> String {
        guard let lesson else {
            return "No lecture material is available. Let the student know they should select a lecture first."
        }

        var context = "LECTURE: \(lesson.title)\n"

        if !lesson.notesMarkdown.isEmpty {
            // Prefer Claude-generated structured notes (downloaded after backend processing)
            context += "\nLECTURE NOTES:\n\(lesson.notesMarkdown)"
        }

        if !lesson.rawTranscript.isEmpty && lesson.status == .complete {
            // Include timestamped transcript if notes are available (gives Apple Intelligence
            // the ability to reference specific moments like "at 02:30 the professor said...")
            let transcriptLines = lesson.rawTranscript
                .split(separator: "\n")
                .prefix(80) // Cap at ~80 lines to stay within context limits
                .joined(separator: "\n")
            context += "\n\nTIMESTAMPED TRANSCRIPT EXCERPT:\n\(transcriptLines)"
        }

        if lesson.notesMarkdown.isEmpty && lesson.rawTranscript.isEmpty {
            context += "\nThis lecture is still being processed. Please check back in a few minutes."
        }

        return context
    }
}
