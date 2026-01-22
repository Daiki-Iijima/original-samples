import Foundation

/// 作業のモード
/// 表示系はここには入れない(矩形一覧など)
public enum InteractionMode: Equatable {
    case normal
    case drawing
    case zoomPreset
    case rectPreset
}
