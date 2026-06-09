import SwiftUI

#Preview("Empty") {
    ZStack(alignment: .bottom) {
        Color(.systemGroupedBackground).ignoresSafeArea()
        InputBar(input: .constant(""), onSend: {})
    }
}

#Preview("With text") {
    ZStack(alignment: .bottom) {
        Color(.systemGroupedBackground).ignoresSafeArea()
        InputBar(input: .constant("What's the weather like today?"), onSend: {})
    }
}

struct InputBar: View {
    @Binding var input: String
    let onSend: () -> Void

    private var isEmpty: Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            glassBar
        } else {
            classicBar
        }
    }

    // MARK: - iOS 26 liquid glass

    @available(iOS 26.0, *)
    private var glassBar: some View {
        GlassEffectContainer {
            HStack(spacing: 8) {
                TextField("Message", text: $input, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .onSubmit(onSend)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36)
                }
                .foregroundStyle(isEmpty ? Color.secondary : .white)
                .glassEffect(isEmpty ? .regular : .regular.tint(.accentColor), in: Circle())
                .disabled(isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Classic fallback (< iOS 26)

    private var classicBar: some View {
        HStack(spacing: 8) {
            TextField("Message", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .onSubmit(onSend)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(isEmpty ? Color.secondary : Color.accentColor)
            }
            .disabled(isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
