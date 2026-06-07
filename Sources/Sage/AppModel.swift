import SwiftUI
import FoundationModels

@Observable
@MainActor
final class AppModel {
    var messages: [Message] = []
    var isGenerating = false

    private var session: LanguageModelSession?

    var availabilityStatus: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Enable Apple Intelligence in Settings → Apple Intelligence & Siri."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence model is downloading. Try again soon."
        case .unavailable:
            return "Apple Intelligence unavailable."
        }
    }

    func sendMessage(_ text: String) async {
        messages.append(Message(role: .user, content: text))
        isGenerating = true

        if let status = availabilityStatus {
            messages.append(Message(role: .assistant, content: status))
            isGenerating = false
            return
        }

        if session == nil {
            session = LanguageModelSession()
        }

        var assistantMessage = Message(role: .assistant, content: "")
        messages.append(assistantMessage)
        let idx = messages.count - 1

        do {
            let stream = session!.streamResponse(to: text)
            for try await partial in stream {
                messages[idx].content = partial.content
            }
        } catch let error as LanguageModelSession.GenerationError {
            messages[idx].content = error.localizedDescription
            session = nil
        } catch {
            messages[idx].content = error.localizedDescription
            session = nil
        }

        isGenerating = false
    }

    func clearConversation() {
        messages = []
        session = nil
    }
}
