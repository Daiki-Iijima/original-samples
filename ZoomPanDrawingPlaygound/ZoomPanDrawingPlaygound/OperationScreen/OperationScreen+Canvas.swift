import DrawingKit
import SwiftUI
import UIKit

extension OperationScreen {

    // MARK: - Canvas Layer

    /// 描画/ズーム/タップを受けるキャンバス層
    ///
    /// なぜView側？
    /// - ZoomableDrawingRepresentable は UIKit ブリッジ（canvasRef）を扱う
    /// - canvasRef は View のライフサイクルで保持するのが自然（Storeに置くと参照管理が難しい）
    var canvasLayer: some View {
        ZoomableDrawingRepresentable(
            image: store.currentLoadedImage.image,
            isDrawing: Binding(
                get: { store.interactionMode == .drawing },
                set: { store.interactionMode = $0 ? .drawing : .normal }
            ),
            canvasRef: $canvas,
            viewportState: Binding(
                get: { store.viewportState },
                set: { store.viewportState = $0 }
            ),
            zoomRequest: Binding(
                get: { store.zoomRequest },
                set: { store.zoomRequest = $0 }
            ),
            onTapImagePoint: { p in
                // ✅ タップ→状態遷移ルールは Store に集約（Viewは「通知」だけ）
                store.handleTapOnCanvas(at: p)
                // ✅ 見た目更新（canvas参照を触るのはViewの責務）
                syncOverlayRects()
            }
        )
        // ✅ 画像が切り替わったらRepresentableを作り直してズレを防ぐ
        .id(store.currentLoadedImage.name)
    }

    // MARK: - Canvas tool sync

    /// UIモード（normal/drawing/camera）を canvas に反映
    ///
    /// なぜView側？
    /// - canvas は UIKit参照でViewが保持しているため、操作もView側で行う
    func applyInteractionModeToCanvas() {
        guard let canvas else { return }

        switch store.interactionMode {
        case .drawing:
            canvas.mode = store.drawingSettings.tool
        case .normal, .camera:
            canvas.mode = .none
        }
    }

    /// 描画設定（ペン/消しゴム/スタンプ）を canvas に反映
    ///
    /// これもView側でOK：理由は applyInteractionModeToCanvas と同じ
    func syncCanvasToolState() {
        guard let canvas else { return }
        guard store.interactionMode == .drawing else { return }

        let settings = store.drawingSettings

        canvas.mode = settings.tool

        canvas.penStyle = PenStyle(
            color: UIColor(settings.pen.color),
            lineWidth: settings.pen.width,
            opacity: settings.pen.opacity
        )

        canvas.eraserRadius = settings.eraser.radius

        canvas.stampKind = settings.stamp.kind
        canvas.stampStyle = StampStyle(
            color: UIColor(settings.stamp.color),
            size: settings.stamp.size,
            opacity: settings.stamp.opacity
        )
    }
}
