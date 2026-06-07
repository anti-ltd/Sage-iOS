import SwiftUI
import FoundationModels

@Observable
@MainActor
final class AppModel {
    var messages: [Message] = []
    var isGenerating = false
    var errorMessage: String? = nil

    private var session: LanguageModelSession?

    func sendMessage(_ text: String) async {
        messages.append(Message(role: .user, content: text))
        isGenerating = true
        errorMessage = nil

        // Reuse session across turns so the model has full conversation context.
        if session == nil {
            session = LanguageModelSession()
        }

        var assistantMessage = Message(role: .assistant, content: "")
        messages.append(assistantMessage)
        let idx = messages.count - 1

        do {
            let stream = session!.streamResponse(to: text)
            for try await partial in stream {
                messages[idx].content = partial.text
            }
        } catch {
            messages[idx].content = "Sorry, something went wrong."
            errorMessage = error.localizedDescription
            // Reset session on error so the next turn starts fresh.
            session = nil
        }

        isGenerating = false
    }

    func clearConversation() {
        messages = []
        session = nil
        errorMessage = nil
    }
}
