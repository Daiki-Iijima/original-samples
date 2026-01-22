import DrawingKit
import SwiftUI
import UIKit

extension OperationScreen {

    // 下層：画像 + ズームパン + 描画キャンバス
    var canvasLayer: some View {
        ZoomableDrawingRepresentable(
            image: UIImage(named: "sample1")!,
            isDrawing: Binding(
                get: { interactionMode == .drawing },
                set: { interactionMode = $0 ? .drawing : .normal }
            ),
            canvasRef: $canvas,
            viewportState: $viewportState,
            zoomRequest: $zoomRequest,
            onTapImagePoint: { p in
                handleTapOnCanvas(at: p)
            }
        )
    }

    func applyInteractionModeToCanvas() {
        guard let canvas else { return }

        switch interactionMode {
        case .drawing:
            canvas.mode = drawingSettings.tool
        case .normal, .zoomPreset, .rectPreset:
            canvas.mode = .none
        }
    }

    func syncCanvasToolState() {
        guard let canvas else { return }
        guard interactionMode == .drawing else {
            // drawing 以外でも overlay は反映しておく
            canvas.setOverlayRects(overlayRects)
            return
        }

        canvas.mode = drawingSettings.tool

        canvas.penStyle = PenStyle(
            color: UIColor(drawingSettings.pen.color),
            lineWidth: drawingSettings.pen.width,
            opacity: drawingSettings.pen.opacity
        )

        canvas.eraserRadius = drawingSettings.eraser.radius

        canvas.stampKind = drawingSettings.stamp.kind
        canvas.stampStyle = StampStyle(
            color: UIColor(drawingSettings.stamp.color),
            size: drawingSettings.stamp.size,
            opacity: drawingSettings.stamp.opacity
        )

        canvas.setOverlayRects(overlayRects)
    }

    /// 選択状態 / 非表示 / チェック状態を加味して canvas に渡す
    func syncOverlayRects() {
        // ✅ 非表示は描画しない（= タップ対象にもならないよう、hitTest側も同じ条件で弾く）
        let visibleRects = overlayRects.filter { !$0.isHidden && !$0.isChecked }

        // ✅ 選択中は強調（style差し替え）
        let rectsForCanvas: [CanvasRect] = visibleRects.map { r in
            guard selectedRectIDs.contains(r.id) else { return r }

            var rr = r
            rr.style.strokeColor = .systemCyan
            rr.style.strokeWidth = max(rr.style.strokeWidth, 5)

            // ついでに薄く塗りを足す（お好み）
            if case .none = rr.style.fill {
                rr.style.fill = .solid(UIColor.systemCyan.withAlphaComponent(0.10))
            }
            return rr
        }

        canvas?.setOverlayRects(rectsForCanvas)
    }

    /// 画像座標のタップ位置から、Rectを選択/解除
    func handleTapOnCanvas(at imagePoint: CGPoint) {
        // ✅ 非表示・チェック済みは「タップ対象にしない」
        let hitCandidates =
            overlayRects
            .filter { !$0.isHidden && !$0.isChecked }
            .reversed()

        guard let hit = hitCandidates.first(where: { $0.rect.contains(imagePoint) }) else {
            return
        }

        if selectedRectIDs.contains(hit.id) {
            selectedRectIDs.remove(hit.id)
        } else {
            selectedRectIDs.insert(hit.id)
        }
    }
}
