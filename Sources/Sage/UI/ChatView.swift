import SwiftUI
import iUXiOS

struct ChatView: View {
    @Environment(AppModel.self) private var model
    @State private var input = ""
    @State private var scrollProxy: ScrollViewProxy? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                    .onChange(of: model.messages.count) {
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: model.isGenerating) {
                        scrollToBottom(proxy: proxy)
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                }

                Divider()
                InputBar(input: $input, onSend: send)
            }
            .navigationTitle("Sage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !model.messages.isEmpty {
                        Button("Clear") { model.clearConversation() }
                            .disabled(model.isGenerating)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Ask me anything")
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
        if model.isGenerating {
            proxy.scrollTo("typing", anchor: .bottom)
        } else if let last = model.messages.last {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}
