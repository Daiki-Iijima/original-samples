import DrawingKit
import SwiftUI
import UIKit

extension OperationScreen {
    
    var canvasLayer: some View {
        ZoomableDrawingRepresentable(
            image: UIImage(named: imageKey)!,
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
        ).id(imageKey)
    }
    
    func applyInteractionModeToCanvas() {
        guard let canvas else { return }
        switch interactionMode {
        case .drawing:
            canvas.mode = drawingSettings.tool
        case .normal,.camera:
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

        // 未確認部材一覧モード以外では overlay 自体を描かない（既存要件）
        guard isUnconfirmedPartsVisible else {
            canvas.setOverlayRects([])
            return
        }

        // 未確認のRect（タップ対象にもする）
        let unconfirmed = overlayRects.filter { !$0.isHidden && !$0.isChecked }

        // 現在プロジェクト未設定なら、あるものから自動で開く
        if currentProjectID == nil {
            currentProjectID = unconfirmed.first?.projectID
        }

        guard let pid = currentProjectID else {
            canvas.setOverlayRects([])
            return
        }

        // 現在プロジェクトのRectだけ描画対象
        let inCurrentProject = unconfirmed.filter { $0.projectID == pid }

        // 選択状態は「見た目だけ強調」して描画（未選択も描く／選択だけ描く等はここで調整）
        let rectsForCanvas: [CanvasRect] = inCurrentProject.map { r in
            if selectedRectIDs.contains(r.id) {
                var s = r.style
                s.strokeWidth = max(s.strokeWidth, 5)
                s.strokeColor = .systemBlue
                return CanvasRect(
                    id: r.id,
                    externalID: r.externalID,
                    name: r.name,
                    projectID: r.projectID,
                    projectName: r.projectName,
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
        // 未確認部材一覧モード以外は、Rectタップ無効（既存要件）
        guard isUnconfirmedPartsVisible else { return }

        // タップ対象：未確認（非表示/確認済みは除外）
        let tappable = overlayRects.filter { !$0.isHidden && !$0.isChecked }

        guard let hit = tappable.reversed().first(where: { $0.rect.contains(imagePoint) }) else {
            return
        }

        // 別プロジェクトのRectをタップしたら「そのプロジェクトを開く」
        if currentProjectID != hit.projectID {
            currentProjectID = hit.projectID
            print(currentProjectID)
        }

        // 選択トグル
        if selectedRectIDs.contains(hit.id) {
            selectedRectIDs.remove(hit.id)
        } else {
            selectedRectIDs.insert(hit.id)
        }

        // 見た目更新
        syncOverlayRects()
    }
}
