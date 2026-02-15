import Foundation
import YamatoAPIKit
import YamatoAppContracts

/// Preview / Mock 両方で使う「プロジェクトの元データ」
/// ここが “唯一の真実（SSOT）” になる
public struct ProjectSeed: Sendable {
    public let id: String
    public let name: String

    public let thumbnailURL: URL?
    public let drawingImageURLs: [URL]

    public let instructionNumbers: [String]
    public let linkIDs: [String]

    public let memoURL: URL?
    public let pipeListURL: URL?

    public let checkbackUserGeneral: String?
    public let checkbackAtGeneral: Date?
    public let checkbackUserCenter: String?
    public let checkbackAtCenter: Date?

    public init(
        id: String,
        name: String,
        thumbnailURL: URL?,
        drawingImageURLs: [URL],
        instructionNumbers: [String],
        linkIDs: [String],
        memoURL: URL?,
        pipeListURL: URL?,
        checkbackUserGeneral: String?,
        checkbackAtGeneral: Date?,
        checkbackUserCenter: String?,
        checkbackAtCenter: Date?
    ) {
        self.id = id
        self.name = name
        self.thumbnailURL = thumbnailURL
        self.drawingImageURLs = drawingImageURLs
        self.instructionNumbers = instructionNumbers
        self.linkIDs = linkIDs
        self.memoURL = memoURL
        self.pipeListURL = pipeListURL
        self.checkbackUserGeneral = checkbackUserGeneral
        self.checkbackAtGeneral = checkbackAtGeneral
        self.checkbackUserCenter = checkbackUserCenter
        self.checkbackAtCenter = checkbackAtCenter
    }
}

// MARK: - Converters

public extension ProjectSeed {
    func toDisplayProject() -> ProjectDisplayProject {
        ProjectDisplayProject(
            id: id,
            name: name,
            thumbnailURL: thumbnailURL,
            drawingImageURLs: drawingImageURLs,
            instructionNumbers: instructionNumbers,
            linkIDs: linkIDs,
            memoURL: memoURL,
            pipeListURL: pipeListURL,
            checkbackUserGeneral: checkbackUserGeneral,
            checkbackAtGeneral: checkbackAtGeneral,
            checkbackUserCenter: checkbackUserCenter,
            checkbackAtCenter: checkbackAtCenter
        )
    }
}

public extension ProjectSeed {
    func toProjectStubDTO() -> ProjectStubDTO {
        ProjectStubDTO(
            id: id,
            name: name,
            thumbnailURL: thumbnailURL,
            checkbackUserGeneral: checkbackUserGeneral,
            checkbackAtGeneral: checkbackAtGeneral,
            checkbackUserCenter: checkbackUserCenter,
            checkbackAtCenter: checkbackAtCenter,
            instructionNumbers: instructionNumbers,
            drawingImageURLs: drawingImageURLs,
            linkIDs: linkIDs,
            pipeListURL: pipeListURL,
            memoURL: memoURL
        )
    }
}
