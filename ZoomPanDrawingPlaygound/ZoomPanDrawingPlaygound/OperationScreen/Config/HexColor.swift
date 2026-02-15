import Foundation
import SwiftUI
import UIKit

/// Hex(#RRGGBB) を保存用に持つ軽量型
struct HexColor: Codable, Equatable, Sendable {
    var hex: String  // "#RRGGBB"

    init(hex: String = "#FF0000") {
        self.hex = HexColor.normalize(hex)
    }

    static func normalize(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !s.hasPrefix("#") { s = "#\(s)" }
        if s.count == 4 {
            // #RGB -> #RRGGBB
            let chars = Array(s)
            s = "#\(chars[1])\(chars[1])\(chars[2])\(chars[2])\(chars[3])\(chars[3])"
        }
        if s.count != 7 { return "#000000" }
        return s
    }

    var uiColor: UIColor {
        UIColor(hex: hex) ?? .black
    }

    var swiftUIColor: Color {
        Color(uiColor)
    }
}

private extension UIColor {
    convenience init?(hex: String) {
        let s = HexColor.normalize(hex)
        let hexPart = String(s.dropFirst())

        guard hexPart.count == 6, let v = Int(hexPart, radix: 16) else { return nil }

        let r = CGFloat((v >> 16) & 0xFF) / 255.0
        let g = CGFloat((v >> 8) & 0xFF) / 255.0
        let b = CGFloat(v & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

extension Color {
    /// 色空間ズレOK前提：ColorPicker で選んだ色を #RRGGBB に丸める
    func toHexStringLossy() -> String {
        let uiColor = UIColor(self)

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return "#000000"
        }

        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))

        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }
}

extension Binding where Value == HexColor {
    /// HexColor <-> ColorPicker を繋ぐ
    func asColorBindingLossy() -> Binding<Color> {
        Binding<Color>(
            get: { self.wrappedValue.swiftUIColor },
            set: { newColor in
                self.wrappedValue = HexColor(hex: newColor.toHexStringLossy())
            }
        )
    }
}
