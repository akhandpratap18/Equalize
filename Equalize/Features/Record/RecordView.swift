import SwiftUI
import SwiftData
import AVFoundation
import Speech
import UniformTypeIdentifiers

struct RecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager
    @Query private var courses: [Course]
    
    @State private var voiceManager = VoiceAssistantManager()
    
    @State private var recordingFileURL: URL?
    @State private var isRecording = false
    @State private var isPaused = false
    @State private var showSaveSheet = false
    @State private var showAddCourse = false
    
    @State private var showUploadPicker = false
    @State private var showVideoAlert = false
    
    @State private var accumulatedTranscript = ""
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?

    var body: some View {
        NavigationStack {
            ZStack {
                // ── Full-bleed classroom illustration ────────────────
                Image("Design 4")
                    .resizable()
                    .scaledToFill()
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                    .clipped()
                    .ignoresSafeArea()

                VStack {
                    LinearGradient(
                        colors: [.black.opacity(0.6), .black.opacity(0.2), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 250)
                    
                    Spacer()
                    
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 350)
                }
                .ignoresSafeArea()

                // ── UI overlay ───────────────────────────────────────
                VStack(spacing: 0) {
                    if !isRecording && !isPaused {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Record")
                                .font(.system(size: 38, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                            Text("Capture your lectures\nand let AI take care\nof the rest.")
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.95))
                                .lineSpacing(4)
                                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 28)
                        .padding(.top, 72)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                    }
                    
                    Spacer()
                    
                    if isRecording || isPaused {
                        // ── Active Recording UI ───────────────────────────────────────
                        VStack(spacing: 32) {
                            Text(formatDuration(recordingDuration))
                                .font(.system(size: 48, weight: .light).monospacedDigit())
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                            
                            // Live Transcript snippet
                            if let errorMsg = voiceManager.errorMessage {
                                Text(errorMsg)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            } else {
                                Text(voiceManager.recognizedText.isEmpty ? "Listening..." : voiceManager.recognizedText)
                                    .font(.body)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .frame(height: 70)
                                    .padding(.horizontal, 40)
                                    .animation(.easeInOut, value: voiceManager.recognizedText)
                            }
                            
                            // Audio Level Waveform

                            HStack(spacing: 4) {
                                ForEach(0..<5) { i in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white)
                                        .frame(width: 4, height: CGFloat.random(in: 10...30) * CGFloat(voiceManager.audioLevel))
                                        .animation(.linear(duration: 0.1), value: voiceManager.audioLevel)
                                }
                            }
                            .frame(height: 40)
                            
                            HStack(spacing: 40) {

                                // Pause / Resume
                                Button {
                                    withAnimation {
                                        isPaused.toggle()
                                        voiceManager.isPaused = isPaused
                                    }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white.opacity(0.2))
                                            .frame(width: 64, height: 64)
                                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                
                                // Stop
                                Button {
                                    stopRecording()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .strokeBorder(.white, lineWidth: 3)
                                            .frame(width: 80, height: 80)
                                        
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(red: 0.85, green: 0.35, blue: 0.3))
                                            .frame(width: 32, height: 32)
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 140)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        // ── Idle Recording UI ───────────────────────────────────────
                        VStack(spacing: 24) {
                            Text("Choose a way to capture your lecture")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.8))
                            
                            HStack(spacing: 32) {
                                // 1. Upload
                                VStack(spacing: 12) {
                                    Button {
                                        showUploadPicker = true
                                    } label: {
                                        Circle()
                                            .fill(Color.white.opacity(0.2))
                                            .frame(width: 60, height: 60)
                                            .overlay(Image(systemName: "square.and.arrow.up").font(.title2).foregroundStyle(.white))
                                    }
                                    Text("Upload")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                }
                                
                                // 2. Audio (Primary)
                                VStack(spacing: 12) {
                                    Button {
                                        startRecording()
                                    } label: {
                                        ZStack {
                                            Circle().strokeBorder(.white, lineWidth: 4).frame(width: 80, height: 80)
                                            Circle().fill(Color(red: 0.85, green: 0.35, blue: 0.3)).frame(width: 60, height: 60)
                                            Image(systemName: "mic.fill").font(.title).foregroundStyle(.white)
                                        }
                                    }
                                    Text("Audio")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                }
                                
                                // 3. Video
                                VStack(spacing: 12) {
                                    Button {
                                        showVideoAlert = true
                                    } label: {
                                        Circle()
                                            .fill(Color.white.opacity(0.2))
                                            .frame(width: 60, height: 60)
                                            .overlay(Image(systemName: "video.fill").font(.title2).foregroundStyle(.white))
                                    }
                                    Text("Video")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                        .padding(.bottom, 140)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 18) {
                        Button {
                            showAddCourse = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        
                        NavigationLink(destination: ProfileView()) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showSaveSheet) {
                SaveRecordingSheet(
                    courses: courses,
                    transcript: accumulatedTranscript,
                    duration: Int(recordingDuration / 60),
                    recordingFileURL: recordingFileURL
                ) {
                    // completion
                    accumulatedTranscript = ""
                    recordingDuration = 0
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showAddCourse) {
                // Since this isn't fully built in this snippet, provide a simple placeholder or the real AddCourseView if it exists
                // The prompt says "make the + button work in record tab". Let's show a minimal add course view.
                AddCourseSheet()
            }
            .fileImporter(isPresented: $showUploadPicker, allowedContentTypes: [.audio, .movie, .video]) { result in
                switch result {
                case .success(let pickedURL):
                    guard pickedURL.startAccessingSecurityScopedResource() else { return }
                    defer { pickedURL.stopAccessingSecurityScopedResource() }
                    let ext = pickedURL.pathExtension
                    let localCopy = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
                    try? FileManager.default.copyItem(at: pickedURL, to: localCopy)
                    recordingFileURL = localCopy
                    accumulatedTranscript = ""
                    recordingDuration = 0
                    showSaveSheet = true
                case .failure(let error):
                    print("Upload failed: \(error)")
                }
            }
            .alert("Video Camera", isPresented: $showVideoAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("In-app video recording is not yet supported in this version. Please use the Upload option to process video files.")
            }
            .onChange(of: voiceManager.recognizedText) { _, newText in
                if !isRecording {
                    accumulatedTranscript = newText
                }
            }
        }
    }

    
    private func startRecording() {
        accumulatedTranscript = ""
        recordingDuration = 0
        voiceManager.recognizedText = ""
        voiceManager.startListening()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isRecording = true
            isPaused = false
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !isPaused {
                recordingDuration += 1
            }
        }
    }

    private func stopRecording() {
        voiceManager.stopListening()
        recordingFileURL = voiceManager.recordingFileURL
        
        timer?.invalidate()
        timer = nil
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isRecording = false
            isPaused = false
        }
        
        // Let the mic stop fully before presenting the sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showSaveSheet = true
        }
    }
    
    private func formatDuration(_ time: TimeInterval) -> String {
        let min = Int(time) / 60
        let sec = Int(time) % 60
        return String(format: "%02d:%02d", min, sec)
    }
}

// MARK: - Add Course Sheet
struct AddCourseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager
    @State private var courseName = ""
    @State private var instructor = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Course Details")) {
                    TextField("Course Name", text: $courseName)
                    TextField("Instructor", text: $instructor)
                }
            }
            .navigationTitle("New Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newCourse = Course(name: courseName, instructor: instructor)
                        modelContext.insert(newCourse)
                        dismiss()
                    }
                    .disabled(courseName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Save Recording Sheet
struct SaveRecordingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager
    
    let courses: [Course]
    let transcript: String
    let duration: Int
    let recordingFileURL: URL?
    var onSaved: () -> Void
    
    @State private var selectedCourseId: String? = nil
    @State private var newCourseName = ""
    @State private var newCourseInstructor = ""
    @State private var lessonTitle = ""
    @State private var saveMode: SaveMode = .existing
    
    enum SaveMode {
        case existing, new
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 0) {
                        ForEach([SaveMode.existing, SaveMode.new], id: \.self) { mode in
                            Text(mode == .existing ? "Existing Course" : "New Course")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(saveMode == mode ? Color(uiColor: .systemBackground) : Color.clear)
                                .foregroundStyle(saveMode == mode ? Color.primary : Color.secondary)
                                .clipShape(Capsule())
                                .contentShape(Capsule())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        saveMode = mode
                                    }
                                }
                        }
                    }
                    .padding(4)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(Capsule())
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 4)
                }
                
                Section("Lesson Details") {
                    TextField("Lecture Title (e.g. Intro to OSI)", text: $lessonTitle)
                }
                
                if saveMode == .existing {
                    Section("Select Course") {
                        if courses.isEmpty {
                            Text("No courses found. Create a new one.")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Course", selection: $selectedCourseId) {
                                Text("Select a course").tag(String?.none)
                                ForEach(courses) { course in
                                    Text(course.name).tag(String?.some(course.id))
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                        }
                    }
                } else {
                    Section("New Course Details") {
                        TextField("Course Name", text: $newCourseName)
                        TextField("Prof/Teacher Name (Optional)", text: $newCourseInstructor)
                    }
                }
            }
            .navigationTitle("Save Lecture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        onSaved()
                        dismiss()
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLecture()
                        onSaved()
                        dismiss()
                    }
                    .disabled(lessonTitle.isEmpty || (saveMode == .existing && selectedCourseId == nil) || (saveMode == .new && newCourseName.isEmpty))
                }
            }
            .onAppear {
                if let first = courses.first {
                    selectedCourseId = first.id
                }
            }
        }
    }
    
    private func saveLecture() {
        let activeCourse: Course
        
        if saveMode == .new {
            let instructor = newCourseInstructor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unknown" : newCourseInstructor
            activeCourse = Course(name: newCourseName, instructor: instructor)
            modelContext.insert(activeCourse)
        } else {
            guard let cid = selectedCourseId, let existing = courses.first(where: { $0.id == cid }) else { return }
            activeCourse = existing
        }
        
        let newLesson = Lesson(
            title: lessonTitle,
            date: Date(),
            durationMinutes: max(1, duration),
            lectureNumber: activeCourse.lessons.count + 1,
            notesMarkdown: transcript.isEmpty ? "" : "## Transcript\n" + transcript,
            rawTranscript: transcript
        )
        
        // Move file to DocumentDirectory so the OS doesn't delete it
        var permanentFileURL: URL? = nil
        if let tempURL = recordingFileURL {
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destURL = docDir.appendingPathComponent(tempURL.lastPathComponent)
            try? FileManager.default.moveItem(at: tempURL, to: destURL)
            permanentFileURL = destURL
        }
        
        let ext = permanentFileURL?.pathExtension.lowercased() ?? "m4a"
        let isVideo = ["mp4", "mov", "m4v"].contains(ext)
        newLesson.sourceType = isVideo ? .importedVideo : .liveCaptureAudio
        newLesson.status = .queued
        newLesson.localRawFileURL = permanentFileURL

        activeCourse.lessons.append(newLesson)
        
        if let fileURL = permanentFileURL {
            let queued = QueuedUpload(
                lessonId: newLesson.id,
                localFileURL: fileURL,
                courseId: activeCourse.id,
                title: lessonTitle,
                sourceType: isVideo ? "IMPORTED_VIDEO" : "LIVE_CAPTURE_AUDIO",
                fileExtension: ext
            )
            modelContext.insert(queued)
        }
        try? modelContext.save()
        
        Task { await syncManager.syncPending() }
    }
}
