import DrawingKit
import SwiftUI
import UIKit

// UIモード
enum InteractionMode: Equatable {
    case normal
    case drawing
    case camera
}

// iPhone sheet route
enum PanelRoute: String, Identifiable {
    case drawingTools
    case unconfirmedParts
    case memo
    case linkProjects

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
    
    static let linkProjects: [LinkProjectItem] = {
        // プロジェクト定義
        let projects: [LinkProjectItem] = [
            LinkProjectItem(id:"proj_a", name:"プロジェクトA"),
            LinkProjectItem(id:"proj_b", name:"プロジェクトB"),
            LinkProjectItem(id:"proj_c", name:"プロジェクトC"),
        ]
        return projects
    }()

    static let overlayRects: [CanvasRect] = {
        var rects: [CanvasRect] = []

        let startX: CGFloat = 80
        let startY: CGFloat = 80
        let stepX: CGFloat = 140
        let stepY: CGFloat = 120

        let sizeRange: ClosedRange<CGFloat> = 60...110

        // プロジェクト定義
        let projects: [(id: String, name: String)] = [
            ("proj_a", "プロジェクトA"),
            ("proj_b", "プロジェクトB"),
            ("proj_c", "プロジェクトC"),
        ]

        var index = 1

        for row in 0..<4 {
            for col in 0..<5 {

                let w = CGFloat.random(in: sizeRange)
                let h = CGFloat.random(in: sizeRange)

                let x = startX + CGFloat(col) * stepX + CGFloat.random(in: -10...10)
                let y = startY + CGFloat(row) * stepY + CGFloat.random(in: -10...10)

                let isChecked = index % 7 == 0      // たまに確認済
                let isHidden  = index % 11 == 0     // たまに非表示

                // --- プロジェクト割当（3つをローテーション） ---
                let project = projects[(index - 1) % projects.count]

                let rect = CanvasRect(
                    externalID: String(format: "P-%03d", index),
                    name: "部品\(index)",
                    projectID: project.id,
                    projectName: project.name,
                    isChecked: isChecked,
                    isHidden: isHidden,
                    rect: CGRect(x: x, y: y, width: w, height: h),
                    style: CanvasRectStyle(
                        strokeColor: .systemYellow,
                        strokeWidth: 2,
                        fill: isChecked
                            ? .none
                            : .solid(UIColor.systemYellow.withAlphaComponent(0.12))
                    )
                )

                rects.append(rect)
                index += 1
            }
        }

        return rects
    }()
}
