import SwiftUI

struct MemoPanelView: View {
    @Binding var text: String
    var onSave: () -> Void
    var onDiscard: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .padding(12)
                .frame(minHeight: 220)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(12)
                .focused($focused)

            Divider().opacity(0.25)

            HStack(spacing: 12) {
                Button(role: .destructive) {
                    onDiscard()
                } label: {
                    Text("破棄")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered)

                Button {
                    onSave()
                } label: {
                    Text("保存")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
        }
        .onAppear { DispatchQueue.main.async { focused = true } }
    }
}
