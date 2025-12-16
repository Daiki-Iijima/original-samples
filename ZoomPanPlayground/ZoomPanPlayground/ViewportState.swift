import CoreGraphics

//  画面が描画している画像の情報
struct ViewportState: Equatable {
    var scale: CGFloat
    var rotation: CGFloat  // 度
    var translation: CGPoint
    var centerInImage: CGPoint  // 今画面に写っている情報の画像中心地点
    var visibleRectInImage: CGRect  // 画面が写している画像上の領域

    //  .initialで使える初期状態を定義
    static let initial = ViewportState(
        scale: 1,
        rotation: 0,
        translation: .zero,
        centerInImage: .zero,
        visibleRectInImage: .zero
    )
}
