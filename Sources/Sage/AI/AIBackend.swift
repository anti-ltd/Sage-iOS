import Foundation

protocol AIBackend: AnyObject {
    /// Stream accumulated text (full response so far, not deltas) for a prompt + history.
    func streamResponse(prompt: String, history: [Message]) -> AsyncThrowingStream<String, Error>
    func resetContext()
}
