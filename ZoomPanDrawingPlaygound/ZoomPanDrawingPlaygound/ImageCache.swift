import Foundation

/// entryProject の画像だけ固定（ロック）するキャッシュ
/// - 「画面復帰のたびに一覧は更新するが、entry画像だけ使い回す」要件を満たす
@MainActor
final class ImageCache {
    static let shared = ImageCache()
    private init() {}

    private var lockedEntry: [String: LoadedImage] = [:]   // projectID -> 固定画像

    func entryImage(for projectID: String) -> LoadedImage? {
        lockedEntry[projectID]
    }

    func setEntryImage(_ image: LoadedImage, for projectID: String) {
        lockedEntry[projectID] = image
    }

    func clearEntryImage(for projectID: String) {
        lockedEntry.removeValue(forKey: projectID)
    }

    func resetAll() {
        lockedEntry.removeAll()
    }
}
