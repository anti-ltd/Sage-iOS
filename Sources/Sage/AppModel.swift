import SwiftUI
import FoundationModels

@Observable
@MainActor
final class AppModel {
    var messages: [Message] = []
    var isGenerating = false

    // Non-nil only on older devices
    var mlxBackend: MLXBackend?
    private var backend: AIBackend?

    init() {
        if #available(iOS 26.0, *), SystemLanguageModel.default.isAvailable {
            backend = FoundationModelsBackend()
        } else {
            let mlx = MLXBackend()
            mlxBackend = mlx
            backend = mlx
        }
    }

    var needsMLXSetup: Bool {
        guard let mlx = mlxBackend else { return false }
        if case .ready = mlx.loadState { return false }
        if case .failed = mlx.loadState { return false }
        return true
    }

    func sendMessage(_ text: String) async {
        guard let backend else { return }
        messages.append(Message(role: .user, content: text))
        isGenerating = true

        var assistantMessage = Message(role: .assistant, content: "")
        messages.append(assistantMessage)
        let idx = messages.count - 1

        do {
            let stream = backend.streamResponse(prompt: text, history: messages)
            for try await chunk in stream {
                messages[idx].content = chunk
            }
        } catch {
            messages[idx].content = error.localizedDescription
            backend.resetContext()
        }

        isGenerating = false
    }

    func clearConversation() {
        messages = []
        backend?.resetContext()
    }
}
