import Foundation

/// キャンバスに対する「1回の操作」
///
/// Swiftでは「状態（elements）」と「操作（command）」を分けると、Undo/Redoが自然に作れる。
/// - 追加: 要素を1つ追加
/// - 消去: 複数要素をまとめて消す（Undoで戻すため、消した要素と元の位置を保持）
enum DrawingCommand: Equatable {
    case add(DrawingElement)
    case erase(EraseCommand)
}

/// 消しゴムで消した結果（Undoで戻すための情報）
struct EraseCommand: Equatable {
    var removed: [RemovedItem]
}

/// 「どこから」「何を」消したか（元のindexに戻せる）
struct RemovedItem: Equatable {
    var index: Int
    var element: DrawingElement
}
