import Foundation
import Combine

@MainActor
public final class OperationConfigStore: ObservableObject {

    public static let shared = OperationConfigStore()

    @Published private(set) var config: OperationConfig = .default

    private init() {
        load()
    }

    // MARK: - Public API

    func update(_ newValue: OperationConfig) {
        config = newValue
        save()
    }

    func resetToDefault() {
        config = .default
        save()
    }

    // MARK: - Persistence

    private var fileURL: URL {
        let fm = FileManager.default
        let dir = (try? fm.url(for: .applicationSupportDirectory,
                               in: .userDomainMask,
                               appropriateFor: nil,
                               create: true)) ?? fm.temporaryDirectory

        let base = dir.appendingPathComponent("Config", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = base
        try? mutable.setResourceValues(values)

        return base.appendingPathComponent("operation_config.json")
    }

    private func load() {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            config = .default
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(OperationConfig.self, from: data)
            config = decoded
        } catch {
            // 壊れてても UI を壊さない
            config = .default
        }
    }

    private func save() {
        let url = fileURL
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(config)
            try data.write(to: url, options: [.atomic])
        } catch {
            // 失敗しても無視（UI継続）
        }
    }
}
