import Foundation

/// アプリ側の保存パッケージ（DrawingKit の internal 型に依存しない）
struct DrawingPackage: Codable {
    var packageVersion: Int = 1

    var imageKey: String
    var drawingKey: String

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// DrawingCanvasView.exportDrawingData() の生データ
    var drawingData: Data
}
