import DrawingKit
import SwiftUI
import UIKit

// =========================================================
// ZoomableDrawingRepresentable
// - isDrawing=false(normal): ZoomPanUIView が 1本指パン + ピンチ
// - isDrawing=true(drawing): DrawingCanvasView が 1本指描画 + 2本指/ピンチを Zoom へ forward
// =========================================================
struct ZoomableDrawingRepresentable: UIViewRepresentable {
    let image: UIImage

    @Binding var isDrawing: Bool  // ★ここが唯一の真実（canvas.mode を見ない）
    @Binding var canvasRef: DrawingCanvasView?

    @Binding var viewportState: ViewportState
    @Binding var zoomRequest: ZoomRequest

    final class Coordinator {
        var lastIsDrawing: Bool?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        // --- Zoom (下) ---
        let zoom = ZoomPanUIView()
        zoom.setImage(image)

        // --- Canvas (上) ---
        let canvas = DrawingCanvasView()
        canvas.backgroundColor = .clear

        // Viewport 変化通知（高頻度）
        zoom.onViewportChanged = { [weak canvas] state in
            // Canvas側の描画を最新変換で更新（ペン/スタンプ/矩形オーバーレイ等）
            canvas?.viewToCanvasScale = state.scale
            canvas?.refreshForViewportChange()
            DispatchQueue.main.async { self.viewportState = state }
        }

        // 座標変換（ズーム追従の核）
        canvas.viewPointToCanvasPoint = { [weak zoom] pView in
            zoom?.viewPointToImagePoint(pView)
        }
        canvas.canvasPointToViewPoint = { [weak zoom] pImage in
            zoom?.imagePointToViewPoint(pImage)
        }

        // 2本指ジェスチャを Zoom に委譲（Canvasが受けてZoomを動かす）
        canvas.onTwoFingerPan = { [weak zoom] g in
            zoom?.handleExternalPan(g)
        }
        canvas.onPinch = { [weak zoom] g in
            zoom?.handleExternalPinch(g)
        }

        canvas.viewLengthToCanvasLength = { [weak zoom] viewLen in
            zoom?.viewLengthToImageLength(viewLen) ?? viewLen
        }
        canvas.canvasLengthToViewLength = { [weak zoom] imageLen in
            zoom?.imageLengthToViewLength(imageLen) ?? imageLen
        }

        // レイアウト
        zoom.frame = container.bounds
        zoom.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        canvas.frame = container.bounds
        canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        container.addSubview(zoom)
        container.addSubview(canvas)

        DispatchQueue.main.async { self.canvasRef = canvas }

        // 初期状態を反映
        applyMode(isDrawing: isDrawing, zoom: zoom, canvas: canvas)

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard
            let zoom = uiView.subviews.compactMap({ $0 as? ZoomPanUIView }).first,
            let canvas = uiView.subviews.compactMap({ $0 as? DrawingCanvasView }).first
        else { return }

        // ★切替判定は isDrawing を見る（canvas.mode は見ない）
        if context.coordinator.lastIsDrawing != isDrawing {
            context.coordinator.lastIsDrawing = isDrawing

            // まず確実にキャンセル（切替直後の “半端な競合” を潰す）
            zoom.cancelAllGestures()
            canvas.cancelAllGestures()

            applyMode(isDrawing: isDrawing, zoom: zoom, canvas: canvas)

            // さらに「次のRunLoopでもう一回」入れると iOS の癖に強い
            DispatchQueue.main.async {
                zoom.cancelAllGestures()
                canvas.cancelAllGestures()
                applyMode(isDrawing: isDrawing, zoom: zoom, canvas: canvas)
            }
        }

        // zoomRequest（通常通り）
        switch zoomRequest {
        case .none:
            break
        case .reset:
            zoom.resetViewport()
            DispatchQueue.main.async { zoomRequest = .none }
        case .set(let s, let c):
            zoom.setViewport(scale: s, centerInImage: c)
            DispatchQueue.main.async { zoomRequest = .none }
        }
    }

    private func applyMode(isDrawing: Bool, zoom: ZoomPanUIView, canvas: DrawingCanvasView) {
        if isDrawing {
            // drawing:
            // - 1本指: Canvas（ペン/消しゴム/スタンプ）
            // - 2本指/ピンチ: Canvasが受けてZoomへforward
            // - Zoom自身のgestureは止める（競合防止）
            canvas.isUserInteractionEnabled = true
            zoom.setOwnGesturesEnabled(false)
        } else {
            // normal:
            // - Canvasに触らせない（hitTestから消える）
            // - Zoom自身のgestureで1本指パン/ピンチ
            canvas.isUserInteractionEnabled = false
            zoom.setOwnGesturesEnabled(true)
        }
    }
}
