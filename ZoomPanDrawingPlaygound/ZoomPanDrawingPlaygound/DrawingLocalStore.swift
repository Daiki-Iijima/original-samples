import Foundation

final class DrawingLocalStore {
    enum StoreError: Error { case invalidKey, notFound }

    static let shared = DrawingLocalStore()
    private init() {}

    private func baseDir() throws -> URL {
        let fm = FileManager.default
        let dir = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let base = dir.appendingPathComponent("DrawingData", isDirectory: true)
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private func sanitize(_ key: String) throws -> String {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.invalidKey }
        return trimmed.replacingOccurrences(of: "/", with: "_")
    }

    private func fileURL(imageKey: String, drawingKey: String) throws -> URL {
        let base = try baseDir()
        let img = try sanitize(imageKey)
        let draw = try sanitize(drawingKey)

        let imgDir = base.appendingPathComponent(img, isDirectory: true)
        try FileManager.default.createDirectory(at: imgDir, withIntermediateDirectories: true)

        return imgDir.appendingPathComponent("\(draw).json", isDirectory: false)
    }

    func save(_ package: DrawingPackage) throws {
        let url = try fileURL(imageKey: package.imageKey, drawingKey: package.drawingKey)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(package)
        try data.write(to: url, options: [.atomic])
    }

    func load(imageKey: String, drawingKey: String) throws -> DrawingPackage {
        let url = try fileURL(imageKey: imageKey, drawingKey: drawingKey)
        guard FileManager.default.fileExists(atPath: url.path) else { throw StoreError.notFound }

        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(DrawingPackage.self, from: data)
    }

    func listDrawingKeys(imageKey: String) throws -> [String] {
        let base = try baseDir()
        let img = try sanitize(imageKey)
        let dir = base.appendingPathComponent(img, isDirectory: true)

        guard FileManager.default.fileExists(atPath: dir.path) else { return [] }

        let urls = try FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)
        return
            urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }
}
