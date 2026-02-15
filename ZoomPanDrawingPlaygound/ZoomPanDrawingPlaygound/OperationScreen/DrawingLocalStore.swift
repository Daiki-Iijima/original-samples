import Foundation

/// DrawingPackage をローカル(JSON)に保存・読み込みする責務を持つクラス
/// imageKey ごとにディレクトリを切り、その中に drawingKey.json を保存する
final class DrawingLocalStore {

    /// ストア操作時のエラー定義
    enum StoreError: Error {
        case invalidKey   // 空文字や不正なキー
        case notFound     // ファイルが存在しない
    }

    /// シングルトン（アプリ内で1つだけ使う想定）
    static let shared = DrawingLocalStore()
    private init() {}

    // MARK: - Paths

    /// Application Support/DrawingData を返す
    /// なければディレクトリを作成する
    private func baseDir() throws -> URL {
        let fm = FileManager.default

        // Application Support ディレクトリを取得（なければ作る）
        let dir = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        // Drawing データ専用のベースディレクトリ
        let base = dir.appendingPathComponent("DrawingData", isDirectory: true)

        // 中間ディレクトリ含めて作成（すでにあってもOK）
        try fm.createDirectory(at: base, withIntermediateDirectories: true, attributes: nil)

        // iCloud バックアップ対象外に設定（キャッシュ的用途想定）
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableBase = base
        try? mutableBase.setResourceValues(values)

        return base
    }

    /// ファイル名として安全な文字列に変換する
    /// - 空文字は禁止
    /// - 英数 + -_. 以外は "_" に置換
    private func sanitize(_ key: String) throws -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.invalidKey }

        // 許可する文字セット
        let allowed = CharacterSet.alphanumerics.union(
            CharacterSet(charactersIn: "-_.")
        )

        // 許可されていない文字は "_" に変換
        let mapped = trimmed.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "_"
        }

        // "__" が連続しないように整理
        var s = String(mapped)
        while s.contains("__") {
            s = s.replacingOccurrences(of: "__", with: "_")
        }

        // 先頭・末尾の "_" を除去（見た目安定用）
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        guard !s.isEmpty else { throw StoreError.invalidKey }
        return s
    }

    /// imageKey / drawingKey から保存先ファイルURLを生成する
    ///
    /// DrawingData/
    ///   └ imageKey/
    ///       └ drawingKey.json
    private func fileURL(imageKey: String, drawingKey: String) throws -> URL {
        let base = try baseDir()

        let img = try sanitize(imageKey)
        let draw = try sanitize(drawingKey)

        // imageKey ごとのディレクトリ
        let imgDir = base.appendingPathComponent(img, isDirectory: true)
        try FileManager.default.createDirectory(
            at: imgDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return imgDir.appendingPathComponent("\(draw).json")
    }

    // MARK: - Public API

    /// DrawingPackage を JSON として保存する
    func save(_ package: DrawingPackage) throws {
        let url = try fileURL(
            imageKey: package.imageKey,
            drawingKey: package.drawingKey
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(package)

        // atomic: 書き込み途中で落ちても壊れない
        try data.write(to: url, options: [.atomic])
    }

    /// 指定した imageKey / drawingKey の DrawingPackage を読み込む
    func load(imageKey: String, drawingKey: String) throws -> DrawingPackage {
        let url = try fileURL(imageKey: imageKey, drawingKey: drawingKey)

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw StoreError.notFound
        }

        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(DrawingPackage.self, from: data)
    }

    /// 指定 imageKey 配下に存在する drawingKey 一覧を返す
    func listDrawingKeys(imageKey: String) throws -> [String] {
        let base = try baseDir()
        let img = try sanitize(imageKey)
        let dir = base.appendingPathComponent(img, isDirectory: true)

        // ディレクトリがなければ空配列
        guard FileManager.default.fileExists(atPath: dir.path) else {
            return []
        }

        let urls = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }
}
