import DrawingKit
import SwiftUI
import UIKit

extension OperationScreen {
    
    var canvasLayer: some View {
        ZoomableDrawingRepresentable(
            image: UIImage(named: "sample2")!,
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
        guard interactionMode == .drawing else { return }
        
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
    }
    
    func syncOverlayRects() {
        guard let canvas else { return }
        
        // 未確認部材一覧モード以外は overlay を出さない
        guard isUnconfirmedPartsVisible else {
            canvas.setOverlayRects([])
            return
        }
        
        // 描画対象（非表示・確認済は除外）
        let renderable = overlayRects.filter { !$0.isHidden && !$0.isChecked }
        
        // 選択状態の見た目だけ強調
        let rectsForCanvas: [CanvasRect] = renderable.map { r in
            if selectedRectIDs.contains(r.id) {
                var s = r.style
                s.strokeWidth = max(s.strokeWidth, 5)
                s.strokeColor = .systemBlue
                return CanvasRect(
                    id: r.id,
                    externalID: r.externalID,
                    name: r.name,
                    isChecked: r.isChecked,
                    isHidden: r.isHidden,
                    rect: r.rect,
                    style: s
                )
            } else {
                return r
            }
        }
        
        canvas.setOverlayRects(rectsForCanvas)
    }
    
    /// ✅ 画像座標でヒットテスト → 選択トグル
    /// - 非表示(isHidden)はヒット対象から除外（タップ無効化）
    /// - チェック済み(isChecked)もヒット対象から除外（仕様：一覧にも出すがタップ対象外）
    func handleTapOnCanvas(at imagePoint: CGPoint) {
        // 未確認部材一覧モード以外は何もしない
        guard isUnconfirmedPartsVisible else { return }
        
        let tappable = overlayRects.filter { !$0.isHidden && !$0.isChecked }
        
        guard let hit = tappable.reversed().first(where: { $0.rect.contains(imagePoint) }) else {
            return
        }
        
        if selectedRectIDs.contains(hit.id) {
            selectedRectIDs.remove(hit.id)
        } else {
            selectedRectIDs.insert(hit.id)
        }
    }
}
