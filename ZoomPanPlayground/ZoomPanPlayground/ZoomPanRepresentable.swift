import SwiftUI
import UIKit

struct ZoomPanRepresentable: UIViewRepresentable {

    //  表示する画像
    //  SwiftUI側から渡される
    let image: UIImage

    //  ZoomPanUIViewに渡すための橋渡し的な変数
    var isTwoFingerPanOnly: Bool

    func makeUIView(context: Context) -> ZoomPanUIView {

        let zoomPanUIView = ZoomPanUIView()
        zoomPanUIView.setImage(image)

        return zoomPanUIView
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {

        uiView.isTwoFingerPanOnly = isTwoFingerPanOnly
    }
}
