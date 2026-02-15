import DrawingKit
import SwiftUI
import UIKit
import Foundation
import YamatoAppContracts

extension OperationScreen {

    // MARK: - Boot

    /// 画面起動時の初期ロード
    /// - entry を currentProject に設定
    /// - entry画像をロック（selectedImageURL は固定）
    /// - link projects / rects を最新化
    @MainActor
    func boot() async {
        store.isBooting = true
        defer { store.isBooting = false }

        // entry を最初に開く
        let entryID = payload.project.id
        store.currentProjectID = entryID

        // entry画像ロック（selectedImageURL）
        do {
            store.currentLoadedImage = try await store.model.lockedEntryImage()
        } catch {
            print("[ERROR] entry画像ダウンロード失敗: \(error)")
            store.currentLoadedImage = .initial
        }

        // プロジェクト一覧＋rect統合を更新
        await refreshProjectsIfNeeded()

        // Rect反映（model -> store -> canvas）
        store.overlayRects = store.model.allRects
        syncOverlayRects()
    }

    /// scenePhase .active 復帰などで呼ぶ想定
    /// - model.refresh で link projects と rects を更新
    /// - store.overlayRects に反映して canvas の overlay を更新
    @MainActor
    func refreshProjectsIfNeeded() async {
        let fallback = payload.project.id
        let currentID = store.currentProjectID ?? fallback

        await store.model.refresh(currentProjectID: currentID)

        // ✅ Viewではなく Store に集約
        store.overlayRects = store.model.allRects
        syncOverlayRects()
    }

    // MARK: - Panel / Mode

    /// 未確認部材パネルの表示切り替え
    /// - OFFにしたら選択状態をクリア（誤選択防止）
    /// - overlay の見た目も即時更新
    func setUnconfirmedPartsVisible(_ visible: Bool) {
        store.isUnconfirmedPartsVisible = visible
        if !visible {
            store.selectedRectIDs.removeAll()
        }
        syncOverlayRects()
    }

    /// モード切り替え時の「パネル強制クローズ」ルール
    /// - 描画/通常/カメラなどモードが変わると、古いパネル状態が残ると事故るので閉じる
    func closePanelsForModeSwitch(from old: InteractionMode, to new: InteractionMode) {
        store.isUnconfirmedPartsVisible = false
        store.isMemoVisible = false
        store.isLinkProjectsVisible = false
        store.isDrawingSettingsPanelVisible = false
        store.presentedPanel = nil
    }

    // MARK: - Open Project

    /// Rectタップ / リンクプロジェクト選択などでプロジェクトを開く
    /// - currentProject を切り替え
    /// - 必要ならそのRectへズーム要求を投げる（ZoomableDrawingRepresentable が処理）
    func openProject(projectID: String, zoomRect: CanvasRect?) {
        store.openProject(projectID: projectID, zoomRect: zoomRect)
        
        syncOverlayRects()
    }

    // MARK: - Export / Local persistence

    /// iPhone フォトに「元画像 + お絵描き」をマージして保存
    func saveMergedToPhotos(currentLoadedImage: LoadedImage) {
        guard let canvas else { return }
        let merged = canvas.exportMergedImage(baseImage: currentLoadedImage.image)
        UIImageWriteToSavedPhotosAlbum(merged, nil, nil, nil)
    }

    /// ローカルに描画履歴を保存
    func saveDrawingLocal(imageName: String, userName: String) {
        guard let canvas else { return }
        do {
            let data = try canvas.exportDrawingData()
            var pkg = DrawingPackage(
                imageKey: imageName,
                drawingKey: userName,
                drawingData: data
            )
            pkg.updatedAt = Date()
            try DrawingLocalStore.shared.save(pkg)
            print("描画データ保存 成功:", imageName, userName)
        } catch {
            print("描画データ保存 失敗:", error)
        }
    }

    /// ローカルの描画履歴を読み出し
    func loadDrawingLocal(imageName: String, userName: String) {
        guard let canvas else { return }
        do {
            let pkg = try DrawingLocalStore.shared.load(imageKey: imageName, drawingKey: userName)
            try canvas.importDrawingData(pkg.drawingData)
            print("描画データ読み込み 成功:", imageName, userName)
        } catch {
            print("描画データ読み込み 失敗:", error)
        }

        // overlay も反映
        syncOverlayRects()
    }
}
