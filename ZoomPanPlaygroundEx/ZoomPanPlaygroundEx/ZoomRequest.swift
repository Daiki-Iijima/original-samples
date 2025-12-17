import CoreGraphics

enum ZoomRequest: Equatable {
    case none  // 何もしない
    case reset  // リセット
    case set(scale: CGFloat, centerInImage: CGPoint)  // 指定スケール&指定画像座標へジャンプ
}
