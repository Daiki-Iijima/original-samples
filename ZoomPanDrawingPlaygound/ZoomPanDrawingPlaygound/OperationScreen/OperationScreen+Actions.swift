import DrawingKit
import SwiftUI
import UIKit
import Foundation
import YamatoAppContracts

extension OperationScreen {


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
