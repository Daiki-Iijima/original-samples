import CoreFoundation
import Foundation

//  Domainを壊さずに将来互換を作るための層
//  - TimelineDocument: ルート
//  - TimelineEntry: type + payload
//  - DTO: Codable向けの素朴な型

struct TimelineDocument: Codable {
    var version: Int
    var entries: [TimelineEntry]

    init(version: Int = 1, entries: [TimelineEntry]) {
        self.version = version
        self.entries = entries
    }
}

//  保存するデータを最大限抽象化した入れ物
struct TimelineEntry: Codable, Equatable {
    var type: String  // "text" / "mood" / これから拡張可能
    var payload: Data  // バイト列(base64を想定)
}

//  --- DTO ---
//  Domainが持っているデータを保存する単位を定義
//  DomainのModelと必ずしも1:1になるとは限らない

struct TextPostDTO: Codable, Equatable {
    var id: String
    var createdAt: Date
    var message: String
}

struct MoodPostDTO: Codable, Equatable {
    var id: String
    var createdAt: Date
    var emoji: String
    var intensity: Int
}

//  JSON変換周りの設定をまとめて定義
//  DateをISO8601で保存
enum TimelineJSON {
    static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
