import Network
import SwiftData
import Foundation
import SwiftUI
import Speech

extension URL {
    var safeDocumentURL: URL {
        guard self.path.contains("/Application/") else { return self }
        if let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return docDir.appendingPathComponent(self.lastPathComponent)
        }
        return self
    }
}

@Observable
final class SyncManager {
    private let monitor = NWPathMonitor()
    var isOnline = false
    var uploadingLessonId: String? = nil

    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
                if path.status == .satisfied {
                    await self?.syncPending()
                }
            }
        }
        monitor.start(queue: DispatchQueue.global())
    }

    // MARK: - Sync all pending uploads

    @MainActor
    func syncPending() async {
        let context = container.mainContext
        
        // 1. Resume uploads
        let uploadDescriptor = FetchDescriptor<QueuedUpload>(predicate: #Predicate { $0.uploaded == false })
        if let pending = try? context.fetch(uploadDescriptor) {
            for upload in pending {
                uploadingLessonId = upload.lessonId
                await performUpload(upload: upload)
                uploadingLessonId = nil
            }
        }
        
        // 2. Resume polling for lessons stuck in PROCESSING state
        let processingDescriptor = FetchDescriptor<Lesson>(predicate: #Predicate { $0.statusRaw == "PROCESSING" })
        if let processing = try? context.fetch(processingDescriptor) {
            for lesson in processing {
                if let cId = lesson.course?.id {
                    Task { @MainActor in await self.pollStatus(lessonId: lesson.id, courseId: cId) }
                }
            }
        }
    }

    // MARK: - Force upload a specific lesson

    @MainActor
    func uploadNow(lesson: Lesson) async {
        let context = container.mainContext
        let lessonId = lesson.id
        let descriptor = FetchDescriptor<QueuedUpload>(
            predicate: #Predicate { $0.lessonId == lessonId && $0.uploaded == false }
        )
        guard let upload = try? context.fetch(descriptor).first else { return }
        uploadingLessonId = upload.lessonId
        await performUpload(upload: upload)
        uploadingLessonId = nil
    }

    @MainActor
    func retryUpload(lesson: Lesson) async {
        let context = container.mainContext
        let lessonId = lesson.id
        
        // Find existing upload or create one if needed
        let descriptor = FetchDescriptor<QueuedUpload>(
            predicate: #Predicate { $0.lessonId == lessonId }
        )
        var uploadToRetry: QueuedUpload? = try? context.fetch(descriptor).first
        
        if let existing = uploadToRetry {
            existing.uploaded = false
        } else if let fileURL = lesson.localRawFileURL, let courseId = lesson.course?.id {
            // Reconstruct if it somehow got deleted
            let ext = fileURL.pathExtension.lowercased()
            let newUpload = QueuedUpload(
                lessonId: lesson.id,
                localFileURL: fileURL,
                courseId: courseId,
                title: lesson.title,
                sourceType: lesson.sourceType == .importedVideo ? "IMPORTED_VIDEO" : "LIVE_CAPTURE_AUDIO",
                fileExtension: ext.isEmpty ? "m4a" : ext
            )
            context.insert(newUpload)
            uploadToRetry = newUpload
        }
        
        try? context.save()
        
        if let upload = uploadToRetry {
            lesson.statusRaw = "QUEUED"
            uploadingLessonId = upload.lessonId
            await performUpload(upload: upload)
            uploadingLessonId = nil
        }
    }

    // MARK: - Core upload + processing trigger

    @MainActor
    private func performUpload(upload: QueuedUpload) async {
        let context = container.mainContext
        let auth = CognitoAuthManager.shared
        guard auth.isAuthenticated else { return }

        // If file doesn't exist (e.g., from old bug where it was in tmp directory), mark failed and skip
        let safeURL = upload.localFileURL.safeDocumentURL
        if !FileManager.default.fileExists(atPath: safeURL.path) {
            print("[SyncManager] File missing for lesson \(upload.lessonId). Skipping upload.")
            upload.uploaded = true
            updateLessonStatus(lessonId: upload.lessonId, status: "FAILED", progress: nil)
            try? context.save()
            return
        }

        do {
            // 1. Init lecture → get presigned S3 URL
            let (_, uploadURL, rawS3Key) = try await APIClient.initLecture(
                userId: auth.currentUserId,
                courseId: upload.courseId,
                lessonId: upload.lessonId,
                title: upload.title,
                sourceType: upload.sourceType,
                fileExtension: upload.fileExtension
            )

            // 2. Upload the raw audio/video file
            try await APIClient.uploadRawFile(to: uploadURL, fileURL: safeURL)

            // Get the lesson to fetch its local transcript
            let lessonId = upload.lessonId
            var rawTranscript = ""
            var lessonRef: Lesson? = nil
            let lessonDescriptor = FetchDescriptor<Lesson>(predicate: #Predicate { $0.id == lessonId })
            if let lesson = try? context.fetch(lessonDescriptor).first {
                lessonRef = lesson
                rawTranscript = lesson.rawTranscript
            }
            
            // 2b. If the transcript is empty, perform robust offline transcription now!
            if rawTranscript.isEmpty {
                updateLessonStatus(lessonId: lessonId, status: "TRANSCRIBING LOCALLY", progress: nil)
                
                do {
                    let generatedTranscript = try await transcribeFileLocally(url: safeURL)
                    if !generatedTranscript.isEmpty {
                        rawTranscript = generatedTranscript
                    } else {
                        rawTranscript = "[System Error: Transcription returned an empty string. The audio file might be silent or the Simulator dictation engine failed.]"
                    }
                } catch {
                    rawTranscript = "[System Error: SFSpeechRecognizer failed with error: \(error.localizedDescription)]"
                }
                
                if let lesson = lessonRef {
                    lesson.rawTranscript = rawTranscript
                    lesson.notesMarkdown = "## Transcript\n" + rawTranscript
                    try? context.save()
                }
                updateLessonStatus(lessonId: lessonId, status: "PROCESSING", progress: nil)
            }

            // 3. Trigger the Step Functions pipeline
            try await APIClient.completeUpload(
                lessonId: upload.lessonId,
                coursePK: "COURSE#\(upload.courseId)",
                sourceType: upload.sourceType,
                rawS3Key: rawS3Key,
                rawTranscript: rawTranscript
            )

            // 4. Mark as uploaded in SwiftData
            upload.uploaded = true
            try? context.save()

            // 5. Start polling for completion
            Task { @MainActor in await self.pollStatus(lessonId: upload.lessonId, courseId: upload.courseId) }

        } catch {
            print("[SyncManager] Upload failed for lesson \(upload.lessonId): \(error)")
        }
    }

    // MARK: - Poll until COMPLETE then download notes

    @MainActor
    private func pollStatus(lessonId: String, courseId: String, attempt: Int = 0) async {
        guard attempt < 180 else { return } // max ~15 minutes
        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

        do {
            let statusResp = try await APIClient.pollStatus(
                lessonId: lessonId,
                coursePK: "COURSE#\(courseId)"
            )

            // Update Lesson.status in SwiftData
            updateLessonStatus(lessonId: lessonId, status: statusResp.status, progress: statusResp.progress)

            if statusResp.status == "COMPLETE" {
                if let notesText = statusResp.notesText {
                    cacheNotes(lessonId: lessonId, notes: notesText)
                }
            } else if statusResp.status == "FAILED" {
                print("🚨🚨🚨 AWS PIPELINE FAILED! ERROR: \(statusResp.errorMessage ?? "Unknown")")
                return
            } else {
                // Still processing — keep polling
                await pollStatus(lessonId: lessonId, courseId: courseId, attempt: attempt + 1)
            }
        } catch {
            print("[SyncManager] Poll failed: \(error)")
            await pollStatus(lessonId: lessonId, courseId: courseId, attempt: attempt + 1)
        }
    }

    @MainActor
    private func updateLessonStatus(lessonId: String, status: String, progress: Int?) {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Lesson>(predicate: #Predicate { $0.id == lessonId })
        if let lesson = try? context.fetch(descriptor).first {
            lesson.statusRaw = status
            if let p = progress {
                lesson.uploadProgress = Double(p) / 100.0
            }
            try? context.save()
        }
    }

    struct AIChapter: Decodable {
        let timestamp: String
        let title: String
        let description: String?
        let text: String
    }
    
    struct AIResponse: Decodable {
        let overview: String?
        let topics: String?
        let notes: String?
        let chapters: [AIChapter]?
        let flashcards: [Flashcard]?
    }

    @MainActor
    func translateLesson(lesson: Lesson, languageName: String, bcp47Code: String, pollyVoice: String) async {
        do {
            let response = try await APIClient.translateLesson(lessonId: lesson.id, courseId: lesson.course?.id ?? "", targetLanguage: languageName, pollyVoice: pollyVoice)
            // Store the BCP-47 code (e.g. "ta-IN") locally for AVSpeechSynthesizer — NOT the response value
            lesson.targetLanguage = bcp47Code
            
            // Cache translated text
            // Cache translated text
            var cleanJSON = response.translatedNotesText.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanJSON.hasPrefix("```") {
                cleanJSON = cleanJSON.replacingOccurrences(of: "```json", with: "")
                cleanJSON = cleanJSON.replacingOccurrences(of: "```", with: "")
            }
            if let data = cleanJSON.data(using: .utf8), let aiResponse = try? JSONDecoder().decode(AIResponse.self, from: data) {
                lesson.translatedSummary = aiResponse.overview
                lesson.translatedTopics = aiResponse.topics
                lesson.translatedNotesMarkdown = aiResponse.notes
                
                if let chapters = aiResponse.chapters {
                    var modifiedTranscript = ""
                    for chapter in chapters {
                        modifiedTranscript += "\(chapter.timestamp)|[CHAPTER] \(chapter.title)\n"
                        modifiedTranscript += "\(chapter.timestamp)|\(chapter.text)\n"
                    }
                    lesson.translatedRawTranscript = modifiedTranscript
                }
            } else {
                lesson.translatedNotesMarkdown = response.translatedNotesText
            }
            
            // Download audio recap
            if let audioUrlStr = response.translatedAudioUrl, let audioUrl = URL(string: audioUrlStr) {
                let (audioData, _) = try await URLSession.shared.data(from: audioUrl)
                let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let destURL = docDir.appendingPathComponent("recap_\(lesson.id)_\(bcp47Code).mp3")
                try audioData.write(to: destURL)
                lesson.audioRecapURL = destURL
            }
            
            try? container.mainContext.save()
        } catch {
            print("Translation failed: \(error)")
        }
    }


    @MainActor
    func generateFlashcards(lesson: Lesson) async {
        let url = APIClient.apiBaseURL.appendingPathComponent("generate_flashcards")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = APIClient.idToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let context = container.mainContext
        let fetchDescriptor = SwiftData.FetchDescriptor<Course>()
        let courses = try? context.fetch(fetchDescriptor)
        let course = courses?.first(where: { $0.lessons.contains(where: { l in l.id == lesson.id }) })
        let courseId = course?.id ?? "unknown"
        
        let coursePK = "COURSE#\(courseId)"
        let lessonSK = "LESSON#\(lesson.id)"
        
        let body: [String: String] = [
            "coursePK": coursePK,
            "lessonSK": lessonSK
        ]
        
        request.httpBody = try? JSONEncoder().encode(body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            struct FlashcardResponse: Codable {
                let flashcards: [Flashcard]
            }
            if let response = try? JSONDecoder().decode(FlashcardResponse.self, from: data) {
                lesson.flashcardsData = try? JSONEncoder().encode(response.flashcards)
                
                try? container.mainContext.save()
            }
        } catch {
            print("Failed to generate flashcards: \(error)")
        }
    }

    @MainActor
    private func cacheNotes(lessonId: String, notes: String) {
        let context = container.mainContext
        let lessonDescriptor = FetchDescriptor<Lesson>(predicate: #Predicate { $0.id == lessonId })
        let lesson = try? context.fetch(lessonDescriptor).first
        
        var parsedNotes = notes
        
        // Attempt to parse AI JSON
        if let data = notes.data(using: .utf8), let aiResponse = try? JSONDecoder().decode(AIResponse.self, from: data) {
            lesson?.summary = aiResponse.overview ?? ""
            lesson?.topics = aiResponse.topics ?? ""
            parsedNotes = aiResponse.notes ?? notes
            
            if let flashcards = aiResponse.flashcards {
                lesson?.flashcardsData = try? JSONEncoder().encode(flashcards)
            }
            
            if let chapters = aiResponse.chapters {
                var modifiedTranscript = ""
                for chapter in chapters {
                    modifiedTranscript += "\(chapter.timestamp)|[CHAPTER] \(chapter.title)\n"
                    if let desc = chapter.description, !desc.isEmpty {
                        modifiedTranscript += "\(chapter.timestamp)|[DESC] \(desc)\n"
                    }
                    modifiedTranscript += "\(chapter.timestamp)|\(chapter.text)\n"
                }
                lesson?.rawTranscript = modifiedTranscript
            }
        }
        
        if let lesson = lesson {
            lesson.notesMarkdown = parsedNotes
            lesson.statusRaw = "COMPLETE"
        }

        // Upsert CachedLessonContent
        let cacheDescriptor = FetchDescriptor<CachedLessonContent>(predicate: #Predicate { $0.lessonId == lessonId })
        if let existing = try? context.fetch(cacheDescriptor).first {
            existing.notesText = parsedNotes
            existing.cachedAt = .now
        } else {
            context.insert(CachedLessonContent(lessonId: lessonId, notesText: parsedNotes))
        }
        try? context.save()
    }

    private func transcribeFileLocally(url: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            throw NSError(domain: "SyncManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "SFSpeechRecognizer could not be initialized for en-US."])
        }
        guard recognizer.isAvailable else {
            throw NSError(domain: "SyncManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "SFSpeechRecognizer is unavailable. (Are you on a Simulator? You might need to enable Dictation in Settings -> Keyboard -> Enable Dictation)."])
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        
        return try await withCheckedThrowingContinuation { continuation in
            var returned = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    if !returned {
                        returned = true
                        continuation.resume(throwing: error)
                    }
                    return
                }
                if let result = result, result.isFinal {
                    if !returned {
                        returned = true
                        continuation.resume(returning: result.bestTranscription.formattedString)
                    }
                }
            }
        }
    }
}
