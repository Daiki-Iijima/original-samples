import SwiftUI

struct CommonFloatingPanel<Content: View>: View {
    let kind: PanelKind
    let containerSize: CGSize

    let width: CGFloat
    let margin: CGFloat
    let headerHeight: CGFloat

    let title: String
    let onClose: () -> Void

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
            position: $position
        ) {
            // 共通ヘッダー
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.headline)

                Spacer()

                trailing()

                Button("閉じる", action: onClose)
            }
            .padding(.horizontal, 12)
        } content: {
            content()
        }
        .onAppear {
            initPositionIfNeeded()
        }
    }

    private func initPositionIfNeeded() {
        guard !didInitPosition else { return }
        didInitPosition = true

        // 共通：右上寄せ / 右下寄せ など “kindごと” に決める
        switch kind {
        case .drawing:
            // 例：右下
            position = CGPoint(
                x: containerSize.width - width / 2 - 16,
                y: containerSize.height - 140
            )
        case .rectList:
            // 例：右上
            position = CGPoint(
                x: containerSize.width - width / 2 - 16,
                y: 140
            )
        }
    }
}
