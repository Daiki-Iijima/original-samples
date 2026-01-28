import DrawingKit
import SwiftUI
import UIKit

extension OperationScreen {

    func saveMergedToPhotos() {
        guard let canvas else { return }
        guard let base = UIImage(named: "sample1") else { return }
        let merged = canvas.exportMergedImage(baseImage: base)
        UIImageWriteToSavedPhotosAlbum(merged, nil, nil, nil)
    }

    func saveDrawingLocal() {
        guard let canvas else { return }
        do {
            let data = try canvas.exportDrawingData()
            var pkg = DrawingPackage(
                imageKey: imageKey,
                drawingKey: drawingKey,
                drawingData: data
            )
            pkg.updatedAt = Date()
            try DrawingLocalStore.shared.save(pkg)
            print("✅ saved:", imageKey, drawingKey)
        } catch {
            print("❌ save failed:", error)
        }
    }

    func loadDrawingLocal() {
        guard let canvas else { return }
        do {
            let pkg = try DrawingLocalStore.shared.load(imageKey: imageKey, drawingKey: drawingKey)
            try canvas.importDrawingData(pkg.drawingData)
            print("✅ loaded:", imageKey, drawingKey)
        } catch {
            print("❌ load failed:", error)
        }

        // overlay も反映
        syncOverlayRects()
    }
}
