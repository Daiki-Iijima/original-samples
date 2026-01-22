import DrawingKit
import SwiftUI

/// ペンの設定
struct PenSettings: Equatable {
    var color: Color = .red
    var width: CGFloat = 4
    var opacity: CGFloat = 1.0
}

/// スタンプの設定
struct StampSettings: Equatable {
    var kind: StampKind = .check
    var color: Color = .red
    var size: CGFloat = 36
    var opacity: CGFloat = 1.0
}

/// 消しゴムの設定
struct EraserSettings: Equatable {
    var radius: CGFloat = 18
}

/// 描画ツール全体の設定
struct DrawingSettings: Equatable {
    /// 今どのツールで描くか
    var tool: DrawMode = .pen

    var pen = PenSettings()
    var stamp = StampSettings()
    var eraser = EraserSettings()
}
