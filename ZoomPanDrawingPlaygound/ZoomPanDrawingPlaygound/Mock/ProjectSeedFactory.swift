import Foundation
import YamatoAPIKit
import YamatoAppContracts

public enum ProjectSeedFactory {

    /// ProjectSeed 単体生成（ここは “単体の生成” のみに責務を絞る）
    public static func make(
        projectID: String,
        seed: String,
        name: String = "配管工事プロジェクトA（検証）"
    ) -> ProjectSeed {

        let thumbnailURL = URL(string: "https://picsum.photos/seed/\(seed)-thumb/300/300")

        let drawingURLs: [URL] = [
            URL(string: "https://picsum.photos/seed/\(seed)-draw-1/1200/800")!,
            URL(string: "https://picsum.photos/seed/\(seed)-draw-2/1200/800")!,
            URL(string: "https://picsum.photos/seed/\(seed)-draw-3/1200/800")!
        ]

        return ProjectSeed(
            id: projectID,
            name: name,
            thumbnailURL: thumbnailURL,
            drawingImageURLs: drawingURLs,
            instructionNumbers: ["12-3456", "12-3456-ALT01"],
            linkIDs: ["L-\(projectID)-A", "L-\(projectID)-B"],
            memoURL: .dummyMemo,
            pipeListURL: .dummyPipeList,
            checkbackUserGeneral: "一般ユーザー太郎",
            checkbackAtGeneral: Date(timeIntervalSince1970: 1_706_525_600),
            checkbackUserCenter: "加工センター花子",
            checkbackAtCenter: Date(timeIntervalSince1970: 1_706_531_000)
        )
    }
}
