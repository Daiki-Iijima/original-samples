import Foundation

//  このenumはTextPostかMoodPostのどちらかであることを約束している
//  和集合(Sum Type)を表現している
public enum Post: Equatable, Identifiable {
    case text(TextPost)
    case mood(MoodPost)

    //  IDは要素のIDを返す
    public var id: UUID {
        switch self {
        case .text(let p): return p.id
        case .mood(let p): return p.id
        }
    }
    
    //  並べ替えで使う
    public var createdAt: Date{
        switch self{
        case .text(let p): return p.createdAt
        case .mood(let p): return p.createdAt
        }
    }
}

//  Postに含まれるTextPost要素
public struct TextPost: Equatable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let message: String

    public init(id: UUID, createdAt: Date, message: String) {
        self.id = id
        self.createdAt = createdAt
        self.message = message
    }
}

//  Postに含まれるMoodPost要素
public struct MoodPost: Equatable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let emoji: String
    public let intensity: Int  // 1 ~ 5までの間のその時の気分の数値

    public init(id: UUID, createdAt: Date, emoji: String, intensity: Int) {
        self.id = id
        self.createdAt = createdAt
        self.emoji = emoji
        self.intensity = intensity
    }
}
