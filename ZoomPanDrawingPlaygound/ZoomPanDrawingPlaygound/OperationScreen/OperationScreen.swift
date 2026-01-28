import DrawingKit
import SwiftUI
import UIKit

struct OperationScreen: View {

    @Environment(\.horizontalSizeClass) private var hSizeClass
    var isPhoneLayout: Bool { hSizeClass == .compact }

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

    // iPad: 描画パネル位置
    @State var panelPos: CGPoint = .zero
    @State var didInitPanelPos: Bool = false
    let panelWidth: CGFloat = 260

    // iPad: Rect一覧パネル位置
    @State var rectListPanelPos: CGPoint = .zero
    @State var didInitRectListPanelPos: Bool = false
    let rectListPanelWidth: CGFloat = 320

    // Rect一覧パネル表示トグル（iPad）
    @State var isRectListVisible: Bool = false

    // iPad: 選択パネル位置
    @State var selectionPanelPos: CGPoint = .zero
    @State var didInitSelectionPanelPos: Bool = false
    let selectionPanelWidth: CGFloat = 320
    
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
    @State var imageKey: String = "sample1"
    @State var drawingKey: String = "v1"

    // Preset
    @State var zoomPreset = ZoomPreset(centerX: 300, centerY: 300, scale: 2.0)
    @State var rectPreset = RectPreset(centerX: 200, centerY: 200, width: 200, height: 140)

    var body: some View {
        ZStack (alignment: .top){
            canvasLayer

            // iPadだけ上部バー
            if !isPhoneLayout {
                OperationiPadTopBar(
                            interactionMode: $interactionMode,
                            isRectListVisible: $isRectListVisible,
                            viewportScale: viewportState.scale,
                            imageKey: $imageKey,
                            drawingKey: $drawingKey,
                            isUnconfirmedPartsVisible: $isUnconfirmedPartsVisible,
                            onResetZoom: { zoomRequest = .reset },
                            onSaveLocal: { saveDrawingLocal() },
                            onLoadLocal: { loadDrawingLocal() },
                            onSavePhotos: { saveMergedToPhotos() }
                            )
            }

            // iPad: floating
            if !isPhoneLayout {
                drawingPanelLayer
                rectListPanelLayer
                modePanelLayer
                unconfirmedPartsPanelLayer
            }

            // iPhone: 固定バー + sheet
            if isPhoneLayout {
                phoneBottomBarLayer
            }

            // iPhoneでも preset は sheet にしたいならここを差し替え可。
            // ひとまず “いまのまま” 表示するなら iPhoneでも modePanelLayer を出してOK。
            // ただし上部バーは出さないので、UI的には phoneSheet化の方が自然。
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
        .onChange(of: isUnconfirmedPartsVisible) {
            // パネル開閉で overlay の有効/無効を切替
            syncOverlayRects()

            // 閉じたら選択もクリアしたいなら（任意）
            if !isUnconfirmedPartsVisible {
                selectedRectIDs.removeAll()
            }
        }
        .sheet(item: $presentedPanel) { route in
            phoneSheet(for: route)
        }
    }
}

#Preview {
    OperationScreen()
}
