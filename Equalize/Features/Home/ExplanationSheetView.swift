import SwiftUI
import FoundationModels

struct ExplanationSheetView: View {
    let selectedText: String
    let context: String
    
    @State private var explanation: String = ""
    @State private var isGenerating = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You selected:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        Text("\"\(selectedText)\"")
                            .font(.body)
                            .italic()
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Explain like I'm 5:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        
                        if isGenerating && explanation.isEmpty {
                            ProgressView()
                                .padding()
                        } else {
                            Text(explanation)
                                .font(.body)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Concept Explanation")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await generateExplanation()
            }
        }
    }
    
    private func generateExplanation() async {
        let instructions = """
        You are a friendly, encouraging tutor. Your student is having trouble understanding a specific concept from their lecture notes.
        Explain the concept simply, using an analogy, like the student is 5 years old.
        Keep the explanation brief, fun, and highly relevant to the context.
        
        Context:
        \(context)
        """
        let prompt = "Explain this specific concept to me simply: '\(selectedText)'"
        
        // Use Apple Intelligence session (Simulated here)
        let session = LanguageModelSession(instructions: instructions)
        let stream = session.streamResponse { prompt }
        
        do {
            var isFirst = true
            for try await chunk in stream {
                if isFirst {
                    isGenerating = false
                    isFirst = false
                }
                explanation = chunk.content
            }
        } catch {
            explanation = "Sorry, I couldn't generate an explanation right now."
            isGenerating = false
        }
    }
}
