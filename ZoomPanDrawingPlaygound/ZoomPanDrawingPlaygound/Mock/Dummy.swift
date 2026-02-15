import Foundation
import CoreGraphics
import YamatoAPIKit

extension URL {
    static let dummyPipeList = URL(string: "app://dummy/pipe_list")!
    static let dummyMemo = URL(string: "app://dummy/memo")!
}

public struct DummyPipeListFactory {

    static func makeJSONData(
        count: Int,
        startX: CGFloat = 60,
        startY: CGFloat = 60,
        stepX: CGFloat = 80,
        stepY: CGFloat = 80,
        rectSize: CGSize = CGSize(width: 40, height: 30)
    ) throws -> Data {

        var items: [PipeItemDTO] = []
        let columns = Int(sqrt(Double(count)).rounded(.up))

        for i in 0..<count {
            let col = i % columns
            let row = i / columns

            let originX = startX + CGFloat(col) * stepX
            let originY = startY + CGFloat(row) * stepY

            let isChecked = i % 5 == 0

            let item = PipeItemDTO(
                pipeCheckID: "P-\(String(format: "%03d", i + 1))",
                pipeName: "部材\(i + 1)",
                checkbackInfo: CheckbackInfoDTO(
                    checkbacked: isChecked,
                    checkbackUser: isChecked ? "ダミーユーザー" : nil,
                    checkbackAt: isChecked ? Date(timeIntervalSince1970: 1_800_000_000) : nil
                ),
                dxfRect: RectDTO(
                    origin: PointDTO(x: originX, y: originY),
                    size: SizeDTO(x: rectSize.width, y: rectSize.height)
                ),
                imageRect: RectDTO(
                    origin: PointDTO(x: originX, y: originY),
                    size: SizeDTO(x: rectSize.width, y: rectSize.height)
                )
            )

            items.append(item)
        }

        let response = PipeListResponseDTO(pipeList: items)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(response)
    }
}

/// ダミー用メモ生成
public enum DummyMemoFactory {

    public static func makeText(
        projectID: String,
        projectName: String
    ) -> String {

        """
        【ダミーメモ】
        プロジェクトID: \(projectID)
        プロジェクト名: \(projectName)

        ・このメモはダミーです
        ・pipe_list と同様、app://dummy スキーム時のみ使用されます
        ・UI / 保存 / 編集動作確認用

        TODO:
        - 現地確認
        - 再チェック対象あり
        - 加工センターへ連絡

        更新日時: \(iso(Date()))
        """
    }

    private static func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}
