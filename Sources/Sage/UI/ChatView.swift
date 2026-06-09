import SwiftUI
import iUXiOS

#Preview("Empty") {
    let model = AppModel()
    return ChatView()
        .environment(model)
        .environment(model.settings)
}

#Preview("Conversation") {
    let model = AppModel()
    model.messages = [
        Message(role: .user, content: "Hey, what's the capital of France?"),
        Message(role: .assistant, content: "The capital of France is Paris."),
        Message(role: .user, content: "What about Germany?"),
        Message(role: .assistant, content: "The capital of Germany is Berlin."),
    ]
    return ChatView()
        .environment(model)
        .environment(model.settings)
}

#Preview("Generating") {
    let model = AppModel()
    model.messages = [
        Message(role: .user, content: "Tell me something interesting about space."),
        Message(role: .assistant, content: "Did you know that a day on Venus is longer than a year on Venus?"),
    ]
    model.isGenerating = true
    return ChatView()
        .environment(model)
        .environment(model.settings)
}

struct ChatView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @State private var input = ""
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if model.messages.isEmpty {
                            emptyState
                        }
                        ForEach(model.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if model.isGenerating {
                            TypingIndicator()
                                .id("typing")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                // Scroll on new messages, state changes, and every streamed token
                .onChange(of: model.messages.count) { scrollToBottom(proxy: proxy) }
                .onChange(of: model.isGenerating) { scrollToBottom(proxy: proxy) }
                .onChange(of: model.messages.last?.content) { scrollToBottom(proxy: proxy) }
                // InputBar floats over scroll content — no opaque background needed
                .safeAreaInset(edge: .bottom) {
                    InputBar(input: $input, onSend: send)
                }
            }
            .navigationTitle("Apple Intelligence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if settings.canChooseMLX {
                        Button { showSettings = true } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !model.messages.isEmpty {
                        Button("Clear") { model.clearConversation() }
                            .disabled(model.isGenerating)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environment(settings)
                    .environment(model)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("On Device AI")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !model.isGenerating else { return }
        input = ""
        Task {
            await model.sendMessage(text)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.15)) {
            if model.isGenerating {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = model.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}
