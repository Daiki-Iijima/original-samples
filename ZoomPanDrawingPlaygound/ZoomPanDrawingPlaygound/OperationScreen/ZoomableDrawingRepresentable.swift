import DrawingKit
import SwiftUI
import UIKit

struct ZoomableDrawingRepresentable: UIViewRepresentable {
    let image: UIImage

    @Binding var isDrawing: Bool
    @Binding var canvasRef: DrawingCanvasView?

    @Binding var viewportState: ViewportState
    @Binding var zoomRequest: ZoomRequest

    /// 画像座標でタップを通知
    var onTapImagePoint: ((CGPoint) -> Void)?

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var lastIsDrawing: Bool?
        var onTapImagePoint: ((CGPoint) -> Void)?
        weak var zoom: ZoomPanUIView?

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc func handleTap(_ g: UITapGestureRecognizer) {
            guard g.state == .ended else { return }
            guard let zoom else { return }
            let pView = g.location(in: zoom)
            let pImage = zoom.viewPointToImagePoint(pView)!
            onTapImagePoint?(pImage)
        }
    }

    func makeCoordinator() -> Coordinator {
        let c = Coordinator()
        c.onTapImagePoint = onTapImagePoint
        return c
    }

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

        // 2本指ジェスチャを Zoom に委譲
        canvas.onTwoFingerPan = { [weak zoom] g in zoom?.handleExternalPan(g) }
        canvas.onPinch = { [weak zoom] g in zoom?.handleExternalPinch(g) }

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

        // ★タップジェスチャ（zoomに付ける）
        let tap = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        zoom.addGestureRecognizer(tap)

        context.coordinator.zoom = zoom

        // 初期状態
        applyMode(isDrawing: isDrawing, zoom: zoom, canvas: canvas)

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard
            let zoom = uiView.subviews.compactMap({ $0 as? ZoomPanUIView }).first,
            let canvas = uiView.subviews.compactMap({ $0 as? DrawingCanvasView }).first
        else { return }

        context.coordinator.onTapImagePoint = onTapImagePoint
        context.coordinator.zoom = zoom

        if context.coordinator.lastIsDrawing != isDrawing {
            context.coordinator.lastIsDrawing = isDrawing

            zoom.cancelAllGestures()
            canvas.cancelAllGestures()

            applyMode(isDrawing: isDrawing, zoom: zoom, canvas: canvas)

            DispatchQueue.main.async {
                zoom.cancelAllGestures()
                canvas.cancelAllGestures()
                applyMode(isDrawing: isDrawing, zoom: zoom, canvas: canvas)
            }
        }

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
            canvas.isUserInteractionEnabled = true
            zoom.setOwnGesturesEnabled(false)
        } else {
            canvas.isUserInteractionEnabled = false
            zoom.setOwnGesturesEnabled(true)
        }
    }
}
