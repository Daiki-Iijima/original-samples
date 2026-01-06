import Foundation
import Observation

@MainActor
@Observable
final class TimelineStore {
    private let repo: PostRepository

    private(set) var posts: [Post] = []
    private(set) var unknownCount: Int = 0

    //  未知のEntryの保持用
    //  次回のsaveで保存するため
    private var preservedUnknownEntries: [AnyUnknownEntry] = []

    init(repo: PostRepository = JSONPostRepository()) {
        self.repo = repo
    }

    func load() {
        do {
            let res = try repo.load()
            self.posts = res.posts
            self.preservedUnknownEntries = res.unknownEntries
            self.unknownCount = res.unknownEntries.count
        } catch {
            print("保存データ読み込み失敗:", error)
            self.posts = []
            self.preservedUnknownEntries = []
            self.unknownCount = 0
        }
    }

    func save() {
        do {
            try repo.save(posts: posts, preservedUnknownEntries: preservedUnknownEntries)
        } catch {
            print("保存失敗", error)
        }
    }

    func addText(_ message: String) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let p = TextPost(id: UUID(), createdAt: Date(), message: trimmed)
        //  先頭にねじ込む
        posts.insert(.text(p), at: 0)
        //  保存
        save()
    }

    func addMood(emoji: String, intensity: Int) {
        //  数値のまるめ処理
        let v = max(1, min(5, intensity))

        let p = MoodPost(id: UUID(), createdAt: Date(), emoji: emoji, intensity: v)
        //  先頭にねじ込む
        posts.insert(.mood(p), at: 0)
        //  保存
        save()
    }

    // わざと「未知type」を保存に混ぜる（将来バージョンが作ったデータを再現）
    func injectUnknown() {
        let fake = #"{"hello":"world","v":2}"#.data(using: .utf8) ?? Data()
        preservedUnknownEntries.insert(.init(type: "photo", payload: fake), at: 0)
        unknownCount = preservedUnknownEntries.count
        save()
    }

    //  全データ削除して保存
    func clearAllAndSave() {
        posts = []
        preservedUnknownEntries = []
        unknownCount = 0
        save()
    }
}
