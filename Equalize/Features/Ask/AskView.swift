import SwiftUI
import FoundationModels

struct ChatMessage: Identifiable {
    let id = UUID()
    var text: String
    let isUser: Bool
    var isThinking: Bool = false
}

struct AskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var intelligenceService = CourseIntelligenceService()
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    /// The lesson whose notes will be used as Apple Intelligence context.
    var lesson: Lesson? = nil
    var course: Course? = nil
    var initialText: String? = nil
    @State private var hasProcessedInitialText = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.97, green: 0.96, blue: 0.95).ignoresSafeArea()

                VStack(spacing: 0) {
                    if messages.isEmpty { Spacer() }

                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 24) {
                                IntroCard(lessonTitle: lesson?.title)
                                    .padding(.top, messages.isEmpty ? 0 : 24)
                                    .id("top_card")

                                ForEach(messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let last = messages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }

                    if messages.isEmpty { Spacer() }

                    // Processing badge
                    if let lesson, lesson.status != .complete && lesson.status != .local {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("Processing (\(lesson.statusRaw))… answers improve once complete")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 6)
                        .background(Color(.systemGray6)).clipShape(Capsule())
                        .padding(.bottom, 4)
                    }

                    InputBar(text: $inputText, action: sendMessage)
                }
            }
            .navigationTitle("Course Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                }
            }
            .animation(.easeInOut(duration: 0.4), value: messages.isEmpty)
            .onAppear {
                handleInitialText()
            }
            .onChange(of: initialText) {
                handleInitialText()
            }
            .onDisappear { intelligenceService.resetSession() }
        }
    }

    private func handleInitialText() {
        guard !hasProcessedInitialText, let text = initialText, !text.isEmpty else { return }
        hasProcessedInitialText = true
        inputText = "Explain this: \(text)"
        sendMessage()
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(text: text, isUser: true))
        inputText = ""
        isInputFocused = false

        let thinkingMessage = ChatMessage(text: "", isUser: false, isThinking: true)
        messages.append(thinkingMessage)
        let thinkingIndex = messages.count - 1

        Task {
            do {
                // Pass the real lesson and course — context is built from notesMarkdown + rawTranscript or retrieved citations
                let stream = intelligenceService.generateStream(for: text, lesson: lesson, course: course)
                var isFirstChunk = true
                for try await chunk in stream {
                    if isFirstChunk {
                        messages[thinkingIndex].isThinking = false
                        isFirstChunk = false
                    }
                    messages[thinkingIndex].text = chunk
                }
            } catch {
                messages[thinkingIndex].isThinking = false
                messages[thinkingIndex].text = "I'm sorry, I couldn't process that. Make sure Apple Intelligence is enabled in Settings."
            }
        }
    }
}

struct IntroCard: View {
    var lessonTitle: String? = nil
    var body: some View {
        HStack(spacing: 16) {
            Image("Fox 2")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(lessonTitle != nil ? "Studying: \(lessonTitle!)" : "Hi! I'm your course assistant.")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text("Ask me anything about this course — concepts, doubts, notes, or practice questions. How can I help you today?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(red: 0.98, green: 0.94, blue: 0.88), Color(red: 0.96, green: 0.90, blue: 0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !message.isUser {
                Image("Fox 2")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                    .background(Circle().fill(Color.white).shadow(radius: 1))
            } else {
                Spacer(minLength: 40)
            }
            
            if message.isThinking {
                HStack(spacing: 4) {
                    Circle().frame(width: 6, height: 6).opacity(0.4)
                    Circle().frame(width: 6, height: 6).opacity(0.7)
                    Circle().frame(width: 6, height: 6).opacity(1.0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
            } else {
                Text(LocalizedStringKey(message.text))
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(message.isUser ? Color(red: 0.88, green: 0.94, blue: 0.85) : Color.white)
                    .foregroundStyle(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.03), radius: 5, y: 2)
            }
            
            if !message.isUser {
                Spacer(minLength: 40)
            }
        }
    }
}

struct InputBar: View {
    @Binding var text: String
    var action: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                TextField("Ask anything about this course...", text: $text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .onSubmit { action() }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            
            Button(action: action) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color(red: 0.28, green: 0.45, blue: 0.36)) // Dark Green #47745B
                    .clipShape(Circle())
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(red: 0.97, green: 0.96, blue: 0.95))
    }
}

#Preview("AskView - Empty") {
    AskView()
}

#Preview("IntroCard") {
    IntroCard()
        .padding()
        .background(Color(red: 0.97, green: 0.96, blue: 0.95))
}

#Preview("MessageBubble - User") {
    MessageBubble(message: ChatMessage(text: "Can you explain the OSI model in simple terms?", isUser: true))
        .padding()
        .background(Color(red: 0.97, green: 0.96, blue: 0.95))
}

#Preview("MessageBubble - Assistant") {
    MessageBubble(message: ChatMessage(text: "Of course! The OSI (Open Systems Interconnection) model is a conceptual framework...", isUser: false))
        .padding()
        .background(Color(red: 0.97, green: 0.96, blue: 0.95))
}

#Preview("MessageBubble - Thinking") {
    MessageBubble(message: ChatMessage(text: "", isUser: false, isThinking: true))
        .padding()
        .background(Color(red: 0.97, green: 0.96, blue: 0.95))
}

#Preview("InputBar") {
    @Previewable @State var text = ""
    InputBar(text: $text, action: {})
}
