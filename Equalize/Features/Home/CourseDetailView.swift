import SwiftUI
import WebKit
import SwiftData

// MARK: - Course Detail View (Folder)
struct CourseDetailView: View {
    let course: Course
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncManager.self) private var syncManager


    var body: some View {

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // ── Hero Image ─────────────────────────────────────
                Image("Design \(course.thumbnailIndex)")
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width, height: 360)
                    .clipped()

                // ── White Content Sheet ────────────────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    // Course Meta
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.name)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color(red: 0.05, green: 0.1, blue: 0.15))
                        Text(course.instructor)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    
                    // Tags
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.caption)
                            Text("\(course.lessons.count) Lectures")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                        
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.caption)
                            let totalMinutes = course.lessons.reduce(0) { $0 + $1.durationMinutes }
                            let hours = max(1, totalMinutes / 60)
                            Text("~ \(hours) hours")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    // Header for List
                    HStack {
                        Text("Course Content")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color(red: 0.05, green: 0.1, blue: 0.15))
                        Spacer()
                        Text("\(course.lessons.count) Lectures")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 12)

                    // Tab Content
                    LecturesContent(course: course)
                }
                .background(Color.white)
                .clipShape(CustomCorner(radius: 24, corners: [.topLeft, .topRight]))
                .offset(y: -24)
                .padding(.bottom, -24)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.regularMaterial, in: Circle())
                        .environment(\.colorScheme, .dark)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Share", action: {})
                    Button("Delete", role: .destructive, action: {})
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.regularMaterial, in: Circle())
                        .environment(\.colorScheme, .dark)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.white.ignoresSafeArea())
    }
}

// Custom corner shape for top rounding
struct CustomCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Lectures Content

struct LecturesContent: View {
    let course: Course
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(course.sortedLessons.enumerated()), id: \.element.id) { index, lesson in
                NavigationLink(destination: LessonPlayerView(lesson: lesson, course: course)) {
                    LectureRowCard(lesson: lesson, index: index)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
}

struct LectureRowCard: View {
    let lesson: Lesson
    let index: Int
    
    var body: some View {
        HStack(spacing: 16) {
            // Circle Icon
            ZStack {
                Circle()
                    .fill(index == 0 ? Color(red: 0.25, green: 0.4, blue: 0.3) : Color(.systemGray6))
                    .frame(width: 44, height: 44)
                
                if index == 0 {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(lesson.lectureNumber)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(red: 0.15, green: 0.18, blue: 0.22))
                
                HStack(spacing: 6) {
                    Text("\(lesson.formattedDate) • \(lesson.durationMinutes) min")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(red: 0.97, green: 0.96, blue: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Lesson Player View (pushed from lecture row)
struct LessonPlayerView: View {
    let lesson: Lesson
    let course: Course
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncManager.self) private var syncManager
    @State private var selectedTab: DetailTab = .overview
    @State private var isShowingAskSheet = false
    @State private var audioPlayer = AudioPlayerViewModel()
    @State private var notesSynthesizer = NotesSynthesizer()
    @State private var nativeAudioPlayer = AudioPlayerViewModel()
    @State private var showTranslated = false
    @State private var isTranslating = false
    @State private var explainText: String? = nil
    
    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case notes = "Notes"
        case transcript = "Transcript"
        case practice = "Practice"
    }


    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func requestTranslation(bcp47: String, languageName: String, voice: String) async {
        isTranslating = true
        await syncManager.translateLesson(lesson: lesson, languageName: languageName, bcp47Code: bcp47, pollyVoice: voice)
        isTranslating = false
        showTranslated = true
    }

    var body: some View {
        let isVideo = lesson.sourceType == .importedVideo
        let durationSec = audioPlayer.duration > 0 ? audioPlayer.duration : Double(lesson.durationMinutes) * 60
        let progressSec = audioPlayer.currentTime > 0 ? audioPlayer.currentTime : durationSec * lesson.progress
        let progressRatio = audioPlayer.duration > 0 ? audioPlayer.progress : max(0.0, min(1.0, lesson.progress))
        
        let displaySummary = showTranslated ? (lesson.translatedSummary ?? lesson.summary) : lesson.summary
        let displayTopics = showTranslated ? (lesson.translatedTopics ?? lesson.topics) : lesson.topics
        var displayNotes: String {
            let notes = showTranslated ? (lesson.translatedNotesMarkdown ?? lesson.notesMarkdown) : lesson.notesMarkdown
            if notes.hasPrefix("{") || notes.hasPrefix("```") {
                var clean = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                clean = clean.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
                if let data = clean.data(using: .utf8), let parsed = try? JSONDecoder().decode(SyncManager.AIResponse.self, from: data) {
                    return parsed.notes ?? notes
                }
                // Fallback: Regex extraction for malformed/truncated JSON
                if let range = clean.range(of: "\"notes\"\\s*:\\s*\"", options: .regularExpression) {
                    let extracted = String(clean[range.upperBound...])
                    var salvaged = extracted
                    if salvaged.hasSuffix("\"}") { salvaged.removeLast(2) }
                    else if salvaged.hasSuffix("\"") { salvaged.removeLast(1) }
                    else if salvaged.hasSuffix("}") { salvaged.removeLast(1) }
                    
                    let pattern = "\\n"
                    let replacement = "\n"
                    salvaged = salvaged.replacingOccurrences(of: pattern, with: replacement)
                    
                    let patternQuote = "\\\""
                    let replacementQuote = "\""
                    salvaged = salvaged.replacingOccurrences(of: patternQuote, with: replacementQuote)
                    return salvaged
                }
            }
            return notes
        }
        let displayTranscript = showTranslated ? (lesson.translatedRawTranscript ?? lesson.rawTranscript) : lesson.rawTranscript

        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // Video Player Area
                    if isVideo {
                        ZStack(alignment: .bottom) {
                            Image("Design \(course.thumbnailIndex)")
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 240, alignment: .center)
                                .clipped()
                                
                            // Center Play Button
                            Button {
                                course.lastInteractedAt = Date()
                                audioPlayer.togglePlayPause()
                            } label: {
                                ZStack {
                                    Circle().fill(.black.opacity(0.4))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                        .foregroundStyle(.white)
                                        .font(.title2)
                                }
                            }
                            .padding(.bottom, 92) // roughly centered
                            
                            // Custom Controls Overlay
                            VStack(spacing: 8) {
                                HStack {
                                    Text(formatTime(progressSec))
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(formatTime(durationSec))
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                    Image(systemName: "viewfinder")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                }
                                
                                // Custom progress slider
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(.white.opacity(0.3)).frame(height: 4)
                                        Capsule().fill(Color(red: 0.5, green: 0.7, blue: 0.6)) // Light green
                                            .frame(width: geo.size.width * progressRatio, height: 4)
                                        Circle().fill(.white)
                                            .frame(width: 12, height: 12)
                                            .offset(x: (geo.size.width * progressRatio) - 6)
                                    }
                                }
                                .frame(height: 12)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }

                    // Content Below Player
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.title)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color(red: 0.05, green: 0.1, blue: 0.15))
                            
                            Text("\(course.name)  •  \(course.instructor)  •  \(lesson.formattedDate)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 16)

                        // Segment Tabs
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(DetailTab.allCases, id: \.self) { tab in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedTab = tab
                                        }
                                    } label: {
                                        Text(tab.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(selectedTab == tab ? .white : .secondary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(selectedTab == tab ? Color(red: 0.25, green: 0.4, blue: 0.3) : Color(.systemGray6))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        
                        if let targetLang = lesson.targetLanguage, lesson.translatedNotesMarkdown != nil {
                            HStack(spacing: 16) {
                                Picker("Language", selection: $showTranslated) {
                                    Text("English").tag(false)
                                    Text(targetLang.uppercased()).tag(true)
                                }
                                .pickerStyle(.segmented)
                                
                                // Accessibility: Read Notes Aloud
                                if selectedTab == .notes {
                                    Button {
                                        if notesSynthesizer.isPlaying {
                                            notesSynthesizer.pause()
                                        } else {
                                            notesSynthesizer.play(text: displayNotes, language: showTranslated ? targetLang : "en-US")
                                        }
                                    } label: {
                                        Image(systemName: notesSynthesizer.isPlaying ? "pause.circle.fill" : "speaker.wave.2.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundStyle(Color(red: 0.25, green: 0.4, blue: 0.3))
                                    }
                                }
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                        }
                        
                        // About this lecture card
                        if selectedTab == .overview {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("About this lecture")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                Text(displaySummary.isEmpty ? "Summary processing..." : displaySummary)
                                    .font(.subheadline)
                                    .foregroundStyle(Color(red: 0.2, green: 0.25, blue: 0.3))
                                    .lineSpacing(4)
                                
                                Divider()
                                
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "clock")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Duration")
                                            .font(.subheadline).fontWeight(.semibold)
                                        Text("\(lesson.durationMinutes) minutes")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                                
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "doc.plaintext")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Topics covered")
                                            .font(.subheadline).fontWeight(.semibold)
                                        Text(displayTopics.isEmpty ? "..." : displayTopics)
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                                
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "book")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Prerequisites")
                                            .font(.subheadline).fontWeight(.semibold)
                                        Text("None")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(20)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.04), radius: 6, y: 3)
                        } else if selectedTab == .notes {
                            NotesSections(markdown: displayNotes, onExplain: { text in
                                explainText = text
                                isShowingAskSheet = true
                            })
                        } else if selectedTab == .transcript {
                            TranscriptContent(transcript: displayTranscript) { time in
                                // Timestamps always correspond to the original audio timeline.
                                // AVSpeechSynthesizer cannot seek, so we only seek the main audio player.
                                audioPlayer.seek(to: time)
                                if !audioPlayer.isPlaying {
                                    audioPlayer.togglePlayPause()
                                }
                            }
                        } else if selectedTab == .practice {
                            PracticeView(lesson: lesson)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Space for sticky bottom bar
                }
            }
            .background(Color(red: 0.97, green: 0.96, blue: 0.95).ignoresSafeArea())
            
            // Sticky Bottom Bar
            if !isVideo {
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Button {
                            course.lastInteractedAt = Date()
                            if showTranslated {
                                if audioPlayer.isPlaying { audioPlayer.togglePlayPause() }
                                if nativeAudioPlayer.isPlaying { nativeAudioPlayer.togglePlayPause() }
                                if notesSynthesizer.isPlaying {
                                    notesSynthesizer.pause()
                                } else {
                                    let cleanText = displayTranscript.split(separator: "\n").compactMap { line -> String? in
                                        let parts = line.split(separator: "|", maxSplits: 1)
                                        guard parts.count == 2 else { return nil }
                                        let text = String(parts[1])
                                        if text.hasPrefix("[CHAPTER]") || text.hasPrefix("[DESC]") { return nil }
                                        return text
                                    }.joined(separator: " ")
                                    let targetLang = lesson.targetLanguage ?? "en-US"
                                    notesSynthesizer.play(text: cleanText, language: targetLang)
                                }
                            } else {
                                if nativeAudioPlayer.isPlaying { nativeAudioPlayer.togglePlayPause() }
                                notesSynthesizer.stop()
                                audioPlayer.togglePlayPause()
                            }
                        } label: {
                            let isPlaying = showTranslated ? notesSynthesizer.isPlaying : audioPlayer.isPlaying
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(Color(red: 0.25, green: 0.4, blue: 0.3))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                if showTranslated {
                                    let langCode = lesson.targetLanguage ?? ""
                                    let langName = Locale(identifier: "en").localizedString(forIdentifier: langCode)?.components(separatedBy: " ").first ?? langCode.uppercased()
                                    Text("Full \(langName) Audio")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color(red: 0.1, green: 0.15, blue: 0.2))
                                        .lineLimit(1)
                                    Spacer()
                                    if notesSynthesizer.isPlaying || notesSynthesizer.isPaused {
                                        Image(systemName: "waveform")
                                            .foregroundStyle(Color(red: 0.25, green: 0.4, blue: 0.3))
                                            .font(.caption)
                                    }
                                } else {
                                    Text("Full Lecture Audio")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color(red: 0.1, green: 0.15, blue: 0.2))
                                        .lineLimit(1)
                                    Spacer()
                                    let progressSec = audioPlayer.progress * audioPlayer.duration
                                    let durationSec = audioPlayer.duration
                                    Text("\(formatTime(progressSec)) / \(formatTime(durationSec))")
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                            
                            if !showTranslated {
                                Slider(value: Binding(
                                    get: { audioPlayer.progress },
                                    set: { val in audioPlayer.seek(to: val * audioPlayer.duration) }
                                ))
                                .tint(Color(red: 0.25, green: 0.4, blue: 0.3))
                                .frame(height: 20)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .animation(.easeInOut(duration: 0.2), value: isTranslating)
            }
        }
        // ── Translation Loading Overlay ─────────────────────────
        .overlay {
            if isTranslating {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.6)
                        
                        Text("Translating Lecture")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    .padding(32)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.25)))
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(lesson.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if let localUrl = lesson.localRawFileURL {
                audioPlayer.loadAudio(url: localUrl.safeDocumentURL)
            }
        }
        .onChange(of: showTranslated) {
            if notesSynthesizer.isPlaying || notesSynthesizer.isPaused {
                notesSynthesizer.stop()
                notesSynthesizer.play(text: displayNotes, language: showTranslated ? (lesson.targetLanguage ?? "en-US") : "en-US")
            }
        }
        .onDisappear {
            if audioPlayer.isPlaying {
                audioPlayer.togglePlayPause()
            }
            notesSynthesizer.stop()
            lesson.progress = audioPlayer.progress
            try? lesson.modelContext?.save()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        course.lastInteractedAt = Date()
                        try? course.modelContext?.save()
                        explainText = nil
                        isShowingAskSheet = true
                    } label: {
                        Image(systemName: "apple.intelligence")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.99, green: 0.6, blue: 0.21),
                                        Color(red: 0.96, green: 0.3, blue: 0.44),
                                        Color(red: 0.65, green: 0.3, blue: 0.91),
                                        Color(red: 0.17, green: 0.58, blue: 0.95)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Menu {
                        Section("Indian Regional") {
                            Button("Tamil 🇮🇳") { Task { await requestTranslation(bcp47: "ta-IN", languageName: "Tamil", voice: "Aditi") } }
                        }
                        Section("International") {
                            Button("Hindi") { Task { await requestTranslation(bcp47: "hi-IN", languageName: "Hindi", voice: "Kajal") } }
                            Button("Spanish") { Task { await requestTranslation(bcp47: "es-US", languageName: "Spanish", voice: "Lupe") } }
                            Button("French") { Task { await requestTranslation(bcp47: "fr-FR", languageName: "French", voice: "Lea") } }
                        }
                        
                        Section("Options") {
                            Button("Share", action: {})
                            
                            Button {
                                Task { await syncManager.retryUpload(lesson: lesson) }
                                dismiss()
                            } label: {
                                if syncManager.uploadingLessonId == lesson.id {
                                    Label("Processing...", systemImage: "arrow.up.circle")
                                } else {
                                    Label("Reprocess Notes", systemImage: "arrow.clockwise")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

// MARK: - Lesson Content Views
struct NotesContent: View {
    let lessons: [Lesson]

    var body: some View {
        if let lesson = lessons.first(where: { !$0.notesMarkdown.isEmpty || $0.statusRaw == "FAILED" }) {
            VStack(alignment: .leading, spacing: 16) {
                if lesson.statusRaw == "FAILED" {
                    Text("Processing Failed")
                        .font(.headline)
                        .foregroundStyle(.red)
                    Text("Check Xcode console for the exact AWS error message.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    NotesSections(markdown: lesson.notesMarkdown)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        } else {
            ContentUnavailableView("No Notes Yet", systemImage: "doc.text", description: Text("Notes will appear here after processing."))
                .padding(.top, 40)
        }
    }
}

struct NotesSections: View {
    let markdown: String
    var onExplain: ((String) -> Void)? = nil
    @State private var webViewHeight: CGFloat = 200 // Default initial height

    var body: some View {
        RichTextView(markdown: markdown, dynamicHeight: $webViewHeight, onExplain: onExplain)
            .frame(height: webViewHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 20)
    }
}

struct TranscriptBlock: Identifiable {
    var id: String { timestamp + title }
    var timestamp: String
    var title: String
    var description: String
    var text: String
}

struct TranscriptContent: View {
    let transcript: String
    @State private var search = ""
    @State private var expandedBlocks: Set<String> = []
    var onSeek: ((Double) -> Void)? = nil

    var parsedBlocks: [TranscriptBlock] {
        var blocks: [TranscriptBlock] = []
        var currentBlock: TranscriptBlock?
        
        let lines = transcript.split(separator: "\n").compactMap { line -> TranscriptLine? in
            let parts = line.split(separator: "|", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return TranscriptLine(timestamp: String(parts[0]), text: String(parts[1]))
        }
        
        for line in lines {
            if line.text.hasPrefix("[CHAPTER]") {
                if let current = currentBlock { blocks.append(current) }
                let title = line.text.replacingOccurrences(of: "[CHAPTER]", with: "")
                currentBlock = TranscriptBlock(timestamp: line.timestamp, title: title, description: "", text: "")
            } else if line.text.hasPrefix("[DESC]") {
                let desc = line.text.replacingOccurrences(of: "[DESC]", with: "").trimmingCharacters(in: .whitespaces)
                currentBlock?.description = desc
            } else {
                if currentBlock == nil {
                    currentBlock = TranscriptBlock(timestamp: line.timestamp, title: "Introduction", description: "", text: "")
                }
                if currentBlock!.text.isEmpty {
                    currentBlock!.text = line.text
                } else {
                    currentBlock!.text += "\n" + line.text
                }
            }
        }
        if let current = currentBlock { blocks.append(current) }
        return blocks
    }

    private func parseTimestamp(_ ts: String) -> Double {
        let parts = ts.split(separator: ":").compactMap { Double($0) }
        if parts.count == 2 { return parts[0] * 60 + parts[1] }
        if parts.count == 3 { return parts[0] * 3600 + parts[1] * 60 + parts[2] }
        return 0
    }

    var body: some View {
        if !transcript.isEmpty {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search transcript...", text: $search)
                        .font(.subheadline)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.bottom, 16)

                Divider()

                LazyVStack(spacing: 12) {
                    ForEach(filtered(parsedBlocks)) { block in
                        VStack(alignment: .leading, spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if expandedBlocks.contains(block.id) {
                                        expandedBlocks.remove(block.id)
                                    } else {
                                        expandedBlocks.insert(block.id)
                                    }
                                }
                                onSeek?(parseTimestamp(block.timestamp))
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(block.title)
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(Color.primary)
                                                .multilineTextAlignment(.leading)
                                            Spacer()
                                            Text(block.timestamp)
                                                .font(.subheadline)
                                                .foregroundStyle(Color.secondary)
                                                .monospacedDigit()
                                        }
                                        
                                        if !block.description.isEmpty && !expandedBlocks.contains(block.id) {
                                            Text(block.description)
                                                .font(.subheadline)
                                                .foregroundStyle(Color.secondary)
                                                .multilineTextAlignment(.leading)
                                                .lineLimit(2)
                                        }
                                    }
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color(.tertiaryLabel))
                                        .rotationEffect(.degrees(expandedBlocks.contains(block.id) ? 90 : 0))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            if expandedBlocks.contains(block.id) && !block.text.isEmpty {
                                Divider()
                                    .padding(.vertical, 12)
                                Text(block.text)
                                    .font(.body)
                                    .foregroundStyle(Color.primary)
                                    .lineSpacing(4)
                            }
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.top, 16)
            }
            .padding(.top, 8)
        } else {
            ContentUnavailableView("No Transcript Yet", systemImage: "waveform", description: Text("Transcript appears after processing."))
                .padding(.top, 40)
        }
    }

    private func filtered(_ blocks: [TranscriptBlock]) -> [TranscriptBlock] {
        guard !search.isEmpty else { return blocks }
        return blocks.filter { $0.text.localizedCaseInsensitiveContains(search) || $0.title.localizedCaseInsensitiveContains(search) }
    }
}

struct RichTextView: UIViewRepresentable {
    let markdown: String
    @Binding var dynamicHeight: CGFloat
    var onExplain: ((String) -> Void)? = nil
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: RichTextView
        var didLoad = false
        var lastRenderedMarkdown: String?
        
        init(_ parent: RichTextView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightObserver", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = height + 30
                }
            } else if message.name == "explainObserver", let text = message.body as? String {
                DispatchQueue.main.async {
                    self.parent.onExplain?(text)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            didLoad = true
            render(in: webView)
        }
        
        func render(in webView: WKWebView) {
            guard didLoad, parent.markdown != lastRenderedMarkdown else { return }
            lastRenderedMarkdown = parent.markdown
            
            let escapedMarkdown = parent.markdown
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            

            var iconBase64 = ""
            if let image = UIImage(systemName: "apple.intelligence")?.withTintColor(.white, renderingMode: .alwaysOriginal),
               let data = image.pngData() {
                iconBase64 = data.base64EncodedString()
            }
            
            let js = """
            window.appleIntelligenceIconBase64 = '\(iconBase64)';
            try {
                document.getElementById('content').innerHTML = marked.parse(`\(escapedMarkdown)`);
                if (window.renderMathInElement) {
                    renderMathInElement(document.getElementById('content'), {
                        delimiters: [
                            {left: '$$', right: '$$', display: true},
                            {left: '$', right: '$', display: false},
                            {left: '\\(', right: '\\)', display: false},
                            {left: '\\[', right: '\\]', display: true}
                        ]
                    });
                }
                mermaid.init(undefined, document.querySelectorAll('.language-mermaid'));
                
                // Add floating Explain button
                if (!window.explainBtnAdded) {
                    window.explainBtnAdded = true;
                    let btn = document.createElement('button');
                    
                    btn.innerHTML = `<div style="display: inline-block; width: 14px; height: 14px; background: linear-gradient(135deg, #FF9933, #F64C72, #994CFF, #2B95FF); -webkit-mask-image: url('data:image/png;base64,${window.appleIntelligenceIconBase64}'); -webkit-mask-size: contain; -webkit-mask-repeat: no-repeat; vertical-align: middle; margin-right: 6px;"></div><span style="font-weight: 400;">Explain this</span>`;
                    btn.style.position = 'absolute';
                    btn.style.display = 'none';
                    btn.style.zIndex = '1000';
                    btn.style.background = 'rgba(255, 255, 255, 0.75)';
                    btn.style.backdropFilter = 'blur(10px)';
                    btn.style.webkitBackdropFilter = 'blur(10px)';
                    btn.style.color = '#000';
                    btn.style.border = '0.5px solid rgba(0,0,0,0.1)';
                    btn.style.padding = '8px 16px';
                    btn.style.borderRadius = '20px';
                    btn.style.boxShadow = '0 4px 15px rgba(0,0,0,0.15)';
                    btn.style.fontSize = '15px';
                    document.body.appendChild(btn);
                    
                    document.addEventListener('selectionchange', () => {
                        let sel = window.getSelection();
                        if (sel.rangeCount > 0 && !sel.isCollapsed) {
                            let range = sel.getRangeAt(0);
                            let rect = range.getBoundingClientRect();
                            btn.style.top = (rect.top + window.scrollY - 40) + 'px';
                            btn.style.left = (rect.left + window.scrollX + (rect.width/2) - 40) + 'px';
                            btn.style.display = 'block';
                        } else {
                            setTimeout(() => { btn.style.display = 'none'; }, 200);
                        }
                    });
                    
                    // Prevent mousedown from clearing the selection
                    btn.addEventListener('mousedown', (e) => {
                        e.preventDefault();
                    });
                    
                    btn.addEventListener('click', (e) => {
                        e.stopPropagation();
                        let text = window.getSelection().toString();
                        if (text) {
                            window.webkit.messageHandlers.explainObserver.postMessage(text);
                            window.getSelection().removeAllRanges();
                            btn.style.display = 'none';
                        }
                    });
                }
                
                setTimeout(() => {
                    let height = document.documentElement.scrollHeight;
                    window.webkit.messageHandlers.heightObserver.postMessage(height);
                }, 500);
            } catch (e) {
                console.error(e);
            }
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs
        
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "heightObserver")
        userContentController.add(context.coordinator, name: "explainObserver")
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false // Let SwiftUI handle scrolling
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
            <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.css">
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/katex.min.js"></script>
            <script src="https://cdn.jsdelivr.net/npm/katex@0.16.8/dist/contrib/auto-render.min.js"></script>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    font-size: 16px;
                    line-height: 1.6;
                    color: \(UIColor.label.resolvedColor(with: webView.traitCollection).hexString);
                    padding: 10px;
                    margin: 0;
                    user-select: text;
                    -webkit-user-select: text;
                }
                h1, h2, h3 { color: \(UIColor.label.resolvedColor(with: webView.traitCollection).hexString); margin-top: 24px; }
                h1 { font-size: 24px; border-bottom: 1px solid #eaecef; padding-bottom: 8px; }
                h2 { font-size: 20px; border-bottom: 1px solid #eaecef; padding-bottom: 6px; }
                p { margin-top: 0; margin-bottom: 16px; }
                ul, ol { padding-left: 20px; margin-bottom: 16px; }
                li { margin-bottom: 4px; }
                code { background-color: rgba(175, 184, 193, 0.2); padding: 0.2em 0.4em; border-radius: 6px; font-family: ui-monospace, SFMono-Regular, SF Mono, Menlo, Consolas, Liberation Mono, monospace; font-size: 85%; }
                pre { background-color: #f6f8fa; padding: 16px; border-radius: 6px; overflow: auto; }
                pre code { background-color: transparent; padding: 0; font-size: 100%; color: #24292f; }
                blockquote { margin: 0; padding: 0 1em; color: #57606a; border-left: 0.25em solid #d0d7de; }
                img { max-width: 100%; box-sizing: content-box; }
                @media (prefers-color-scheme: dark) {
                    h1 { color: #f7fafc; }
                    h2 { color: #e2e8f0; border-bottom: 1px solid #4a5568; }
                    h3 { color: #e2e8f0; }
                }
                p, ul, ol { margin-top: 0; margin-bottom: 1em; }
                li { margin-bottom: 0.25em; }
                code {
                    font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
                    background-color: rgba(27,31,35,0.05); padding: 0.2em 0.4em; border-radius: 6px; font-size: 85%;
                }
                @media (prefers-color-scheme: dark) { code { background-color: rgba(255,255,255,0.1); } }
                pre { background-color: #f6f8fa; border-radius: 6px; padding: 16px; overflow: auto; }
                @media (prefers-color-scheme: dark) { pre { background-color: #161b22; } }
                pre code { background-color: transparent; padding: 0; }
                blockquote { margin: 0; padding: 0 1em; color: #6a737d; border-left: 0.25em solid #dfe2e5; }
                .mermaid { display: flex; justify-content: center; margin: 1.5em 0; background-color: white; padding: 10px; border-radius: 8px; }
            </style>
        </head>
        <body>
            <div id="content"></div>
            <script>
                mermaid.initialize({ startOnLoad: false, theme: 'default' });
                function renderMarkdown(md) {
                    document.getElementById('content').innerHTML = marked.parse(md);
                    if (window.renderMathInElement) {
                        renderMathInElement(document.getElementById('content'), {
                            delimiters: [
                                {left: '$$', right: '$$', display: true},
                                {left: '$', right: '$', display: false},
                                {left: '\\(', right: '\\)', display: false},
                                {left: '\\[', right: '\\]', display: true}
                            ]
                        });
                    }
                    document.querySelectorAll('pre code.language-mermaid').forEach((block) => {
                        const div = document.createElement('div');
                        div.className = 'mermaid'; div.textContent = block.textContent;
                        block.parentNode.replaceWith(div);
                    });
                    mermaid.run({ querySelector: '.mermaid' });
                    setTimeout(() => {
                        window.webkit.messageHandlers.heightObserver.postMessage(document.documentElement.scrollHeight);
                    }, 200);
                }
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.render(in: uiView)
    }
}

extension UIColor {
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

