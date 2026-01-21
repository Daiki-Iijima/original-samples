import DrawingKit
import SwiftUI
import UIKit

struct ZoomableDrawingRepresentable: UIViewRepresentable {
    let image: UIImage
    @Binding var canvasRef: DrawingCanvasView?

    @Binding var viewportState: ViewportState
    @Binding var zoomRequest: ZoomRequest

    /// final な DrawingCanvasView を継承できないので、
    /// “ヒットテストだけ” を制御する透明Viewを一枚かませる。
    final class TouchGateView: UIView {
        enum Policy {
            /// 1本指は Canvas、2本指以上は ZoomPan へ落とす
            case oneFingerToCanvas_twoFingersToZoom

            /// noneモード用：1本/2本ともパンはZoomPanへ、ズームもZoomPanへ
            /// （= Canvasに当てない）
            case allToZoom
        }

        var policy: Policy = .oneFingerToCanvas_twoFingersToZoom

        /// “このViewがタッチを受けるか” をここで決める
        /// - true を返すと、このViewがヒット→下の canvas に届く（※hitTestでcanvasを返す）
        /// - false を返すと、このViewは無視され→下の zoom に届く
        override func point(inside p: CGPoint, with event: UIEvent?) -> Bool {
            let touches = event?.allTouches ?? []
            let touchCount = touches.count

            switch policy {
            case .oneFingerToCanvas_twoFingersToZoom:
                let inside = (touchCount <= 1) && super.point(inside: p, with: event)
                return inside

            case .allToZoom:
                return false
            }
        }

        /// point(inside)=true の場合、このViewがヒットするので
        /// “下の Canvas を返す” ようにして実際の入力先を Canvas にする
        weak var canvas: UIView?

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard self.point(inside: point, with: event) else { return nil }
            return canvas
        }
    }

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UIView {
        let container = UIView()

        // --- Zoom (下) ---
        let zoom = ZoomPanUIView()
        zoom.setImage(image)

        // --- Canvas (中) ---
        let canvas = DrawingCanvasView()
        canvas.backgroundColor = .clear

        zoom.onViewportChanged = { [weak canvas] state in
            canvas?.refreshForViewportChange()

            DispatchQueue.main.async {
                self.viewportState = state
            }
        }

        // 座標変換（ズーム追従の核）
        canvas.viewPointToCanvasPoint = { [weak zoom] pView in
            zoom?.viewPointToImagePoint(pView)
        }
        canvas.canvasPointToViewPoint = { [weak zoom] pImage in
            zoom?.imagePointToViewPoint(pImage)
        }

        // 2本指ジェスチャを Zoom に委譲
        canvas.onTwoFingerPan = { [weak zoom] g in
            zoom?.handleExternalPan(g)
        }
        canvas.onPinch = { [weak zoom] g in
            zoom?.handleExternalPinch(g)
        }

        // --- Gate (上) ---
        let gate = TouchGateView()
        gate.backgroundColor = .clear
        gate.isUserInteractionEnabled = true
        gate.canvas = canvas
        gate.policy = .oneFingerToCanvas_twoFingersToZoom

        // レイアウト
        zoom.frame = container.bounds
        zoom.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        canvas.frame = container.bounds
        canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        gate.frame = container.bounds
        gate.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // 重ね順
        container.addSubview(zoom)
        container.addSubview(canvas)
        container.addSubview(gate)

        DispatchQueue.main.async {
            self.canvasRef = canvas
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let zoom = uiView.subviews.compactMap({ $0 as? ZoomPanUIView }).first else { return }
        guard let canvas = uiView.subviews.compactMap({ $0 as? DrawingCanvasView }).first else {
            return
        }
        guard let gate = uiView.subviews.compactMap({ $0 as? TouchGateView }).first else { return }

        // ここで “モードに応じたポリシー” を切り替える
        // - pen/stamp/eraser: 1本指はcanvas、2本指はzoom
        // - none: 全部zoom（パン1本も2本も、ズーム2本）
        if canvas.mode == .none {
            gate.policy = .allToZoom
            zoom.isTwoFingerPanOnly = false
        } else {
            gate.policy = .oneFingerToCanvas_twoFingersToZoom
            zoom.isTwoFingerPanOnly = true  // 1本指パンを抑止（2本指パンのみ）
        }

        // zoom命令
        switch zoomRequest {
        case .none:
            break

        case .reset:
            zoom.resetViewport()
            DispatchQueue.main.async { self.zoomRequest = .none }

        case .set(let scale, let centerInImage):
            zoom.setViewport(scale: scale, centerInImage: centerInImage)
            DispatchQueue.main.async { self.zoomRequest = .none }
        }
    }
}
