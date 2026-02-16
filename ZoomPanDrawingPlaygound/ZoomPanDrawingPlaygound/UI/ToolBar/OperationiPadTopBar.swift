import SwiftUI

// ============================
// OperationiPadTopBar（2段トップバー）
// - 1段目: 共通（戻る/モード/Rect一覧/ResetZoom/scale）
// - 2段目: モード別ショートカット + Key/IO
// ============================

struct OperationiPadTopBar: View {
    @Binding var interactionMode: InteractionMode
    let viewportScale: CGFloat

    @Binding var isUnconfirmedPartsVisible: Bool

    // 2段目で使いそうなやつ（必要に応じて増やす）
    @Binding var isMemoVisible: Bool
    @Binding var isLinkProjectsVisible: Bool
    @Binding var isDrawingSettingsPanelVisible: Bool

    var onBack: () -> Void
    var onResetZoom: () -> Void
    var onUploadImage: () -> Void
    var onSaveLocal: () -> Void
    var onLoadLocal: () -> Void
    var onSavePhotos: () -> Void
    var onOpenPipeScanner: () -> Void
    var onOpenConfig: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // --------------------
            // 1段目（共通）
            // --------------------
            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 44, height: 34)
                        .contentShape(Rectangle())
                }

                modeButton("確認モード", .normal)
                modeButton("描画モード", .drawing)
                
                Button {
                    onOpenPipeScanner()
                } label: {
                    Text("文字認識")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Spacer()

                Button("ズームリセット") { onResetZoom() }

                Text(String(format: "ズーム倍率: %.2f", viewportScale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                
                Button {
                } label: {
                    Label("強制終了", systemImage: "")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button {
                    onOpenConfig()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.headline)
                        .frame(width: 44, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

            }

            // --------------------
            // 2段目（モード別）
            // ※ 別Viewに切り出して型推論を軽くする
            // --------------------
            OperationiPadTopBarSecondRow(
                interactionMode: $interactionMode,
                isUnconfirmedPartsVisible: $isUnconfirmedPartsVisible,
                isMemoVisible: $isMemoVisible,
                isLinkProjectsVisible: $isLinkProjectsVisible,
                isSettingsPanelVisible: $isDrawingSettingsPanelVisible,
                onUploadImage: onUploadImage,
                onSaveLocal: onSaveLocal,
                onLoadLocal: onLoadLocal,
                onSavePhotos: onSavePhotos
            )
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // mode button（共通）
    private func modeButton(_ title: String, _ mode: InteractionMode) -> some View {
        Button { interactionMode = mode } label: {
            Text(title)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(interactionMode == mode ? Color.blue.opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

// ============================
// 2段目（モード別）
// ============================

struct OperationiPadTopBarSecondRow: View {
    @Binding var interactionMode: InteractionMode

    @Binding var isUnconfirmedPartsVisible: Bool
    @Binding var isMemoVisible: Bool
    @Binding var isLinkProjectsVisible: Bool
    @Binding var isSettingsPanelVisible: Bool

    var onUploadImage: () -> Void
    var onSaveLocal: () -> Void
    var onLoadLocal: () -> Void
    var onSavePhotos: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch interactionMode {
        case .normal:
            TogglePillButton(title: "未確認部材一覧", isOn: $isUnconfirmedPartsVisible, systemImage: "list.bullet")
            TogglePillButton(title: "リンクプロジェクト一覧", isOn: $isLinkProjectsVisible, systemImage: "link")
            TogglePillButton(title: "メモ", isOn: $isMemoVisible, systemImage: "note.text")
            
            Spacer()

        case .drawing:
            TogglePillButton(title: "ツール選択", isOn: $isSettingsPanelVisible, systemImage: "slider.horizontal.3")
            Button {
                onUploadImage()
            } label: {
                Label("画像アップロード", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondary.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            Spacer()
        default:
            Spacer()
        }
    }
}

// ============================
// Preview
// ============================

#Preview {
    struct _PreviewHost: View {
        @State var interactionMode: InteractionMode = .normal
        @State var isRectListVisible = false
        @State var isUnconfirmedPartsVisible = false
        @State var isMemoVisible = false
        @State var isLinkProjectsVisible = false
        @State var isDrawingSettingsPanelVisible = false
        @State var imageKey = "sample1"
        @State var drawingKey = "v1"

        var body: some View {
            OperationiPadTopBar(
                interactionMode: $interactionMode,
                viewportScale: 1.23,
                isUnconfirmedPartsVisible: $isUnconfirmedPartsVisible,
                isMemoVisible: $isMemoVisible,
                isLinkProjectsVisible: $isLinkProjectsVisible,
                isDrawingSettingsPanelVisible: $isDrawingSettingsPanelVisible,
                onBack: {},
                onResetZoom: {},
                onUploadImage: {},
                onSaveLocal: {},
                onLoadLocal: {},
                onSavePhotos: {},
                onOpenPipeScanner: {},
                onOpenConfig: {},
            )
            .padding()
        }
    }

    return _PreviewHost()
}
