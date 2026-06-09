import SwiftUI
import FoundationModels

@Observable
@MainActor
final class AppModel {
    var messages: [Message] = []
    var isGenerating = false

    /// Non-nil whenever MLX is the active (or pending) backend.
    var mlxBackend: MLXBackend?
    private var backend: AIBackend?

    let settings: AppSettings

    init() {
        let settings = AppSettings()
        self.settings = settings

        if #available(iOS 26.0, *),
           SystemLanguageModel.default.isAvailable,
           !settings.preferMLX
        {
            backend = FoundationModelsBackend()
        } else {
            let mlx = MLXBackend(model: settings.selectedMLXModel)
            mlxBackend = mlx
            backend = mlx
        }
    }

    var needsMLXSetup: Bool {
        guard let mlx = mlxBackend else { return false }
        if case .ready = mlx.loadState { return false }
        return true  // idle / downloading / loading / failed all stay on setup screen
    }

    // MARK: - Backend switching

    /// Switch between Foundation Models and MLX at runtime.
    /// Clears the conversation so history from the old backend isn't replayed.
    func switchBackend(preferMLX: Bool) {
        guard !isGenerating else { return }
        settings.preferMLX = preferMLX
        messages = []

        if preferMLX {
            let mlx = MLXBackend(model: settings.selectedMLXModel)
            mlxBackend = mlx
            backend = mlx
        } else {
            mlxBackend = nil
            if #available(iOS 26.0, *) {
                backend = FoundationModelsBackend()
            }
        }
    }

    /// Switch to a different MLX model. Creates a fresh backend (idle state) and clears history.
    func switchMLXModel(to option: MLXModelOption) {
        guard !isGenerating else { return }
        settings.selectedMLXModelID = option.id
        messages = []
        let mlx = MLXBackend(model: option)
        mlxBackend = mlx
        backend = mlx
    }

    // MARK: - Messaging

    func sendMessage(_ text: String) async {
        guard let backend else { return }
        messages.append(Message(role: .user, content: text))
        isGenerating = true

        let assistantMessage = Message(role: .assistant, content: "")
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
