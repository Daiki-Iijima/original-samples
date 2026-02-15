import Foundation
import CoreGraphics

/// Operation 画面のユーザー設定
struct OperationConfig: Codable, Equatable, Sendable {

    struct SelectionStyle: Codable, Equatable, Sendable {
        var strokeColor: HexColor = .init(hex: "#00C853") // green-ish
        var strokeAlpha: Double = 1.0
        var strokeWidth: Double = 4

        var fillColor: HexColor = .init(hex: "#00C853")
        var fillAlpha: Double = 0.18
        var fillEnabled: Bool = true
        
        //  矩形の中の色
        var textColor: HexColor = .init(hex: "#FFFFFF")
        var textAlpha: Double = 1.0
    }

    struct CheckedStyle: Codable, Equatable, Sendable {
        var strokeColor: HexColor = .init(hex: "#1976D2") // blue
        var strokeAlpha: Double = 1.0
        var strokeWidth: Double = 2
        
        var fillEnabled: Bool = false
        var fillAlpha: Double = 0.0
        var fillColor: HexColor = .init(hex: "#1976D2")
        
        //  矩形の中の色
        var textColor: HexColor = .init(hex: "#FFFFFF")
        var textAlpha: Double = 1.0
    }

    struct UnconfirmedStyle: Codable, Equatable, Sendable {
        var strokeColor: HexColor = .init(hex: "#FBC02D") // yellow
        var strokeAlpha: Double = 1.0
        var strokeWidth: Double = 2

        var fillColor: HexColor = .init(hex: "#FBC02D")
        var fillAlpha: Double = 0.12
        var fillEnabled: Bool = true
        
        //  矩形の中の色
        var textColor: HexColor = .init(hex: "#FFFFFF")
        var textAlpha: Double = 1.0
    }

    struct PanelWidths: Codable, Equatable, Sendable {
        var drawingTools: Double = 320
        var unconfirmedParts: Double = 360
        var memo: Double = 360
        var linkProjects: Double = 360
    }

    var selection: SelectionStyle = .init()
    var checked: CheckedStyle = .init()
    var unconfirmed: UnconfirmedStyle = .init()
    var panels: PanelWidths = .init()

    static let `default` = OperationConfig()
}
