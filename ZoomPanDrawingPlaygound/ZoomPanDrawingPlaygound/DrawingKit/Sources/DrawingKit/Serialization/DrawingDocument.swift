import UIKit
import CoreGraphics

// MARK: - DrawingElement（アプリ内部モデル）
//
// Swiftの enum は「取りうる要素の種類」を型として固定できる。
// 今は stroke だけでも、将来 stamp / eraser を case 追加で表現できる。

enum DrawingElement: Equatable {
    case stroke(Stroke)
    case stamp(Stamp)
    // 将来: 消しゴムを「要素」として扱うならここに追加
    // case eraserStroke(EraserStroke)
}

// MARK: - Document V2（保存形式）
//
// ここからが「壊れない」ポイント。
// enum を Codable にすると、未知caseが来たときに decode で落ちやすい。
// なので、要素は “type + payload(Data)” の封筒（Envelope）で保存する。

struct DrawingDocument: Codable {
    var version: Int
    var elements: [ElementEnvelope]

    init(version: Int = 2, elements: [ElementEnvelope]) {
        self.version = version
        self.elements = elements
    }
}

/// type と payload を持つ封筒
/// - type: "stroke" / "stamp" など
/// - payload: 各DTOを JSON 化した Data（base64 で保存される）
///
/// こうすると「未知 type」でも payload を丸ごと保持できる。
/// decode 側で type を知らなければ “無視する/保持する” の選択ができる。
struct ElementEnvelope: Codable, Equatable {
    var type: String
    var payload: Data
}

// MARK: - DTO（Codableに落とすための型）

struct StrokeDTO: Codable, Equatable {
    var id: String
    var points: [PointDTO]
    var style: PenStyleDTO
}

struct StampDTO: Codable, Equatable {
    var id: String
    var kind: StampKind
    var center: PointDTO
    var style: StampStyleDTO
}

struct PenStyleDTO: Codable, Equatable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double
    var lineWidth: Double
    var opacity: Double
}

struct StampStyleDTO: Codable, Equatable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double
    var size: Double
    var opacity: Double
}

struct PointDTO: Codable, Equatable {
    var x: Double
    var y: Double
}

// MARK: - 変換（Model <-> DTO）

extension StrokeDTO {
    init(_ stroke: Stroke) {
        self.id = stroke.id.uuidString
        self.points = stroke.points.map { .init(x: Double($0.x), y: Double($0.y)) }
        self.style = PenStyleDTO(stroke.style)
    }

    @MainActor func toModel() -> Stroke {
        let pts = points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        return Stroke(
            id: UUID(uuidString: id) ?? UUID(),
            points: pts,
            style: style.toModelPenStyle()
        )
    }
}

extension StampDTO {
    init(_ stamp: Stamp) {
        self.id = stamp.id.uuidString
        self.kind = stamp.kind
        self.center = .init(x: Double(stamp.center.x), y: Double(stamp.center.y))
        self.style = StampStyleDTO(stamp.style)
    }

    func toModel() -> Stamp {
        return Stamp(
            id: UUID(uuidString: id) ?? UUID(),
            kind: kind,
            center: CGPoint(x: CGFloat(center.x), y: CGFloat(center.y)),
            style: style.toModelStampStyle()
        )
    }
}

extension PenStyleDTO {
    init(_ style: PenStyle) {
        let rgba = style.color.rgbaComponents() ?? (r: 1, g: 0, b: 0, a: 1)
        self.r = Double(rgba.r)
        self.g = Double(rgba.g)
        self.b = Double(rgba.b)
        self.a = Double(rgba.a)
        self.lineWidth = Double(style.lineWidth)
        self.opacity = Double(style.opacity)
    }

    @MainActor func toModelPenStyle() -> PenStyle {
        let c = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
        return PenStyle(color: c, lineWidth: CGFloat(lineWidth), opacity: CGFloat(opacity))
    }
}

extension StampStyleDTO {
    init(_ style: StampStyle) {
        let rgba = style.color.rgbaComponents() ?? (r: 1, g: 0, b: 0, a: 1)
        self.r = Double(rgba.r)
        self.g = Double(rgba.g)
        self.b = Double(rgba.b)
        self.a = Double(rgba.a)
        self.size = Double(style.size)
        self.opacity = Double(style.opacity)
    }

    func toModelStampStyle() -> StampStyle {
        let c = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(a))
        return StampStyle(color: c, size: CGFloat(size), opacity: CGFloat(opacity))
    }
}

// MARK: - Envelope <-> DrawingElement

extension ElementEnvelope {
    static func fromElement(_ element: DrawingElement) throws -> ElementEnvelope {
        let encoder = JSONEncoder()

        switch element {
        case .stroke(let s):
            let dto = StrokeDTO(s)
            let data = try encoder.encode(dto)
            return ElementEnvelope(type: "stroke", payload: data)

        case .stamp(let s):
            let dto = StampDTO(s)
            let data = try encoder.encode(dto)
            return ElementEnvelope(type: "stamp", payload: data)
        }
    }

    /// decode：未知typeでも落ちないように “nil で返す” 方式にしてる
    /// - 将来「未知要素を保持したい」なら `.unknown(type,payload)` を case に追加してもOK
    @MainActor func toElement() -> DrawingElement? {
        let decoder = JSONDecoder()

        switch type {
        case "stroke":
            guard let dto = try? decoder.decode(StrokeDTO.self, from: payload) else { return nil }
            return .stroke(dto.toModel())

        case "stamp":
            guard let dto = try? decoder.decode(StampDTO.self, from: payload) else { return nil }
            return .stamp(dto.toModel())

        default:
            // 未知要素：ここでは “読み飛ばす”
            return nil
        }
    }
}

// MARK: - UIColor helper

private extension UIColor {
    func rgbaComponents() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (r, g, b, a)
    }
}
