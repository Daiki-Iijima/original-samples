import CoreFoundation
import Foundation

//  Domainが知っているプロトコルに準拠したRepositoryを定義
final class JSONPostRepository: PostRepository {
    private let fileName = "timeline.json"

    func load() throws -> LoadResult {

        let url = try fileURL()

        //  データがなかったら何もなし
        guard FileManager.default.fileExists(atPath: url.path) else {
            return LoadResult(posts: [], unknownEntries: [])
        }

        let data = try Data(contentsOf: url)
        let loadedData = try TimelineJSON.makeDecoder().decode(TimelineDocument.self, from: data)

        var posts: [Post] = []
        var unknown: [AnyUnknownEntry] = []

        for entry in loadedData.entries {
            switch entry.type {
            case "text":
                if let dto = try? TimelineJSON.makeDecoder().decode(
                    TextPostDTO.self, from: entry.payload)
                {
                    posts.append(.text(dto.toModel()))
                } else {
                    //  型は定義済みだが、Jsonがパースできなかったので壊れている
                    //  これも未知のデータとして扱う
                    unknown.append(.init(type: entry.type, payload: entry.payload))
                }
            case "mood":
                if let dto = try? TimelineJSON.makeDecoder().decode(
                    MoodPostDTO.self, from: entry.payload)
                {
                    posts.append(.mood(dto.toModel()))
                } else {
                    //  型は定義済みだが、Jsonがパースできなかったので壊れている
                    //  これも未知のデータとして扱う
                    unknown.append(.init(type: entry.type, payload: entry.payload))
                }
            default:
                //  プログラムとしては認知していないがデータとしてある未知の情報もここでハンドリングできる
                unknown.append(.init(type: entry.type, payload: entry.payload))
            }
        }

        posts.sort { $0.createdAt > $1.createdAt }

        return LoadResult(posts: posts, unknownEntries: unknown)
    }

    func save(posts: [Post], preservedUnknownEntries: [AnyUnknownEntry]) throws {
        var entries: [TimelineEntry] = []

        //  PostをTimelineEntryに変換
        for post in posts {
            let entry = try TimelineEntry.fromPost(post)
            entries.append(entry)
        }

        //  未知のEntryもTimeLineEntryに変換
        for u in preservedUnknownEntries {
            entries.append(TimelineEntry(type: u.type, payload: u.payload))
        }

        //  Jsonに変換して保存
        let doc = TimelineDocument(version: 1, entries: entries)
        let data = try TimelineJSON.makeEncoder().encode(doc)

        let url = try fileURL()
        try data.write(to: url, options: [.atomic])
    }

    //  ファイルの保存パスを生成
    private func fileURL() throws -> URL {
        let dir = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return dir.appendingPathComponent(fileName)
    }
}

//  DTO <-> Domain Modelの相互変換拡張を定義

extension TextPostDTO {
    fileprivate func toModel() -> TextPost {
        TextPost(
            id: UUID(uuidString: id) ?? UUID(),
            createdAt: createdAt,
            message: message
        )
    }

    fileprivate init(_ model: TextPost) {
        self.id = model.id.uuidString
        self.createdAt = model.createdAt
        self.message = model.message
    }
}

extension MoodPostDTO {
    fileprivate func toModel() -> MoodPost {
        MoodPost(
            id: UUID(uuidString: id) ?? UUID(),
            createdAt: createdAt,
            emoji: emoji,
            intensity: intensity
        )
    }

    fileprivate init(_ model: MoodPost) {
        self.id = model.id.uuidString
        self.createdAt = model.createdAt
        self.emoji = model.emoji
        self.intensity = model.intensity
    }
}

//  ここでDomain Modelを受け取って、DTOに変換の後、TimelineEntryにする
extension TimelineEntry {
    fileprivate static func fromPost(_ post: Post) throws -> TimelineEntry {
        let encoder = TimelineJSON.makeEncoder()

        switch post {
        case .text(let p):
            let dto = TextPostDTO(p)  // このファイルの中で拡張したTextPostDTOのコンストラクタが動く
            //  TimelineEntryに入れる時はdtoはjsonにする
            return TimelineEntry(type: "text", payload: try encoder.encode(dto))
        case .mood(let p):
            let dto = MoodPostDTO(p)  // このファイルの中で拡張したMoodPostDTOのコンストラクタが動く
            //  TimelineEntryに入れる時はdtoはjsonにする
            return TimelineEntry(type: "mood", payload: try encoder.encode(dto))
        }
    }
}
