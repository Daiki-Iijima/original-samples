import Foundation
import CoreGraphics

//  pipe_list_url

struct PipeListResponseDTO: Codable {
    let pipeList: [PipeItemDTO]

    enum CodingKeys: String, CodingKey {
        case pipeList = "pipe_list"
    }
}

struct PipeItemDTO: Codable {
    let pipeCheckID: String
    let pipeName: String
    let checkbackInfo: CheckbackInfoDTO
    let dxfRect: RectDTO
    let imageRect: RectDTO

    enum CodingKeys: String, CodingKey {
        case pipeCheckID = "pipe_check_id"
        case pipeName = "pipe_name"
        case checkbackInfo = "checkback_info"
        case dxfRect = "dxf_rect"
        case imageRect = "image_rect"
    }
}

struct CheckbackInfoDTO: Codable {
    let checkbacked: Bool
    let checkbackUser: String?
    let checkbackAt: Date?

    enum CodingKeys: String, CodingKey {
        case checkbacked
        case checkbackUser = "checkback_user"
        case checkbackAt = "checkback_at"
    }
}

struct RectDTO: Codable {
    let origin: PointDTO
    let size: SizeDTO
}

struct PointDTO: Codable {
    let x: CGFloat
    let y: CGFloat
}

struct SizeDTO: Codable {
    let x: CGFloat
    let y: CGFloat
}

extension RectDTO {
    var cgRect: CGRect {
        CGRect(x: origin.x, y: origin.y, width: size.x, height: size.y)
    }
}
