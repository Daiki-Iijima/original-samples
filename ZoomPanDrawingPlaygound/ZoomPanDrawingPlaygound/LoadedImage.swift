import Foundation
import UIKit

/// 作業用の画像のデータ保持用構造体
/// - URL からダウンロードして UIImage にする
/// - name は URL の lastPathComponent を基本に、変なら自前生成
struct LoadedImage: Sendable {
    let name: String
    let image: UIImage
    let url: URL

    init(url: URL) async throws {
        self.url = url

        //  URLから画像ダウンロード
        //    - ここで throw されるので呼び出し側は do-catch できる
        let (data, resp) = try await URLSession.shared.data(from: url)

        // ステータス確認（画像直URLなら 200 以外は基本おかしい）
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        //  UIImage化（失敗したらdecode不能）
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        self.image = image

        //  ファイル名
        let raw = url.lastPathComponent
        if raw.isEmpty || !raw.contains(".") {
            self.name = "image_\(UUID().uuidString).png"
        } else {
            self.name = raw
        }
    }

    ///  初期値用（全部""でいい、という要望に合わせて “空のダミー” を用意）
    /// - image は必要なので 1x1 の透明画像を入れる
    static let initial: LoadedImage = {
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        let img = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        return LoadedImage(
            name: "",
            image: img,
            url: URL(string: "about:blank")!
        )
    }()

    // private init（initial用）
    private init(name: String, image: UIImage, url: URL) {
        self.name = name
        self.image = image
        self.url = url
    }
}
