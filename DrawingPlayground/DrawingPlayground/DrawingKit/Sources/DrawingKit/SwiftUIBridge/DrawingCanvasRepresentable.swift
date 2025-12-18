//  SwiftUI から UIKit(View) を扱うための橋渡し。
//
//  SwiftUI は「状態（State）を変更すると View が再評価される」思想。
//  UIKit は「インスタンスへ命令して状態を変える」思想。
//  そのギャップを埋めるのが UIViewRepresentable で、
//  SwiftUI の state を updateUIView で UIKit 側へ反映するのが定番パターン。
//

import UIKit
import SwiftUI

public struct DrawingCanvasRepresentable: UIViewRepresentable {

    // MARK: - SwiftUI から渡される設定（= State駆動）
    public var mode: DrawMode

    // ペン設定
    public var penStyle: PenStyle

    // スタンプ設定
    public var stampKind: StampKind
    public var stampStyle: StampStyle

    // 消しゴム設定（SwiftUI 側で変更できるようにする）
    public var eraserRadius: CGFloat

    // UIKit の参照を SwiftUI 側へ返す（Undo/Redo/Clear/Export/Serialize を叩ける）
    @Binding public var canvasRef: DrawingCanvasView?

    // MARK: - Init
    // SwiftUI の View は値型なので init で受け取ったものを保持しやすい
    public init(
        mode: DrawMode,
        penStyle: PenStyle,
        stampKind: StampKind,
        stampStyle: StampStyle,
        eraserRadius: CGFloat,
        canvasRef: Binding<DrawingCanvasView?>
    ) {
        self.mode = mode
        self.penStyle = penStyle
        self.stampKind = stampKind
        self.stampStyle = stampStyle
        self.eraserRadius = eraserRadius
        self._canvasRef = canvasRef
    }

    // MARK: - UIViewRepresentable
    public func makeUIView(context: Context) -> DrawingCanvasView {
        let v = DrawingCanvasView()

        // makeUIView は「生成」のみで、SwiftUIの更新サイクル中に
        // Binding を直接更新すると警告が出ることがあるので main に投げるのが定番。
        DispatchQueue.main.async {
            self.canvasRef = v
        }

        return v
    }

    public func updateUIView(_ uiView: DrawingCanvasView, context: Context) {
        // SwiftUI の state を UIKit へ反映
        uiView.mode = mode

        uiView.penStyle = penStyle

        uiView.stampKind = stampKind
        uiView.stampStyle = stampStyle

        uiView.eraserRadius = eraserRadius

        DispatchQueue.main.async {
            self.canvasRef = uiView
        }
    }
}
