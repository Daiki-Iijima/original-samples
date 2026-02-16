import SwiftUI

struct CommonFloatingPanel<Content: View>: View {
    let kind: PanelKind
    let containerSize: CGSize

    let width: CGFloat
    let margin: CGFloat
    let headerHeight: CGFloat

    let title: String
    let onClose: () -> Void
    
    let isShowCloseButton: Bool

    /// 右上などに置く追加ボタン（任意）
    @ViewBuilder var trailing: () -> AnyView

    @Binding var position: CGPoint
    @Binding var didInitPosition: Bool

    @ViewBuilder var content: () -> Content

    var body: some View {
        DraggableAutoPanel(
            containerSize: containerSize,
            width: width,
            margin: margin,
            headerHeight: headerHeight,
            position: $position,
        ) {
            // 共通ヘッダー
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.headline)

                Spacer()

                trailing()

                if isShowCloseButton{
                    Button("閉じる", action: onClose)
                }
            }
            .padding(.horizontal, 12)
        } content: {
            content()
        }
        .onAppear {
            initPositionIfNeeded()
        }
    }

    //  パネル初期位置設定
    private func initPositionIfNeeded() {
        guard !didInitPosition else { return }
        didInitPosition = true

        // 共通：右上寄せ / 右下寄せ など “kindごと” に決める
        switch kind {
        case .drawing:
            position = CGPoint(
                x: containerSize.width - width / 2 - 16,
                y: containerSize.height - 140
            )
        case .unconfirmedParts:
            // 左下寄せ
            position = CGPoint(
                x: width / 2 + 16,
                y: 500
            )
        case .memo:
            // 画面中心上部
            position = CGPoint(
                x: containerSize.width / 2,
                y: 140
            )
        case .linkProjects:
            // 左下寄せ
            position = CGPoint(
                x: containerSize.width - width / 2 - 16,
                y: 500
            )
        }
    }
}
