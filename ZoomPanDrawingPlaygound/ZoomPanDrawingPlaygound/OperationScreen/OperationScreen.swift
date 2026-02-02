import DrawingKit
import SwiftUI
import UIKit

struct OperationScreen: View {

    @Environment(\.horizontalSizeClass) private var hSizeClass
    var isPhoneLayout: Bool { hSizeClass == .compact }
    
    // 現在開いているプロジェクト（未確認部材一覧モードで有効）
    @State var currentProjectID: String? = nil
    //  プロジェクト切り替え時のズーム待機列
    @State var pendingZoomRect: CanvasRect?

    // iPhoneのsheet表示ルート
    @State var presentedPanel: PanelRoute? = nil

    // DrawingKit
    @State var canvas: DrawingCanvasView?

    // UIモード
    @State var interactionMode: InteractionMode = .normal

    // 描画設定
    @State var drawingSettings = DrawingSettings()

    // ZoomPan
    @State var viewportState = ViewportState.initial
    @State var zoomRequest: ZoomRequest = .none
    
    //  メモ周り
    @State var memoText: String = ""
    @State var memoPanelPos: CGPoint = .zero
    @State var didInitMemoPanelPos: Bool = false
    let memoPanelWidth: CGFloat = 360
    
    //  リンクプロジェクト周り
    @State var linkProjectsPos: CGPoint = .zero
    @State var didInitLinkProjectsPanelPos: Bool = false
    let linkProjectsPanelWidth: CGFloat = 320

    // iPad: 描画パネル位置
    @State var panelPos: CGPoint = .zero
    @State var didInitPanelPos: Bool = false
    let panelWidth: CGFloat = 260
    
    // 未確認部材一覧パネル（iPad）
    @State var isUnconfirmedPartsVisible: Bool = false

    @State var unconfirmedPartsPanelPos: CGPoint = .zero
    @State var didInitUnconfirmedPartsPanelPos: Bool = false
    let unconfirmedPartsPanelWidth: CGFloat = 320


    // overlay rects
    @State var overlayRects: [CanvasRect] = SampleData.overlayRects

    // 選択
    @State var selectedRectIDs: Set<UUID> = []

    //  保存キー
    //  Actionsで使用
    @State var imageKey: String = "proj_a"
    @State var drawingKey: String = "v1"

    // Preset
    @State var zoomPreset = ZoomPreset(centerX: 300, centerY: 300, scale: 2.0)
    @State var rectPreset = RectPreset(centerX: 200, centerY: 200, width: 200, height: 140)

    var body: some View {
        ZStack(alignment: .top) {
            canvasLayer

            if isPhoneLayout {
                VStack(spacing: 0) {
                    OperationPhoneTopBar(
                        interactionMode: $interactionMode,
                        viewportScale: viewportState.scale,
                        onBack: { /* dismiss */ },
                        onResetZoom: { zoomRequest = .reset },
                        onForceQuit: { /* your logic */ }
                    )

                    Spacer()

                    OperationPhoneBottomBar(
                        interactionMode: $interactionMode,
                        presentedPanel: $presentedPanel,
                        onUploadImage: { /* upload */ }
                    )
                    .padding(EdgeInsets(top: 0, leading: 8, bottom: 16, trailing: 8))
                    
                }
                .ignoresSafeArea(edges: .bottom)
            } else {
                // iPad: 既存 topBarLayer + floating panels
                topBarLayer
                drawingSettingPanelLayer
                memoPanelLayer
                unconfirmedPartsPanelLayer
                linkProjectsPanelLayer
            }
        }
        .onChange(of: canvas) {
            applyInteractionModeToCanvas()
            syncCanvasToolState()
            syncOverlayRects()
        }
        .onChange(of: interactionMode) {
            applyInteractionModeToCanvas()
            syncCanvasToolState()
        }
        .onChange(of: drawingSettings) {
            syncCanvasToolState()
        }
        .onChange(of: overlayRects) {
            syncOverlayRects()
        }
        .onChange(of: selectedRectIDs) {
            syncOverlayRects()
        }
        .onChange(of: isUnconfirmedPartsVisible) { newValue in
            setUnconfirmedPartsVisible(newValue)
        }
        .onChange(of: presentedPanel) { newValue in
            setUnconfirmedPartsVisible(newValue == .unconfirmedParts)
        }
        .onChange(of: interactionMode) { old, new in
            closePanelsForModeSwitch(from: old, to: new)
            applyInteractionModeToCanvas()
            syncCanvasToolState()
        }
        .sheet(item: $presentedPanel) { route in
            phoneSheet(for: route)
        }
    }
    
    @State var isMemoVisible: Bool = false
    @State var isLinkProjectsVisible: Bool = false
    @State var isDrawingSettingsPanelVisible: Bool = true
    
    private var topBarLayer: some View {
        // クロージャは let で先に型を確定させてから渡す
        let onBack: () -> Void = { /*dismiss()*/ }
        let onResetZoom: () -> Void = { zoomRequest = .reset }
        let onUploadImage: () -> Void = { /*uploadImage()*/ }
        let onSaveLocal: () -> Void = { saveDrawingLocal() }
        let onLoadLocal: () -> Void = { loadDrawingLocal() }
        let onSavePhotos: () -> Void = { /*saveDrawingToPhotos()*/ }

        return OperationiPadTopBar(
            interactionMode: $interactionMode,
            viewportScale: viewportState.scale,
            imageKey: $imageKey,
            drawingKey: $drawingKey,
            isUnconfirmedPartsVisible: $isUnconfirmedPartsVisible,
            isMemoVisible: $isMemoVisible,
            isLinkProjectsVisible: $isLinkProjectsVisible,
            isDrawingSettingsPanelVisible: $isDrawingSettingsPanelVisible,
            onBack: onBack,
            onResetZoom: onResetZoom,
            onUploadImage: onUploadImage,
            onSaveLocal: onSaveLocal,
            onLoadLocal: onLoadLocal,
            onSavePhotos: onSavePhotos
        )
        .padding()
    }

    private func setUnconfirmedPartsVisible(_ visible: Bool) {
        isUnconfirmedPartsVisible = visible

        if visible {
            // 初回表示時：未確認Rectがあるなら、その先頭プロジェクトを開く
            let unconfirmed = overlayRects.filter { !$0.isHidden && !$0.isChecked }
            if currentProjectID == nil {
                currentProjectID = unconfirmed.first?.projectID
            }
        } else {
            // モード外は overlay 無効（既存要件）
            currentProjectID = nil
            selectedRectIDs.removeAll()
        }

        syncOverlayRects()
    }

    private func closePanelsForModeSwitch(from old: InteractionMode, to new: InteractionMode) {

        // まず「全部閉じる」を基本にして、
        // 必要なものだけ後で開く方が事故が少ない
        isUnconfirmedPartsVisible = false
        isMemoVisible = false
        isLinkProjectsVisible = false
        isDrawingSettingsPanelVisible = false
        presentedPanel = nil

        switch new {
        case .normal:
            // normal は必要なら何も開かない（ユーザーがトグルで開く）
            break

        case .drawing:
            // drawing ではツール選択だけ残す、など
            // isDrawingSettingsPanelVisible = true  // もし自動で開きたいなら
            break

        case .camera:
            // camera は強制的に他を閉じるだけ
            break

        default:
            break
        }
    }
    
    func openProject(projectID: String,zoomRect: CanvasRect?) {
        // 1) 現在プロジェクト切替
        currentProjectID = projectID

        // 2) 画像切替（例：projectID をそのままキーにする）
        imageKey = projectID   // 例: "proj_a" / "proj_b" / "proj_c"
        // ※ Assets の画像名が違うなら map を用意してここで変換

        // 3) 選択を跨がせたくないならクリア
//        selectedRectIDs.removeAll()

        // 4) overlay 再描画
        syncOverlayRects()
        
        guard let rect = zoomRect else { return }

        // 次の runloop で zoom を投げる（Canvas 再生成後）
        DispatchQueue.main.async {
            let c = CGPoint(x: rect.rect.midX, y: rect.rect.midY)
            zoomRequest = .set(
                scale: max(viewportState.scale, 2.0),
                centerInImage: c
            )
            pendingZoomRect = nil
        }
    }
}


#Preview {
    OperationScreen()
}
