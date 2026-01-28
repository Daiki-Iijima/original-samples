import DrawingKit
import SwiftUI
import UIKit

// UIモード
enum InteractionMode: Equatable {
    case normal
    case drawing
    case zoomPreset
    case rectPreset
}

// iPhone sheet route
enum PanelRoute: String, Identifiable {
    case drawing
    case rectList
    case selection

    var id: String { rawValue }
}

struct ZoomPreset: Equatable {
    var centerX: CGFloat
    var centerY: CGFloat
    var scale: CGFloat
}

struct RectPreset: Equatable {
    var centerX: CGFloat
    var centerY: CGFloat
    var width: CGFloat
    var height: CGFloat
}

enum SampleData {
    static let overlayRects: [CanvasRect] = [
        CanvasRect(
            externalID: "A-001",
            name: "部品A",
            isChecked: false,
            isHidden: false,
            rect: CGRect(x: 100, y: 120, width: 220, height: 160),
            style: CanvasRectStyle(
                strokeColor: .systemYellow,
                strokeWidth: 3,
                fill: .solid(UIColor.systemYellow.withAlphaComponent(0.15))
            )
        ),
        CanvasRect(
            externalID: "B-002",
            name: "部品B（確認済）",
            isChecked: true,
            isHidden: false,
            rect: CGRect(x: 380, y: 140, width: 180, height: 120),
            style: CanvasRectStyle(
                strokeColor: .systemYellow,
                strokeWidth: 3,
                fill: .none
            )
        ),
        CanvasRect(
            externalID: "C-003",
            name: "部品C（非表示）",
            isChecked: false,
            isHidden: true,
            rect: CGRect(x: 160, y: 340, width: 200, height: 140),
            style: CanvasRectStyle(
                strokeColor: .systemYellow,
                strokeWidth: 3,
                fill: .none
            )
        ),
    ]
}
