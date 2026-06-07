import Foundation
import MLXLLM
import MLXLMCommon

@Observable
final class MLXBackend: AIBackend {
    enum LoadState {
        case idle, downloading(Double), loading, ready, failed(String)
    }

    var loadState: LoadState = .idle

    private var modelContainer: ModelContainer?

    // Small 4-bit quantised model — ~700 MB download, runs well on A14+.
    private let config = ModelRegistry.llama3_2_1B_4bit

    func prepare() async {
        guard modelContainer == nil else { return }
        do {
            loadState = .downloading(0)
            let container = try await LLMModelFactory.shared.loadContainer(
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

    func streamResponse(prompt: String, history: [Message]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let container = self.modelContainer else {
                    continuation.finish(throwing: MLXError.modelNotLoaded)
                    return
                }

                // Build chat history for the model.
                var chatMessages: [[String: String]] = history.dropLast().map { msg in
                    ["role": msg.role == .user ? "user" : "assistant", "content": msg.content]
                }
                chatMessages.append(["role": "user", "content": prompt])

                do {
                    let result = try await container.perform { context in
                        let input = try await context.processor.prepare(
                            input: .init(messages: chatMessages)
                        )
                        return try MLXLMCommon.generate(
                            input: input,
                            parameters: GenerateParameters(),
                            context: context
                        ) { tokens in
                            return .more
                        }
                    }
                    continuation.yield(result.output)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func resetContext() {
        // MLX is stateless per-generate; nothing to reset.
    }

    enum MLXError: LocalizedError {
        case modelNotLoaded
        var errorDescription: String? { "Model not loaded yet." }
    }
}
