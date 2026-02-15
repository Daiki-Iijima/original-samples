import Foundation

/// ProjectDTO が decode できる形の “JSON生成用” DTO
public struct ProjectStubDTO: Encodable {
    let id: String
    let name: String
    let thumbnailURL: URL?

    let checkbackUserGeneral: String?
    let checkbackAtGeneral: Date?

    let checkbackUserCenter: String?
    let checkbackAtCenter: Date?

    let instructionNumbers: [String]
    let drawingImageURLs: [URL]
    let linkIDs: [String]

    let pipeListURL: URL?
    let memoURL: URL?

    enum CodingKeys: String, CodingKey {
        case id = "project_id"
        case name = "project_name"
        case thumbnailURL = "project_thumbnail_url"

        case checkbackUserGeneral = "checkback_user_general"
        case checkbackAtGeneral = "checkback_at_general"

        case checkbackUserCenter = "checkback_user_center"
        case checkbackAtCenter = "checkback_at_center"

        case instructionNumbers = "instruction_numbers"
        case drawingImageURLs = "project_drawing_image_urls"
        case linkIDs = "link_ids"

        case pipeListURL = "pipe_list_url"
        case memoURL = "project_memo_url"
    }
}
