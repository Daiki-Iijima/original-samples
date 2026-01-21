import SwiftUI
import UIKit

struct ZoomPanRepresentable: UIViewRepresentable {

    //  表示する画像
    //  SwiftUI側から渡される
    let image: UIImage

    //  ZoomPanUIViewに渡すための橋渡し的な変数
    var isTwoFingerPanOnly: Bool

    //  SwiftUI側で監視できるようにする
    @Binding var viewportState: ViewportState
    @Binding var zoomRequest: ZoomRequest

    func makeUIView(context: Context) -> ZoomPanUIView {

        let zoomPanUIView = ZoomPanUIView()
        zoomPanUIView.setImage(image)

        //  ViewPortの更新を受けたらSwiftUI側の数値を変更して再描画
        zoomPanUIView.onViewportChanged = { state in
            DispatchQueue.main.async {
                self.viewportState = state
            }
        }

        return zoomPanUIView
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        uiView.isTwoFingerPanOnly = isTwoFingerPanOnly
        
        switch zoomRequest {
        case .none:
            break
        case .reset:
            uiView.resetViewport()
            //  処理したら何もしない状態に戻す
            DispatchQueue.main.async {
                self.zoomRequest = .none
            }
        case let .set(scale, center):
            uiView.setViewport(scale: scale, centerInImage: center)
            //  処理したら何もしない状態に戻す
            DispatchQueue.main.async {
                self.zoomRequest = .none
            }
        }
    }
}
