import UIKit

//  ペンが持っている情報
//  UIColorがUI管轄のデータになるので、メインスレッドで使うことを前提として構造体を定義する
@MainActor
public struct PenStyle: Equatable {
    //  色
    public var color: UIColor
    //  線の幅
    public var lineWidth: CGFloat
    //  透明度
    public var opacity: CGFloat
    
    public init(color: UIColor, lineWidth: CGFloat, opacity: CGFloat) {
        self.color = color
        self.lineWidth = lineWidth
        self.opacity = opacity
    }
    
    //  デフォルトの値を入れやすいように定義
    public static let initial = PenStyle(color: .red, lineWidth: 4, opacity: 1)
}
