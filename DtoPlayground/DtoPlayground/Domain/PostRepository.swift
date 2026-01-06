import Foundation

//  Domainが知っている情報はプロトコル(インターフェイス)だけで、保存方法は知らない
public protocol PostRepository {
    func load() throws -> LoadResult
    func save(posts: [Post], preservedUnknownEntries: [AnyUnknownEntry]) throws
}

//  未知要素の格納用
//  Domainの知らないPostの場合はこれになる
public struct AnyUnknownEntry: Equatable {
    public let type: String
    public let payload: Data

    public init(type: String, payload: Data) {
        self.type = type
        self.payload = payload
    }
}

public struct LoadResult {
    public let posts: [Post]
    public let unknownEntries: [AnyUnknownEntry]

    public init(posts: [Post], unknownEntries: [AnyUnknownEntry]) {
        self.posts = posts
        self.unknownEntries = unknownEntries
    }
}
