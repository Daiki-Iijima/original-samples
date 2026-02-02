import SwiftUI

// MARK: - Height preference

private struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        // 一番大きい値を採用（レイアウト揺れ対策）
        value = max(value, nextValue())
    }
}

extension View {
    fileprivate func readHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: ViewHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(ViewHeightKey.self, perform: onChange)
    }
}

// MARK: - Panel

struct DraggableAutoPanel<Header: View, Content: View>: View {
    let containerSize: CGSize

    /// 横幅は固定にしやすい（まずは固定推奨）
    let width: CGFloat

    /// 余白（画面端にめり込まない）
    let margin: CGFloat

    /// ヘッダーの高さ（持ち手）
    let headerHeight: CGFloat

    /// 位置（center）
    @Binding var position: CGPoint

    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    // 中身の計測値
    @State private var contentHeight: CGFloat = 0
    
    @State private var didInitPosition = false

    // ドラッグ中の一時オフセット（これが “ピタ追従” のコツ）
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        let panelSize = computedPanelSize()
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        ZStack {
            // Materialは外側に1枚だけ
            shape.fill(.ultraThinMaterial)

            VStack(spacing: 0) {
                header()
                    .frame(height: headerHeight)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(panelSize: panelSize))
                    .overlay(divider, alignment: .bottom)

                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .readHeight { h in
                        let rounded = (h * 2).rounded() / 2
                        if abs(contentHeight - rounded) > 0.5 {
                            contentHeight = rounded
                        }
                    }
            }
        }
        .frame(width: panelSize.width, height: panelSize.height)
        .clipShape(shape)  // これで上下も完全に枠と一致
        .overlay(shape.stroke(.white.opacity(0.15), lineWidth: 1))
        .position(position)
        .offset(dragOffset)
        .onAppear {
            guard !didInitPosition else { return }
            didInitPosition = true
            position = clamp(position, panelSize: panelSize)
        }
        .onChange(of: panelSize.height) {
            // 初期化済みなら追従（リサイズで画面外に出ないため）
            guard didInitPosition else { return }
            position = clamp(position, panelSize: panelSize)
        }
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
    }

    private func computedPanelSize() -> CGSize {
        // ヘッダー + 中身 + padding(上下8*2)
        let rawHeight = headerHeight + contentHeight + 16

        // 画面に収まるよう最大値を制限（スクロール無しの限界）
        let maxH = max(80, containerSize.height - margin * 2)
        let h = min(rawHeight, maxH)

        return CGSize(width: width, height: h)
    }

    private func dragGesture(panelSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($dragOffset) { value, state, _ in
                // 指への追従はここで（描画コストが軽い）
                state = value.translation
            }
            .onEnded { value in
                // 確定は最後に一回だけ（遅れ・ふわつき激減）
                let newPos = CGPoint(
                    x: position.x + value.translation.width,
                    y: position.y + value.translation.height
                )
                position = clamp(newPos, panelSize: panelSize)
            }
    }

    private func clamp(_ p: CGPoint, panelSize: CGSize) -> CGPoint {
        var x = p.x
        var y = p.y

        let halfW = panelSize.width / 2
        let halfH = panelSize.height / 2

        x = max(margin + halfW, min(containerSize.width - margin - halfW, x))
        y = max(margin + halfH, min(containerSize.height - margin - halfH, y))

        return CGPoint(x: x, y: y)
    }
}
