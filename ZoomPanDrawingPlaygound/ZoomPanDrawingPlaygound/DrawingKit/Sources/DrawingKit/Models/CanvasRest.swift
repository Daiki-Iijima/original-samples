import CoreGraphics
import UIKit

public enum RectFill: Equatable {
    case none
    case solid(UIColor)
}

public struct CanvasRectStyle: Equatable, @unchecked Sendable {
    public var strokeColor: UIColor
    public var strokeWidth: CGFloat
    public var fill: RectFill

    public init(
        strokeColor: UIColor,
        strokeWidth: CGFloat = 2,
        fill: RectFill = .none
    ) {
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.fill = fill
    }

    public static let initial = CanvasRectStyle(
        strokeColor: .systemYellow,
        strokeWidth: 2,
        fill: .none
    )
}

/// 画像座標（左上原点）で指定する矩形
public struct CanvasRect: Equatable, Identifiable {
    // ---- 既存 ----
    public var id: UUID
    public var rect: CGRect
    public var style: CanvasRectStyle

    // ---- 業務フィールド ----

    /// 外部データの固有ID（DBやAPIのIDなど）
    /// UUID/Int/ULID など何でも入れられるよう String 推奨
    public var externalID: String?

    /// 表示名（UI一覧で使う）
    public var name: String

    /// 業務フラグ：チェック済み
    public var isChecked: Bool

    /// 表示/非表示（業務都合で非表示判定したいならあると便利）
    public var isHidden: Bool

    public init(
        id: UUID = UUID(),
        externalID: String? = nil,
        name: String = "",
        isChecked: Bool = false,
        isHidden: Bool = false,
        rect: CGRect,
        style: CanvasRectStyle = .initial
    ) {
        self.id = id
        self.externalID = externalID
        self.name = name
        self.isChecked = isChecked
        self.isHidden = isHidden
        self.rect = rect
        self.style = style
    }
}

extension CanvasRect {
    /// 業務状態を加味した「実際に描画に使うスタイル」
    public var effectiveStyle: CanvasRectStyle {
        guard !isChecked else {
            // チェック済み：例えば緑にする（好みで）
            var s = style
            s.strokeColor = .systemGreen
            // fill も変えたいならここで
            // s.fill = .solid(UIColor.systemGreen.withAlphaComponent(0.12))
            return s
        }
        return style
    }

    /// 描画すべきか（非表示や業務判定をここに集約）
    public var shouldRender: Bool {
        !isHidden && !isChecked
    }
}
