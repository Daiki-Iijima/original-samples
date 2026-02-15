import DrawingKit
import UIKit

//  PipeListDTO -> CanvasRect
enum PipeListMapper {
    static func toCanvasRects(
        _ items: [PipeItemDTO],
        projectID: String,
        projectName: String
    ) -> [CanvasRect] {
        items.map { item in
            let checked = item.checkbackInfo.checkbacked

            // checkedなら薄く/触れない仕様にするなら isChecked=true
            // ※あなたの既存ロジック：isCheckedは「確認済みで一覧から除外」じゃなく
            // 「未確認一覧のフィルタで除外」になってるので、ここは仕様次第
            let isChecked = checked

            let style = CanvasRectStyle(
                strokeColor: checked ? .systemGray : .systemYellow,
                strokeWidth: checked ? 2 : 2,
                fill: checked
                    ? .none
                    : .solid(UIColor.systemYellow.withAlphaComponent(0.12))
            )

            return CanvasRect(
                id: StableUUID.make(item.pipeCheckID),
                externalID: item.pipeCheckID,
                name: item.pipeName,
                projectID: projectID,
                projectName: projectName,
                isChecked: isChecked,
                isHidden: false,
                rect: item.imageRect.cgRect,
                style: style
            )
        }
    }
}
