import Foundation

/// Undo/Redo 用の履歴管理
/// - “done/undone を配列で持つ” のが一番シンプルな構成
final class DrawingHistory<Element> {
    private(set) var done: [Element] = []
    private(set) var undone: [Element] = []

    func push(_ element: Element) {
        done.append(element)
        // 新しい操作が入ったら redo は破棄するのが一般的
        undone.removeAll()
    }

    func undo() -> Element? {
        guard let last = done.popLast() else { return nil }
        undone.append(last)
        return last
    }

    func redo() -> Element? {
        guard let last = undone.popLast() else { return nil }
        done.append(last)
        return last
    }

    func clear() {
        done.removeAll()
        undone.removeAll()
    }

    /// deserialize などで「一括置き換え」したい時用
    /// - これを用意しておくと import 時に余計な redo 破棄ロジック等を踏まなくて済む
    func replaceAll(done newDone: [Element], undone newUndone: [Element] = []) {
        done = newDone
        undone = newUndone
    }
}
