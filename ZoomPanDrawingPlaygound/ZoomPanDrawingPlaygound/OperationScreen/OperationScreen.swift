import DrawingKit
import SwiftUI
import UIKit

struct OperationScreen: View {

    // DrawingKit 操作用（Representable から注入される UIKit View）
    @State var canvas: DrawingCanvasView?

    // UIのモード
    @State var interactionMode: InteractionMode = .normal

    // 描画ツールの状態
    @State var drawingSettings = DrawingSettings()

    // ZoomPan 用
    @State var viewportState = ViewportState.initial
    @State var zoomRequest: ZoomRequest = .none

    // 右下（描画パネル）位置
    @State var panelPos: CGPoint = .zero
    @State var didInitPanelPos: Bool = false
    let panelWidth: CGFloat = 260

    // Rect一覧パネル位置
    @State var rectListPanelPos: CGPoint = .zero
    @State var didInitRectListPanelPos: Bool = false
    let rectListPanelWidth: CGFloat = 320

    // Rect一覧パネルは「見せる/隠す」を明示的に持つ
    @State public var isRectListVisible: Bool = false

    // 選択Rectパネル位置
    @State public var selectionPanelPos: CGPoint = .zero
    @State public var didInitSelectionPanelPos: Bool = false
    public let selectionPanelWidth: CGFloat = 320

    // overlay矩形（Undo不要の表示要素）
    @State var overlayRects: [CanvasRect] = [
        CanvasRect(
            externalID: "A-001",
            name: "部品A",
            isChecked: false,
            isHidden: false,
            rect: CGRect(x: 100, y: 120, width: 220, height: 160),
            style: CanvasRectStyle(
                strokeColor: .systemYellow,
                strokeWidth: 3,
                fill: .solid(UIColor.systemYellow.withAlphaComponent(0.15))
            )
        ),
        CanvasRect(
            externalID: "B-002",
            name: "部品B（確認済）",
            isChecked: true,
            isHidden: false,
            rect: CGRect(x: 380, y: 140, width: 180, height: 120),
            style: CanvasRectStyle(
                strokeColor: .systemYellow,
                strokeWidth: 3,
                fill: .none
            )
        ),
        CanvasRect(
            externalID: "C-003",
            name: "部品C（非表示）",
            isChecked: false,
            isHidden: true,
            rect: CGRect(x: 160, y: 340, width: 200, height: 140),
            style: CanvasRectStyle(
                strokeColor: .systemYellow,
                strokeWidth: 3,
                fill: .none
            )
        ),
    ]

    @State var selectedRectIDs: Set<UUID> = []

    // 保存キー（画像と紐づく想定）
    @State var imageKey: String = "sample1"
    @State var drawingKey: String = "v1"

    // ズーム指定（画像座標）
    @State var zoomPreset = ZoomPreset(centerX: 300, centerY: 300, scale: 2.0)

    // 矩形追加指定（画像座標）
    @State var rectPreset = RectPreset(centerX: 200, centerY: 200, width: 200, height: 140)

    var body: some View {
        ZStack {
            canvasLayer
            topBarLayer
            drawingPanelLayer
            modePanelLayer
            rectListPanelLayer
            selectedRectPanelLayer
        }
        // canvas が注入されたら、今の状態を反映
        .onChange(of: canvas) { _ in
            applyInteractionModeToCanvas()
            syncCanvasToolState()
            syncOverlayRects()
        }
        // モード変更
        .onChange(of: interactionMode) { _ in
            applyInteractionModeToCanvas()
            syncCanvasToolState()
        }
        // 描画設定変更
        .onChange(of: drawingSettings) { _ in
            syncCanvasToolState()
        }
        // overlay変更
        .onChange(of: overlayRects) { _ in
            syncOverlayRects()
        }
        // 選択変更
        .onChange(of: selectedRectIDs) { _ in
            syncOverlayRects()
        }
    }
}
