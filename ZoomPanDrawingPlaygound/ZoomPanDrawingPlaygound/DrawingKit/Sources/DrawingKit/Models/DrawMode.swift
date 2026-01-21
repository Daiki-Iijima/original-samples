import Foundation

//  描画モード
public enum DrawMode: CaseIterable {
    case pen
    case stamp
    case eraser
    case none

    public var icon: String {
        switch self {
        case .pen: return "pencil.tip"
        case .stamp: return "seal.fill"
        case .eraser: return "eraser.fill"
        case .none: return "hand.draw"
        }
    }

    public var title: String {
        switch self {
        case .pen: return "ペン"
        case .stamp: return "スタンプ"
        case .eraser: return "消しゴム"
        case .none: return "操作"
        }
    }
}
