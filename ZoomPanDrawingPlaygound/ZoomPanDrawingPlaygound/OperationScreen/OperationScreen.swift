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

    // overlay rects
    @State var overlayRects: [CanvasRect] = SampleData.overlayRects

    // 選択
    @State var selectedRectIDs: Set<UUID> = []

    // 保存キー（サンプル）
    @State var imageKey: String = "sample1"
    @State var drawingKey: String = "v1"

    // Preset
    @State var zoomPreset = ZoomPreset(centerX: 300, centerY: 300, scale: 2.0)
    @State var rectPreset = RectPreset(centerX: 200, centerY: 200, width: 200, height: 140)

    var body: some View {
        ZStack {
            canvasLayer

            // ✅ iPadだけ上部バー
            if !isPhoneLayout {
                topBarLayer
            }

            // ✅ iPad: floating
            if !isPhoneLayout {
                drawingPanelLayer
                rectListPanelLayer
                selectedRectPanelLayer
                modePanelLayer
            }

            // ✅ iPhone: 固定バー + sheet
            if isPhoneLayout {
                phoneBottomBarLayer
            }

            // iPhoneでも preset は sheet にしたいならここを差し替え可。
            // ひとまず “いまのまま” 表示するなら iPhoneでも modePanelLayer を出してOK。
            // ただし上部バーは出さないので、UI的には phoneSheet化の方が自然。
        }
        .onChange(of: canvas) { _ in
            applyInteractionModeToCanvas()
            syncCanvasToolState()
            syncOverlayRects()
        }
        .onChange(of: interactionMode) { _ in
            applyInteractionModeToCanvas()
            syncCanvasToolState()
        }
        .onChange(of: drawingSettings) { _ in
            syncCanvasToolState()
        }
        .onChange(of: overlayRects) { _ in
            syncOverlayRects()
        }
        .onChange(of: selectedRectIDs) { _ in
            syncOverlayRects()
        }
        .sheet(item: $presentedPanel) { route in
            phoneSheet(for: route)
        }
    }
}
