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

    // Overlayの“元データ”（全プロジェクト分）
    @Published var overlayRects: [CanvasRect] = []

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
        overlayRects = model.allRects
    }

    /// 画面復帰やプロジェクト切替のタイミングで呼ぶ
    func refreshProjectsIfNeeded() async {
        let fallback = payload.project.id
        let currentID = currentProjectID ?? fallback

        await model.refresh(currentProjectID: currentID)

        // Modelが「全件統合」を作る → Storeは「UI用元データ」として受け取る
        overlayRects = model.allRects
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
       
        //  ユーザー設定を読み込み
        let checkedStyle = style(from: config.checked)
        let unconfirmedStyle = style(from: config.unconfirmed)
        let selectedStyle = style(from: config.selection)
        
        // 1) チェック済み
        let checkedAll: [CanvasRect] = overlayRects
            .filter { !$0.isHidden && $0.isChecked }
            .map { r in
                var rr = r
                rr = rr.with(style: checkedStyle)
                return rr
            }

        // 2) 未確認：一覧ONの時だけ、現在プロジェクト分のみ（黄色系）
        let unconfirmedInCurrentProject: [CanvasRect]
        if isUnconfirmedPartsVisible, let pid = currentProjectID {
            unconfirmedInCurrentProject = overlayRects
                .filter { !$0.isHidden && !$0.isChecked && $0.projectID == pid }
                .map { $0.with(style: unconfirmedStyle) }
        } else {
            unconfirmedInCurrentProject = []
        }
        // 3) 選択中の強調（最優先で上書き）
        func applySelected(_ rects: [CanvasRect]) -> [CanvasRect] {
            rects.map { r in
                guard selectedRectIDs.contains(r.id) else { return r }
                return r.with(style: selectedStyle)
            }
        }

        return applySelected(checkedAll) + applySelected(unconfirmedInCurrentProject)
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

