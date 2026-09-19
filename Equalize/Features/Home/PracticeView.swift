import SwiftUI
import SwiftData

struct PracticeView: View {
    let lesson: Lesson
    
    @State private var flashcards: [Flashcard] = []
    @State private var isGenerating = false
    
    // Quiz State
    @State private var currentIndex = 0
    @State private var selectedOptionIndex: Int? = nil
    @State private var hasAnsweredCurrent = false
    @State private var correctAnswersCount = 0
    @State private var userAnswers: [Bool] = []
    @State private var showAnalysis = false
    
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncManager.self) private var syncManager
    
    var body: some View {
        VStack {
            if flashcards.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "rectangle.portrait.on.rectangle.portrait.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text("No Flashcards")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Generate active recall flashcards specifically curated for this lecture.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        
                    Button {
                        isGenerating = true
                        Task {
                            await syncManager.generateFlashcards(lesson: lesson)
                            loadFlashcards()
                            isGenerating = false
                        }
                    } label: {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 150, height: 44)
                        } else {
                            Text("Generate Flashcards")
                                .fontWeight(.semibold)
                                .frame(width: 180, height: 44)
                        }
                    }
                    .background(Color(red: 0.25, green: 0.4, blue: 0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(isGenerating)
                }
            } else if currentIndex >= flashcards.count {
                // Summary Screen
                VStack(spacing: 24) {
                    Text("Quiz Complete!")
                        .font(.title2)
                        .fontWeight(.bold)
                        
                    Button {
                        showAnalysis = true
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 15)
                            Circle()
                                .trim(from: 0, to: CGFloat(correctAnswersCount) / CGFloat(flashcards.count))
                                .stroke(Color.green, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut(duration: 1.0), value: correctAnswersCount)
                            
                            VStack {
                                Text("\(correctAnswersCount)/\(flashcards.count)")
                                    .font(.system(size: 40, weight: .bold, design: .rounded))
                                Text("Correct")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 150, height: 150)
                    .padding(.vertical, 10)
                    
                    Text("Tap the ring for a detailed analysis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    

                    
                    Button {
                        isGenerating = true
                        Task {
                            await syncManager.generateFlashcards(lesson: lesson)
                            loadFlashcards()
                            isGenerating = false
                        }
                    } label: {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        } else {
                            Text("Regenerate Flashcards")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .background(Color(red: 0.25, green: 0.4, blue: 0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    .disabled(isGenerating)
                }
            } else {
                // Quiz Question Screen
                VStack(spacing: 24) {
                    Text("Question \(currentIndex + 1) of \(flashcards.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(flashcards[currentIndex].question)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .frame(minHeight: 100)
                    
                    VStack(spacing: 12) {
                        ForEach(0..<flashcards[currentIndex].options.count, id: \.self) { i in
                            Button {
                                selectOption(i)
                            } label: {
                                HStack {
                                    Text(["A", "B", "C", "D"][i % 4])
                                        .fontWeight(.bold)
                                        .frame(width: 30)
                                    Text(flashcards[currentIndex].options[i])
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    if hasAnsweredCurrent {
                                        if i == flashcards[currentIndex].correctAnswer {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        } else if i == selectedOptionIndex {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.red)
                                        }
                                    }
                                }
                                .padding()
                                .background(buttonBackground(for: i))
                                .foregroundStyle(buttonForeground(for: i))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(buttonBorder(for: i), lineWidth: 2)
                                )
                            }
                            .disabled(hasAnsweredCurrent)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                .id(currentIndex)
            }
        }
        .onAppear {
            loadFlashcards()
        }
        .sheet(isPresented: $showAnalysis) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(0..<flashcards.count, id: \.self) { i in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: userAnswers[i] ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(userAnswers[i] ? .green : .red)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(flashcards[i].question)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    if !userAnswers[i] {
                                        Text("Answer: \(flashcards[i].options[flashcards[i].correctAnswer])")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
                .navigationTitle("Quiz Analysis")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            showAnalysis = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    private func loadFlashcards() {
        if let data = lesson.flashcardsData, let cards = try? JSONDecoder().decode([Flashcard].self, from: data) {
            self.flashcards = cards
            self.currentIndex = 0
            self.correctAnswersCount = 0
            self.userAnswers = []
            self.hasAnsweredCurrent = false
            self.selectedOptionIndex = nil
        } else {
            self.flashcards = []
        }
    }
    
    private func selectOption(_ index: Int) {
        guard !hasAnsweredCurrent else { return }
        selectedOptionIndex = index
        hasAnsweredCurrent = true
        
        let isCorrect = (index == flashcards[currentIndex].correctAnswer)
        if isCorrect {
            correctAnswersCount += 1
            userAnswers.append(true)
            triggerHaptic(success: true)
        } else {
            userAnswers.append(false)
            triggerHaptic(success: false)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (isCorrect ? 1.0 : 1.5)) {
            withAnimation(.easeInOut) {
                currentIndex += 1
                selectedOptionIndex = nil
                hasAnsweredCurrent = false
            }
        }
    }
    
    private func triggerHaptic(success: Bool) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(success ? .success : .error)
    }
    
    private func buttonBackground(for index: Int) -> Color {
        if !hasAnsweredCurrent { return Color(UIColor.secondarySystemBackground) }
        if index == flashcards[currentIndex].correctAnswer {
            return Color.green.opacity(0.15)
        } else if index == selectedOptionIndex {
            return Color.red.opacity(0.15)
        }
        return Color(UIColor.secondarySystemBackground).opacity(0.5)
    }
    
    private func buttonForeground(for index: Int) -> Color {
        if !hasAnsweredCurrent { return .primary }
        if index == flashcards[currentIndex].correctAnswer {
            return .green
        } else if index == selectedOptionIndex {
            return .red
        }
        return .primary.opacity(0.5)
    }
    
    private func buttonBorder(for index: Int) -> Color {
        if !hasAnsweredCurrent { return .clear }
        if index == flashcards[currentIndex].correctAnswer {
            return .green.opacity(0.5)
        } else if index == selectedOptionIndex {
            return .red.opacity(0.5)
        }
        return .clear
    }
}
