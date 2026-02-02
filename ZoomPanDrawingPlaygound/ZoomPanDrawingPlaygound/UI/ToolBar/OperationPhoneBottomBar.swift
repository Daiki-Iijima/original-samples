import SwiftUI

struct OperationPhoneBottomBar: View {
    @Binding var interactionMode: InteractionMode
    @Binding var presentedPanel: PanelRoute?

    var onUploadImage: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Divider().opacity(0.2)

            HStack(spacing: 10) {
                content
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var content: some View {
        switch interactionMode {
        case .normal:
            pill("未確認", "list.bullet") { presentedPanel = .unconfirmedParts }
            pill("リンク", "link") { presentedPanel = .linkProjects }
            pill("メモ", "note.text") { presentedPanel = .memo }
            Spacer()

        case .drawing:
            pill("ツール", "slider.horizontal.3") { presentedPanel = .drawingTools }
            pill("画像UP", "photo.on.rectangle") { onUploadImage() }
            Spacer()

        default:
            Spacer()
        }
    }

    private func pill(_ title: String, _ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
