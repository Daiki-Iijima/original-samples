import Foundation
import YamatoAPIKit
import UIKit

struct ProjectVM: Identifiable{
    let id: String
    var name: String

    // 毎回更新されるURL群（DTO由来）
    var thumbnailURL: URL?
    var pipeListURL: URL?
    var memoURL: URL?

    // それに紐づく毎回更新されるデータ
    var loadedThumb: LoadedImage?
    var memoText: String?

    // その他DTO情報（必要なら）
    var instructionNumbers: [String]
    var linkIDs: [String]
    var checkbackUserGeneral: String?
    var checkbackAtGeneral: Date?
    var checkbackUserCenter: String?
    var checkbackAtCenter: Date?

    init(dto: ProjectDTO) {
        self.id = dto.id
        self.name = dto.name
        self.thumbnailURL = dto.thumbnailURL
        self.pipeListURL = dto.pipeListURL
        self.memoURL = dto.memoURL

        self.loadedThumb = nil
        self.memoText = nil

        self.instructionNumbers = dto.instructionNumbers
        self.linkIDs = dto.linkIDs
        self.checkbackUserGeneral = dto.checkbackUserGeneral
        self.checkbackAtGeneral = dto.checkbackAtGeneral
        self.checkbackUserCenter = dto.checkbackUserCenter
        self.checkbackAtCenter = dto.checkbackAtCenter
    }
}
