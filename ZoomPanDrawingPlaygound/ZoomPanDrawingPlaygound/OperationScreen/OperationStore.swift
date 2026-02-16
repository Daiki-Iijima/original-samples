import SwiftUI
import DrawingKit
import YamatoAPIKit
import YamatoAppContracts
import UIKit
import Combine


/// Operation画面全体の状態を保持し、状態遷移ルールを持つ（＝Store）
///
/// なぜ ViewModel ではなく Store？
/// - OperationScreen は「複数パネル」「描画キャンバス」「選択状態」「ズーム状態」など
///   1画面の中に複数View相当の状態を同時に扱う
/// - “単一ViewのためのViewModel” より “画面全体の状態ストア” の方が責務が明確
///
/// 役割：
/// - UI状態（モード / 選択 / パネル / ズーム）を @Published で保持
/// - Model（データ層）を呼び、結果をUI表示用に整形して反映
/// - 「表示用Overlay（青=チェック済み + 未確認=現在プロジェクトのみ）」の合成を提供
///
/// 置かないもの：
/// - URLSession等の通信実装（それはModel）
/// - SwiftUIのレイアウト（それはView）
@MainActor
final class OperationStore: ObservableObject {
    
    // MARK: - External / fixed
    
    let services: YamatoServices
    let payload: ProjectOpenPayload
    let selectedImageURL: URL
    
    /// データ層（取得・統合・キャッシュ）
    let model: OperationScreenModel
    
    // MARK: - Published (Viewが直接監視する状態)
    
    // 現在表示対象のプロジェクト（未確認パネルで切替される）
    @Published var currentProjectID: String? = nil
    
    // モードと描画設定（UI操作で切り替わる）
    @Published var interactionMode: InteractionMode = .normal
    @Published var drawingSettings: DrawingSettings = .init()
    
    // entry画像（画面中固定）
    @Published var currentLoadedImage: LoadedImage = .initial
    
    // ズームパン（キャンバス層が参照）
    @Published var viewportState: ViewportState = .initial
    @Published var zoomRequest: ZoomRequest = .none
    
    //  ダウンロードしてきた全部材データ
    @Published var allPipeRects: [CanvasRect] = []
    //  未確認部材やチェックバック対象の部材データ(表示用)
    @Published var renderingRects: [CanvasRect] = []
    
    // 未確認パネルでの選択状態（Rectを選択/解除）
    @Published public var selectedRectIDs: Set<UUID> = []
    
    // Panels (shared)
    @Published var presentedPanel: PanelRoute? = nil
    
    @Published var isMemoVisible: Bool = false
    @Published var isLinkProjectsVisible: Bool = false
    @Published var isDrawingSettingsPanelVisible: Bool = true
    @Published var isUnconfirmedPartsVisible: Bool = false
    
    @Published var memoText: String = ""
    
    // iPad floating positions（“UIの配置”だが、複数ビュー跨ぎで共有するため Store 管理）
    @Published var panelPos: CGPoint = CGPoint(x: 9999, y: 9999)
    @Published var didInitPanelPos: Bool = false
    
    @Published var unconfirmedPartsPanelPos: CGPoint = CGPoint(x: 9999, y: 9999)
    @Published var didInitUnconfirmedPartsPanelPos: Bool = false
    
    @Published var memoPanelPos: CGPoint = CGPoint(x: 9999, y: 9999)
    @Published var didInitMemoPanelPos: Bool = false
    
    @Published var linkProjectsPos: CGPoint = CGPoint(x: 9999, y: 9999)
    @Published var didInitLinkProjectsPanelPos: Bool = false
    
    // Loading（画面起動シーケンス）
    @Published var isBooting: Bool = false
    
    // iOS16 old/new workaround（以前ViewにあったものをStoreへ移す）
    @Published var lastInteractionMode: InteractionMode = .normal
    
    //  設定
    @Published var config: OperationConfig = .default
    private var cancellables: Set<AnyCancellable> = []
    
    // =========================================================
    // MARK: - Scanner(Pipe) mode state
    // =========================================================
    
    /// スキャナから戻ってきた結果（ドメイン）
    @Published var collectedPipes: [ScanItem] = []
    /// いま「ScanItemモードでパネル表示中」か（0件なら false ）
    @Published var isPipeListMode: Bool = false
    /// checkback送信中のID（pipeCheckID）
    @Published var checkingPipeIDs: Set<String> = []
    /// 全体送信中（ボタン連打防止）
    @Published var isCheckingBack: Bool = false
    /// エラー表示用
    @Published var lastErrorMessage: String? = nil
    /// 今回のスキャン結果に含まれる pipeCheckID（パネルに残したい対象）
    @Published var currentScanPipeIDs: Set<String> = []
    @Published var scanPanelRects: [CanvasRect] = []



    // MARK: - Init
    
    init(
        services: YamatoServices,
        payload: ProjectOpenPayload,
        selectedImageURL: URL
    ) {
        self.services = services
        self.payload = payload
        self.selectedImageURL = selectedImageURL
        self.model = OperationScreenModel(
            services: services,
            entryProjectID: payload.project.id,
            selectedImageURL: selectedImageURL
        )
        // config 変更を Store に取り込む（UI更新トリガーにする）
        OperationConfigStore.shared.$config
            .sink { [weak self] v in
                self?.config = v
            }
            .store(in: &cancellables)
        
    }
    
    // MARK: - Boot / Refresh
    
    /// 画面初回表示時に1回呼ぶ想定
    ///
    /// なぜStoreがやる？
    /// - “起動時に何をどの順で揃えるか” はUIの流れ（画面の状態遷移）なのでStore
    func boot() async {
        isBooting = true
        defer { isBooting = false }
        
        // 1) entry を最初に開く（起動直後の表示先）
        let entryID = payload.project.id
        currentProjectID = entryID
        
        // 2) entry画像ロック（画面中固定）
        do {
            currentLoadedImage = try await model.lockedEntryImage()
        } catch {
            // ここはUIを壊さず初期状態に落とす
            print("[ERROR] entry画像ダウンロード失敗:", error)
            currentLoadedImage = .initial
        }
        
        // 3) リンクプロジェクト一覧＋rect統合を更新
        await refreshProjectsIfNeeded()
        
        // 4) 全rectを“元データ”として保持
        allPipeRects = model.allRects
        
        //  表示用データとして設定
        renderingRects = allPipeRects
    }
    
    /// 画面復帰やプロジェクト切替のタイミングで呼ぶ
    func refreshProjectsIfNeeded() async {
        let fallback = payload.project.id
        let currentID = currentProjectID ?? fallback
        
        await model.refresh(currentProjectID: currentID)
        
        // Modelが「全件統合」を作る → Storeは「UI用元データ」として受け取る
        allPipeRects = model.allRects
        
        renderingRects = allPipeRects
    }
    
    // MARK: - Panel / Mode
    
    /// 未確認パネル表示切替
    /// - 非表示にする時は選択状態もクリア（UI整合性）
    func setUnconfirmedPartsVisible(_ visible: Bool) {
        isUnconfirmedPartsVisible = visible
        if !visible { selectedRectIDs.removeAll() }
    }
    
    /// モード切替時のパネル制御（状態遷移ルール）
    func closePanelsForModeSwitch(from old: InteractionMode, to new: InteractionMode) {
        // “モードが変わったら一旦パネルを閉じる” というUIルールを一箇所に集約
        isUnconfirmedPartsVisible = false
        isMemoVisible = false
        isLinkProjectsVisible = false
        isDrawingSettingsPanelVisible = false
        presentedPanel = nil
    }
    
    // MARK: - Project open (from panels / tap)
    
    /// パネルからプロジェクトを開く（必要ならズームも同時に行う）
    @MainActor
    func openProject(projectID: String, zoomRect: CanvasRect?) {
        currentProjectID = projectID
        
        Task { [weak self] in
            guard let self else { return }
            
            // entry はユーザー選択画像（固定）
            if projectID == payload.project.id {
                self.currentLoadedImage = (try? await self.model.lockedEntryImage()) ?? .initial
            } else {
                // それ以外は「サムネ」
                if let vm = self.model.projects.first(where: { $0.id == projectID }) {
                    if let thumb = vm.loadedThumb {
                        self.currentLoadedImage = thumb
                    } else if let url = vm.thumbnailURL {
                        // 万一まだ落ちてなければここで落とす（保険）
                        self.currentLoadedImage = (try? await LoadedImage(url: url)) ?? .initial
                    } else {
                        self.currentLoadedImage = .initial
                    }
                }
            }
            
            // ズームして表示する場合
            if let rect = zoomRect {
                let c = CGPoint(x: rect.rect.midX, y: rect.rect.midY)
                self.zoomRequest = .set(scale: max(self.viewportState.scale, 2.0), centerInImage: c)
            }
        }
    }
    
    // MARK: - Canvas tap logic (選択トグル)
    
    /// キャンバスをタップしたときの選択ルール
    ///
    /// なぜStore？
    /// - タップ→選択トグルは「状態遷移ルール」なのでStoreが持つ
    func handleTapOnCanvas(at imagePoint: CGPoint) {
        guard isUnconfirmedPartsVisible else { return }
        
        // ✅ 表示用rectから「タップ対象」を作る（= 表示と判定を一致させる）
        let tappable = makeDisplayOverlayRects()
            .filter { !$0.isHidden && !$0.isChecked }   // 未確認だけタップ可能
        
        guard let hit = tappable.reversed().first(where: { $0.rect.contains(imagePoint) }) else {
            return
        }
        
        // ✅ ここはもう “別プロジェクトがヒットする” こと自体が起きない
        // （makeDisplayOverlayRects が currentProject 分だけ返すから）
        
        if selectedRectIDs.contains(hit.id) {
            selectedRectIDs.remove(hit.id)
        } else {
            selectedRectIDs.insert(hit.id)
        }
    }
    
    // MARK: - Overlay composition (canvasへ渡す用)
    
    /// canvas.setOverlayRects に渡す “表示用Rect” を作る
    ///
    /// 表示ルール：
    /// 1) チェック済みは常時表示（青）
    /// 2) 未確認部材一覧ONの時だけ、未チェックを表示
    ///    - ただし “現在選択中プロジェクト分だけ” 表示（見た目が散らからないため）
    func makeDisplayOverlayRects() -> [CanvasRect] {
        
        let cfg = config
        
        // 1) チェック済み：常時表示
        let checkedAll: [CanvasRect] = renderingRects
            .filter { !$0.isHidden && $0.isChecked }
            .map { r in
                var s = r.style
                
                // stroke/fill
                s.strokeColor = cfg.checked.strokeColor.uiColor(alpha: cfg.checked.strokeAlpha)
                s.strokeWidth = CGFloat(cfg.checked.strokeWidth)
                s.fill = cfg.checked.fillEnabled
                ? .solid(cfg.checked.fillColor.uiColor(alpha: cfg.checked.fillAlpha))
                : .none
                
                s.textColor = cfg.checked.textColor.uiColor(alpha: cfg.checked.textAlpha)
                
                return r.with(style: s)
            }
        
        // 2) 未確認：一覧ONの時だけ現在プロジェクト分
        let unconfirmedInCurrentProject: [CanvasRect] = {
            guard isUnconfirmedPartsVisible else { return [] }
            let unconfirmed = renderingRects.filter { !$0.isHidden && !$0.isChecked }
            guard let pid = currentProjectID else { return [] }
            
            return unconfirmed
                .filter { $0.projectID == pid }
                .map { r in
                    var s = r.style
                    s.strokeColor = cfg.unconfirmed.strokeColor.uiColor(alpha: cfg.unconfirmed.strokeAlpha)
                    s.strokeWidth = CGFloat(cfg.unconfirmed.strokeWidth)
                    s.fill = cfg.unconfirmed.fillEnabled
                    ? .solid(cfg.unconfirmed.fillColor.uiColor(alpha: cfg.unconfirmed.fillAlpha))
                    : .none
                    
                    s.textColor = cfg.unconfirmed.textColor.uiColor(alpha: cfg.unconfirmed.textAlpha)
                    
                    return r.with(style: s)
                }
        }()
        
        // 3) 選択中（最優先）
        func applySelectedStyle(_ rects: [CanvasRect]) -> [CanvasRect] {
            rects.map { r in
                guard selectedRectIDs.contains(r.id) else { return r }
                var s = r.style
                
                s.strokeColor = cfg.selection.strokeColor.uiColor(alpha: cfg.selection.strokeAlpha)
                s.strokeWidth = CGFloat(cfg.selection.strokeWidth)
                s.fill = cfg.selection.fillEnabled
                ? .solid(cfg.selection.fillColor.uiColor(alpha: cfg.selection.fillAlpha))
                : .none
                
                s.textColor = cfg.selection.textColor.uiColor(alpha: cfg.selection.textAlpha)
                
                return r.with(style: s)
            }
        }
        
        return applySelectedStyle(checkedAll) + applySelectedStyle(unconfirmedInCurrentProject)
    }
    
    // =========================================================
    // MARK: - Scanner -> Store integration
    // =========================================================
    
    /// スキャナから戻ってきた ScanItem を受け取る
    /// - ✅ 0件なら「何も開かない」＝通常モードのまま
    /// - ✅ 1件でもあれば「ScanItemモードでパネルを開く」
    func acceptCollectedPipes(_ items: [ScanItem]) {
        guard !items.isEmpty else {
            collectedPipes = []
            isPipeListMode = false
            checkingPipeIDs.removeAll()
            isCheckingBack = false
            lastErrorMessage = nil
            currentScanPipeIDs.removeAll()
            scanPanelRects = []
            return
        }

        currentScanPipeIDs = Set(items.flatMap { $0.results.map(\.pipeCheckID) })

        collectedPipes = items
        isPipeListMode = true
        lastErrorMessage = nil

        // パネル用：今回分だけ（downloadedのチェック済みを混ぜない）
        scanPanelRects = makeScanOnlyRects(from: items, mergingWith: allPipeRects)

        // overlay用：必要なら従来通り（混ぜてもOK）
        renderingRects = makePanelRects(from: items, mergingWith: allPipeRects)

        applyCollectedPipesToOverlayRects()

        isUnconfirmedPartsVisible = true
        selectedRectIDs.removeAll()
    }
    
    private func makeScanOnlyRects(from items: [ScanItem], mergingWith downloaded: [CanvasRect]) -> [CanvasRect] {
        var downloadedByKey: [String: CanvasRect] = [:]
        downloadedByKey.reserveCapacity(downloaded.count)

        for r in downloaded {
            guard !r.projectID.isEmpty, let pid = r.pipeCheckBackID, !pid.isEmpty else { continue }
            downloadedByKey["\(r.projectID)|\(pid)"] = r
        }

        var out: [CanvasRect] = []
        out.reserveCapacity(items.reduce(0) { $0 + $1.results.count })

        var usedKeys = Set<String>()

        for item in items {
            for entry in item.results {
                let key = "\(entry.projectID)|\(entry.pipeCheckID)"
                guard usedKeys.insert(key).inserted else { continue } // ✅重複排除

                let base = downloadedByKey[key]

                let rect = base?.rect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
                let style = base?.style ?? .initial
                let isHidden = base?.isHidden ?? false

                let pname =
                    base?.projectName
                    ?? model.projects.first(where: { $0.id == entry.projectID })?.name
                    ?? entry.projectID

                var r = CanvasRect(
                    id: StableUUID.make(entry.pipeCheckID),
                    externalID: entry.pipeCheckID,
                    name: entry.pipeName,
                    projectID: entry.projectID,
                    projectName: pname,
                    isChecked: entry.checkbacked,
                    isHidden: isHidden,
                    rect: rect,
                    style: style
                )
                r.name = "\(entry.pipeName) (\(item.value))"
                out.append(r)
            }
        }

        out.sort {
            if $0.projectID != $1.projectID { return $0.projectID < $1.projectID }
            return ($0.pipeCheckBackID ?? $0.name) < ($1.pipeCheckBackID ?? $1.name)
        }
        return out
    }


    /// ScanItem -> CanvasRect（確認済みも消さずに全部出す）
    /// ScanItem -> CanvasRect（pipeCheckIDでoverlayRectsとマージしてrectを埋める）
    private func makePanelRects(from items: [ScanItem], mergingWith downloaded: [CanvasRect]) -> [CanvasRect] {

        // downloaded: projectID|pipeCheckID -> rect
        var downloadedByKey: [String: CanvasRect] = [:]
        downloadedByKey.reserveCapacity(downloaded.count)

        for r in downloaded {
            guard !r.projectID.isEmpty,
                  let pid = r.pipeCheckBackID, !pid.isEmpty
            else { continue }
            downloadedByKey["\(r.projectID)|\(pid)"] = r
        }

        var out: [CanvasRect] = []
        out.reserveCapacity(items.reduce(0) { $0 + $1.results.count })

        // ✅重複防止用：スキャン由来で既に追加したkey
        var usedKeys = Set<String>()
        usedKeys.reserveCapacity(out.capacity)

        // 1) ScanItem.results -> CanvasRect（downloadedとマージ）
        for item in items {
            for entry in item.results {

                let key = "\(entry.projectID)|\(entry.pipeCheckID)"
                usedKeys.insert(key)

                let base = downloadedByKey[key]

                let rect = base?.rect ?? CGRect(x: 0, y: 0, width: 1, height: 1)
                let style = base?.style ?? .initial
                let isHidden = base?.isHidden ?? false

                let pname =
                    base?.projectName
                    ?? model.projects.first(where: { $0.id == entry.projectID })?.name
                    ?? entry.projectID

                var r = CanvasRect(
                    id: StableUUID.make(entry.pipeCheckID),
                    externalID: entry.pipeCheckID,
                    name: entry.pipeName,
                    projectID: entry.projectID,
                    projectName: pname,
                    isChecked: entry.checkbacked,
                    isHidden: isHidden,
                    rect: rect,
                    style: style
                )

                // item.value を出したいなら
                r.name = "\(entry.pipeName) (\(item.value))"

                out.append(r)
            }
        }

        // 2) downloaded側の「チェックバック済み」を全部追加（スキャンで既に入ってるものは除外）
        for base in downloaded {
            guard !base.projectID.isEmpty,
                  let pid = base.pipeCheckBackID, !pid.isEmpty
            else { continue }

            let key = "\(base.projectID)|\(pid)"
            guard !usedKeys.contains(key) else { continue }   // 重複防止
            guard base.isChecked else { continue }            // チェック済みだけ追加
            guard !base.isHidden else { continue }            // 好み：非表示は除外

            // baseは既にrect/styleを持ってるのでそのまま追加でOK
            out.append(base)
            usedKeys.insert(key)
        }

        out.sort {
            if $0.projectID != $1.projectID { return $0.projectID < $1.projectID }
            return ($0.pipeCheckBackID ?? $0.name) < ($1.pipeCheckBackID ?? $1.name)
        }

        return out
    }

    /// 選択中の項目をチェックバックして、結果をリストに反映
    func checkBackSelectedPipes() async {
        guard isPipeListMode else { return }
        guard !isCheckingBack else { return }

        let selected = renderingRects.filter { selectedRectIDs.contains($0.id) }

        let ids = Array(
            Set(selected.compactMap(\.pipeCheckBackID).filter { !$0.isEmpty })
        ).sorted()

        guard !ids.isEmpty else { return }

        isCheckingBack = true
        lastErrorMessage = nil
        checkingPipeIDs.formUnion(ids)

        defer {
            isCheckingBack = false
            checkingPipeIDs.subtract(ids)
        }

        do {
            let backs: [PipeCheckBackResult] = try await services.pipeCheck.checkBack(ids: ids)

            let succeededIDs = Set(backs.filter { $0.checkbacked }.map(\.pipeCheckID))
            markChecked(pipeCheckIDs: succeededIDs)

            for i in collectedPipes.indices {
                collectedPipes[i].mergeCheckBack(backs)
            }

            selectedRectIDs.removeAll()
        } catch {
            lastErrorMessage = "\(error)"
        }
    }
    
    /// パネル（チェックバック一覧）に出す行
    var checkbackPanelRects: [CanvasRect] {
        scanPanelRects
    }

    private func markChecked(pipeCheckIDs: Set<String>) {
        guard !pipeCheckIDs.isEmpty else { return }

        func updated(_ src: [CanvasRect]) -> (next: [CanvasRect], changed: Bool) {
            var next = src
            var changed = false
            for i in next.indices {
                guard let id = next[i].pipeCheckBackID, pipeCheckIDs.contains(id) else { continue }
                if next[i].isChecked == false {
                    next[i].isChecked = true
                    changed = true
                }
            }
            return (next, changed)
        }

        let a = updated(allPipeRects)
        if a.changed { allPipeRects = a.next }

        let b = updated(renderingRects)
        if b.changed { renderingRects = b.next }

        let c = updated(scanPanelRects)
        if c.changed { scanPanelRects = c.next }
    }


    /// collectedPipes の checkback 状態を overlayRects に反映する
    private func applyCollectedPipesToOverlayRects() {
        guard !collectedPipes.isEmpty else { return }
        
        // projectID|pipeCheckID -> checkbacked
        var dict: [String: Bool] = [:]
        dict.reserveCapacity(collectedPipes.reduce(0) { $0 + $1.results.count })
        
        for item in collectedPipes {
            for e in item.results {
                dict["\(e.projectID)|\(e.pipeCheckID)"] = e.checkbacked
            }
        }
        
        var changed = false
        var next = allPipeRects
        
        for i in next.indices {
            guard !next[i].projectID.isEmpty,
                  let pipeID = next[i].pipeCheckBackID, !pipeID.isEmpty
            else { continue }
            
            let key = "\(next[i].projectID)|\(pipeID)"
            guard let cb = dict[key] else { continue }
            
            if next[i].isChecked != cb {
                next[i].isChecked = cb
                changed = true
            }
        }
        
        if changed { allPipeRects = next }
    }
}

// MARK: - Small helper
private extension CanvasRect {
    func with(style: CanvasRectStyle) -> CanvasRect {
        CanvasRect(
            id: id,
            externalID: pipeCheckBackID,
            name: name,
            projectID: projectID,
            projectName: projectName,
            isChecked: isChecked,
            isHidden: isHidden,
            rect: rect,
            style: style
        )
    }
}

//  MARK: - LinkProject用ヘルパー

extension OperationStore{
    /// LinkProjectsPanelView に渡す表示用アイテム
    var linkProjectItems: [LinkProjectItem] {
        model.projects.map { p in
            LinkProjectItem(id: p.id, name: p.name)
        }
    }
}

//  MARK: - CanvasRectのデザインをユーザー設定から読み込む
private func style(from s: OperationConfig.SelectionStyle) -> CanvasRectStyle {
    CanvasRectStyle(
        strokeColor: s.strokeColor.uiColor,
        strokeWidth: CGFloat(s.strokeWidth),
        fill: s.fillEnabled
        ? .solid(s.fillColor.uiColor.withAlphaComponent(CGFloat(s.fillAlpha)))
        : .none
    )
}

private func style(from s: OperationConfig.CheckedStyle) -> CanvasRectStyle {
    CanvasRectStyle(
        strokeColor: s.strokeColor.uiColor.withAlphaComponent(CGFloat(s.strokeAlpha)),
        strokeWidth: CGFloat(s.strokeWidth),
        fill: s.fillEnabled
        ? .solid(s.fillColor.uiColor.withAlphaComponent(CGFloat(s.fillAlpha)))
        : .none
    )
}

private func style(from s: OperationConfig.UnconfirmedStyle) -> CanvasRectStyle {
    CanvasRectStyle(
        strokeColor: s.strokeColor.uiColor.withAlphaComponent(CGFloat(s.strokeAlpha)),
        strokeWidth: CGFloat(s.strokeWidth),
        fill: s.fillEnabled
        ? .solid(s.fillColor.uiColor.withAlphaComponent(CGFloat(s.fillAlpha)))
        : .none
    )
}


extension OperationStore {

    /// チェックバック専用画面として起動するための入口
    func enterCheckbackOnlyMode(items: [ScanItem]) {
        // 通常のモード切替UIを使わない前提なら固定化
        interactionMode = .normal
        lastInteractionMode = .normal

        // 余計なパネルは閉じる
        isMemoVisible = false
        isLinkProjectsVisible = false
        isDrawingSettingsPanelVisible = false

        // ここが本体：ScanItemモードに入れて「未確認部材一覧」を開く
        acceptCollectedPipes(items)

        // acceptCollectedPipes 内で
        // presentedPanel = .unconfirmedParts
        // isUnconfirmedPartsVisible = true
        // selectedRectIDs.removeAll()
        // までやってくれてるので、ここはそれ以上いらない
    }
}
