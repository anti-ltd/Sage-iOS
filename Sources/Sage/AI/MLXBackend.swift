import Foundation
import Hub
import MLXLLM
import MLXLMCommon

@Observable
final class MLXBackend: AIBackend, @unchecked Sendable {
    enum LoadState {
        case idle, downloading(Double), loading, ready, failed(String)
    }

    var loadState: LoadState = .idle
    private var modelContainer: ModelContainer?

    private let modelOption: MLXModelOption
    private var config: ModelConfiguration { modelOption.configuration }

    // Application Support persists across reinstalls; Caches (the default) does not.
    private static let hubApi: HubApi = {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return HubApi(downloadBase: dir)
    }()

    init(model: MLXModelOption = MLXModelCatalog.defaultModel) {
        self.modelOption = model
    }

    // MARK: - Setup

    @MainActor
    func prepare() async {
        guard modelContainer == nil else { return }

        // If a previous attempt left corrupt or incompatible files, wipe them
        // so we get a clean download rather than hitting the same error again.
        if case .failed = loadState {
            clearModelCache()
        }

        loadState = .downloading(0)
        do {
            let container = try await LLMModelFactory.shared.loadContainer(
                hub: Self.hubApi,
                configuration: config
            ) { [weak self] progress in
                Task { @MainActor in
                    self?.loadState = .downloading(progress.fractionCompleted)
                }
            }
            modelContainer = container
            loadState = .ready
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    /// Removes this model's cached files so the next `prepare()` triggers a fresh download.
    private func clearModelCache() {
        // HubApi stores models at {downloadBase}/models/{org}/{repo}
        // config.name returns the full repo ID, e.g. "mlx-community/Qwen3-1.7B-4bit"
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelDir = appSupport
            .appendingPathComponent("models")
            .appendingPathComponent(config.name)
        try? FileManager.default.removeItem(at: modelDir)
    }

    // MARK: - Inference

    func streamResponse(prompt: String, history: [Message]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let container = self.modelContainer else {
                    continuation.finish(throwing: MLXError.modelNotLoaded)
                    return
                }

                // Build UserInput before the @Sendable perform closure (Chat.Message isn't Sendable).
                let chatHistory: [Chat.Message] = history.dropLast().compactMap { msg in
                    switch msg.role {
                    case .user: return .user(msg.content)
                    case .assistant: return msg.content.isEmpty ? nil : .assistant(msg.content)
                    }
                } + [.user(prompt)]
                let userInput = UserInput(chat: chatHistory)

                do {
                    try await container.perform { context in
                        let input = try await context.processor.prepare(input: userInput)
                        var accumulated = ""
                        let _ = try MLXLMCommon.generate(
                            input: input,
                            parameters: GenerateParameters(),
                            context: context
                        ) { tokenId in
                            let piece = context.tokenizer.decode(tokens: [tokenId])
                            accumulated += piece
                            continuation.yield(accumulated)
                            return .more
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func resetContext() {
        // Each generate call is independent; nothing to reset.
    }

    enum MLXError: LocalizedError {
        case modelNotLoaded
        var errorDescription: String? { "Model not loaded." }
    }
}
