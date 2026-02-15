import Foundation
import YamatoAPIKit
import DrawingKit
import Combine
import UIKit

/// Operation画面の「データ層」
///
/// ここに置くもの（＝なぜここなのか）
/// - ネットワーク取得（リンクプロジェクト一覧 / サムネ / メモ / pipeList）
/// - entry画像の固定キャッシュ（画面中ずっと同じ画像を使う要件）
/// - pipeList を CanvasRect に変換し「全プロジェクト分を統合した結果」を作る
///
/// ここに置かないもの
/// - パネル表示状態・モード・選択状態などの「UI状態」
/// - タップやズームなど「ユーザー操作起点の状態遷移」
///
/// 理由：
/// - Viewから通信を剥がして、テスト・再利用・責務分離をしやすくするため
/// - StoreがUIルールを持ち、Modelがデータルールを持つため
@MainActor
final class OperationScreenModel: ObservableObject {

    // MARK: - External dependency

    /// APIアクセス等のサービス群（通信はここに集約）
    private let services: YamatoServices

    // MARK: - Fixed inputs (screen lifetime)

    /// entryプロジェクト（＝ユーザーが最初に開いたプロジェクト）
    let entryProjectID: String

    /// entryプロジェクトの「ユーザーが指定した画像URL」
    /// 画面中は固定で扱う（リンクプロジェクトを開いても entry画像は変わらない）
    let selectedImageURL: URL

    // MARK: - Output state (for UI)

    /// リンクプロジェクト一覧（thumb/memo等を含むView向けVM）
    @Published private(set) var projects: [ProjectVM] = []

    /// ✅ 要件：どのプロジェクトを開いていても全rectを参照できる
    /// 全プロジェクト分の pipeList を CanvasRect に変換し、統合した結果
    @Published private(set) var allRects: [CanvasRect] = []

    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Init

    init(services: YamatoServices, entryProjectID: String, selectedImageURL: URL) {
        self.services = services
        self.entryProjectID = entryProjectID
        self.selectedImageURL = selectedImageURL
    }

    // MARK: - Public API

    /// 画面復帰のたびに呼ぶ：リンクプロジェクト一覧を毎回最新化
    ///
    /// ルール：
    /// - entry画像は固定（selectedImageURLでロック＋キャッシュ）
    /// - entry以外の thumb/memo/pipeList は毎回ダウンロード（最新を優先）
    /// - pipeList は全件まとめて rect化して allRects に統合
    func refresh(currentProjectID: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // 1) 一覧は毎回最新版取得（リンク関係が変わる可能性があるため）
            let dtos = try await services.operation.fetchAllLinkProjects(projcet_id: currentProjectID)

            // 2) DTO -> VM（URL群はここで毎回 “最新” に更新）
            var next = dtos.map(ProjectVM.init(dto:))

            // 3) entry画像は固定（selectedImageURLから作り、キャッシュがあれば利用）
            let entryImage = try await lockedEntryImage()
            if let idx = next.firstIndex(where: { $0.id == entryProjectID }) {
                next[idx].loadedThumb = entryImage
            }

            // 4) entry以外の thumb/memo をダウンロードしてVMを enrich
            //    - 失敗しても一覧自体は出したいので、個別失敗は握り潰す
            next = await enrichProjects(next)

            // 5) pipeList -> CanvasRect 統合（全プロジェクト分）
            //    - 「どのプロジェクトを開いていても全rect参照」要件のため、ここで統合する
            let rects = await buildAllRects(from: next)

            // 6) state反映
            self.projects = next
            self.allRects = rects

        } catch {
            self.errorMessage = "リンクプロジェクト一覧の取得に失敗しました: \(error)"
        }
    }

    // MARK: - Entry image lock (cache)

    /// entry画像は画面中ずっと固定
    /// - 画面復帰のたびに同じ画像を再DLしないためキャッシュする
    /// - entryProjectID をキーに保持
    func lockedEntryImage() async throws -> LoadedImage {
        if let cached = ImageCache.shared.entryImage(for: entryProjectID) {
            return cached
        }
        let img = try await LoadedImage(url: selectedImageURL)
        ImageCache.shared.setEntryImage(img, for: entryProjectID)
        return img
    }

    // MARK: - Enrich (thumb / memo)

    /// entry以外の thumb/memo を取得して ProjectVM を更新する
    ///
    /// なぜここ？
    /// - 「データを揃える」処理なのでModel側が持つ（Storeに置くとUI責務と混ざりやすい）
    private func enrichProjects(_ projects: [ProjectVM]) async -> [ProjectVM] {
        var next = projects

        // NOTE:
        // thumb/memo を全部同時並列にするとネットワークが細い環境で詰まりやすいので、
        // ここでは段階的（thumb → memo）にしている。
        next = await downloadThumbs(projects: next)
        next = await downloadMemos(projects: next)
        return next
    }

    private func downloadThumbs(projects: [ProjectVM]) async -> [ProjectVM] {
        var next = projects

        await withTaskGroup(of: (Int, LoadedImage?).self) { group in
            for i in next.indices {
                // entryは固定なのでスキップ
                if next[i].id == entryProjectID { continue }
                guard let url = next[i].thumbnailURL else { continue }

                group.addTask {
                    do {
                        let img = try await LoadedImage(url: url)
                        return (i, img)
                    } catch {
                        return (i, nil)
                    }
                }
            }

            for await (i, img) in group {
                next[i].loadedThumb = img
            }
        }

        return next
    }

    private func downloadMemos(projects: [ProjectVM]) async -> [ProjectVM] {
        var next = projects

        await withTaskGroup(of: (Int, String?).self) { group in
            for i in next.indices {
                guard let url = next[i].memoURL else { continue }

                // TaskGroup内はSendable制約があるので、必要な値だけコピーして渡す
                let pid = next[i].id
                let pname = next[i].name

                group.addTask {
                    do {
                        let text = try await self.downloadText(
                            url: url,
                            projectID: pid,
                            projectName: pname
                        )
                        return (i, text)
                    } catch {
                        return (i, nil)
                    }
                }
            }

            for await (i, text) in group {
                next[i].memoText = text
            }
        }

        return next
    }

    // MARK: - Rect unify (pipeList -> CanvasRect)

    /// pipeListURL を全プロジェクト分DL → rect化 → 1配列に統合
    ///
    /// なぜここ？
    /// - これは「データの統合結果」を作る処理で、UI状態とは独立
    /// - Storeが「どれを表示するか」を決め、Modelが「全件を作る」
    private func buildAllRects(from projects: [ProjectVM]) async -> [CanvasRect] {
        typealias PipeListResult = (projectID: String, projectName: String, items: [PipeItemDTO])

        var merged: [CanvasRect] = []
        merged.reserveCapacity(projects.count * 50)

        await withTaskGroup(of: PipeListResult.self) { group in
            for p in projects {
                guard let url = p.pipeListURL else { continue }

                // ✅ TaskGroupへ渡すのはSendableな値だけ（id/name/URL）
                let pid = p.id
                let pname = p.name

                group.addTask { [url] in
                    do {
                        let resp = try await self.downloadPipeList(url: url)
                        return (pid, pname, resp.pipeList)
                    } catch {
                        // 失敗は握り潰す：一覧UIを壊さない
                        return (pid, pname, [])
                    }
                }
            }

            // CanvasRect化はMainActor側で（DrawingKitの型をTask内で弄らない方が安全）
            for await r in group {
                let rects = PipeListMapper.toCanvasRects(
                    r.items,
                    projectID: r.projectID,
                    projectName: r.projectName
                )
                merged.append(contentsOf: rects)
            }
        }

        return merged
    }

    // MARK: - Networking utilities

    /// メモ（テキスト）を取得
    /// - Dummy URL を扱う都合でModelに置く（View/Store側に分散させない）
    private func downloadText(url: URL, projectID: String? = nil, projectName: String? = nil) async throws -> String {

        // ダミーメモ対応（UIプレビュー/オフライン動作確認用）
        if url.scheme == "app", url.host == "dummy" {
            return DummyMemoFactory.makeText(
                projectID: projectID ?? "UNKNOWN",
                projectName: projectName ?? "不明プロジェクト"
            )
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        let (data, resp) = try await URLSession.shared.data(for: req)

        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    /// pipeList（JSON）を取得してDTOにデコード
    private func downloadPipeList(url: URL) async throws -> PipeListResponseDTO {

        // ダミーURL対応（UI確認用）
        if url.scheme == "app", url.host == "dummy" {
            let data = try DummyPipeListFactory.makeJSONData(
                count: 10,
                rectSize: CGSize(width: 36, height: 28)
            )
            return try Self.pipeListDecoder.decode(PipeListResponseDTO.self, from: data)
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        let (data, resp) = try await URLSession.shared.data(for: req)

        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try Self.pipeListDecoder.decode(PipeListResponseDTO.self, from: data)
    }

    /// pipeListのDate形式が揺れる（fractional seconds有無）ため専用decoderを固定で持つ
    /// - 毎回生成すると無駄なのでstaticにする
    private static let pipeListDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let c = try d.singleValueContainer()
            let s = try c.decode(String.self)

            let f1 = ISO8601DateFormatter()
            f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let dt = f1.date(from: s) { return dt }

            let f2 = ISO8601DateFormatter()
            f2.formatOptions = [.withInternetDateTime]
            if let dt = f2.date(from: s) { return dt }

            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid date: \(s)")
        }
        return decoder
    }()
}
