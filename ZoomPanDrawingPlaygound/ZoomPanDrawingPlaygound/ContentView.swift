import DrawingKit
import SwiftUI

struct ContentView: View {

    // =========================================================
    // DrawingKit 操作用（Representable から注入される UIKit View）
    // =========================================================
    @State private var canvas: DrawingCanvasView?

    // =========================================================
    // App の操作モード（normal: 1本指パンOK / drawing: 描画UI表示）
    // =========================================================
    @State private var operationMode: OperationMode = .normal

    // =========================================================
    // 描画ツールの状態（ペン/スタンプ/消しゴムを分離して保持）
    // =========================================================
    @State private var drawingSettings = DrawingSettings()

    // =========================================================
    // ZoomPan 用（既存）
    // =========================================================
    @State private var viewportState = ViewportState.initial
    @State private var zoomRequest: ZoomRequest = .none

    // =========================================================
    // 右下パネル位置（ドラッグ移動）
    // =========================================================
    @State private var panelPos: CGPoint = .zero
    @State private var didInitPanelPos: Bool = false

    @State private var overlayRects: [CanvasRect] = [
        CanvasRect(
            rect: CGRect(x: 100, y: 120, width: 220, height: 160),
            style: CanvasRectStyle(
                strokeColor: .systemGreen,
                strokeWidth: 3,
                fill: .solid(UIColor.systemGreen.withAlphaComponent(0.15))
            )
        )
    ]

    private let panelWidth: CGFloat = 260

    var body: some View {
        ZStack {
            canvasLayer
            topBarLayer
            drawingPanelLayer
        }
        // canvas が注入されたら、今の状態を反映
        .onChange(of: canvas) { _ in
            applyOperationModeToCanvas()
            syncCanvasToolState()
        }

        // 操作モード切替（normal/drawing）
        .onChange(of: operationMode) { _ in
            applyOperationModeToCanvas()
            syncCanvasToolState()
        }

        // 描画設定が変わったら Canvas に反映（ここに集約）
        .onChange(of: drawingSettings) { _ in
            syncCanvasToolState()
        }
    }
}

// MARK: - Layers（ここに分割して型推論と可読性を改善）

extension ContentView {

    /// 下層：画像 + ズームパン + 描画キャンバス
    fileprivate var canvasLayer: some View {
        ZoomableDrawingRepresentable(
            image: UIImage(named: "sample1")!,
            isDrawing: Binding(
                get: { operationMode == .drawing },
                set: { operationMode = $0 ? .drawing : .normal }
            ),
            canvasRef: $canvas,
            viewportState: $viewportState,
            zoomRequest: $zoomRequest
        )
    }

    /// 上部バー
    fileprivate var topBarLayer: some View {
        VStack {
            topBar
            Spacer()
        }
        .padding()
    }

    /// 描画パネル（描画モードのときだけ表示）
    @ViewBuilder
    fileprivate var drawingPanelLayer: some View {
        if operationMode == .drawing {
            GeometryReader { proxy in
                DraggableAutoPanel(
                    containerSize: proxy.size,
                    width: panelWidth,
                    margin: 12,
                    headerHeight: 44,
                    position: $panelPos
                ) {
                    // ---- header（掴んで移動できる領域）----
                    DrawingModePanelHeader(drawMode: drawingSettings.tool)
                        .padding(.horizontal, 12)
                } content: {
                    // ---- panel content（ボタン/スライダー操作領域）----
                    // 既存 DrawingModePanel の引数に合わせるため、一旦 “互換 Binding” を渡す
                    DrawingModePanel(
                        drawMode: toolBinding,
                        stampKind: stampKindBinding,
                        color: activeColorBinding,
                        lineWidth: activeSizeBinding,
                        opacity: activeOpacityBinding,
                        eraserRadius: eraserRadiusBinding,
                        onUndo: { canvas?.undo() },
                        onRedo: { canvas?.redo() },
                        onClear: { canvas?.clear() },
                        onSave: { /* 次ステップで実装 */  }
                    )
                    .padding(.horizontal, 12)
                }
                .onAppear {
                    initPanelPositionIfNeeded(in: proxy.size)
                }
            }
            .ignoresSafeArea()
        }
    }

    /// 初回だけ右下に置く
    fileprivate func initPanelPositionIfNeeded(in container: CGSize) {
        guard !didInitPanelPos else { return }
        didInitPanelPos = true

        panelPos = CGPoint(
            x: container.width - panelWidth / 2 - 16,
            y: container.height - 140  // 高さは自動変動する前提なので “だいたい” でOK
        )
    }
}

// MARK: - UI（TopBar）

extension ContentView {

    fileprivate var topBar: some View {
        HStack(spacing: 12) {

            Button("Reset Zoom") {
                zoomRequest = .reset
            }

            Text(String(format: "scale: %.2f", viewportState.scale))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // 「描画」トグル（押したときだけ描画モード）
            Button {
                operationMode = (operationMode == .drawing) ? .normal : .drawing
            } label: {
                Text("描画")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(operationMode == .drawing ? Color.blue.opacity(0.25) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Canvas 反映（UIKit の DrawingCanvasView へ適用）

extension ContentView {

    /// 操作モードに応じて Canvas 入力を ON/OFF
    fileprivate func applyOperationModeToCanvas() {
        guard let canvas else { return }

        switch operationMode {
        case .drawing:
            // 描画時：ツールは syncCanvasToolState が責務を持つ
            canvas.mode = drawingSettings.tool

        case .normal:
            // normal時：描画しない
            canvas.mode = .none
        }
    }

    /// 現在の DrawingSettings を Canvas に反映
    fileprivate func syncCanvasToolState() {
        guard let canvas else { return }
        guard operationMode == .drawing else { return }

        // どのツールで描くか
        canvas.mode = drawingSettings.tool

        // ペン
        canvas.penStyle = PenStyle(
            color: UIColor(drawingSettings.pen.color),
            lineWidth: drawingSettings.pen.width,
            opacity: drawingSettings.pen.opacity
        )

        // 消しゴム
        canvas.eraserRadius = drawingSettings.eraser.radius

        // スタンプ
        canvas.stampKind = drawingSettings.stamp.kind
        canvas.stampStyle = StampStyle(
            color: UIColor(drawingSettings.stamp.color),
            size: drawingSettings.stamp.size,
            opacity: drawingSettings.stamp.opacity
        )

        //  矩形オーバーレイ
        canvas.setOverlayRects(overlayRects)
    }
}

// MARK: - DrawingModePanel 互換用 Binding（後でPanel側を直すと不要になる）

extension ContentView {

    /// ツール種別（pen/stamp/eraser）
    fileprivate var toolBinding: Binding<DrawMode> {
        Binding(
            get: { drawingSettings.tool },
            set: { drawingSettings.tool = $0 }
        )
    }

    /// スタンプ種類
    fileprivate var stampKindBinding: Binding<StampKind> {
        Binding(
            get: { drawingSettings.stamp.kind },
            set: { drawingSettings.stamp.kind = $0 }
        )
    }

    /// Panelの ColorPicker が触る “現在ツールの色”
    /// - ペンなら pen.color
    /// - スタンプなら stamp.color
    fileprivate var activeColorBinding: Binding<Color> {
        Binding(
            get: {
                switch drawingSettings.tool {
                case .stamp: return drawingSettings.stamp.color
                default: return drawingSettings.pen.color
                }
            },
            set: { newValue in
                switch drawingSettings.tool {
                case .stamp: drawingSettings.stamp.color = newValue
                default: drawingSettings.pen.color = newValue
                }
            }
        )
    }

    /// Panelの Slider(lineWidth) が触る “現在ツールのサイズ”
    /// - ペンなら pen.width
    /// - スタンプなら stamp.size
    fileprivate var activeSizeBinding: Binding<CGFloat> {
        Binding(
            get: {
                switch drawingSettings.tool {
                case .stamp: return drawingSettings.stamp.size
                default: return drawingSettings.pen.width
                }
            },
            set: { newValue in
                switch drawingSettings.tool {
                case .stamp: drawingSettings.stamp.size = newValue
                default: drawingSettings.pen.width = newValue
                }
            }
        )
    }

    /// Panelの Slider(opacity) が触る “現在ツールの不透明度”
    /// - ペンなら pen.opacity
    /// - スタンプなら stamp.opacity
    fileprivate var activeOpacityBinding: Binding<CGFloat> {
        Binding(
            get: {
                switch drawingSettings.tool {
                case .stamp: return drawingSettings.stamp.opacity
                default: return drawingSettings.pen.opacity
                }
            },
            set: { newValue in
                switch drawingSettings.tool {
                case .stamp: drawingSettings.stamp.opacity = newValue
                default: drawingSettings.pen.opacity = newValue
                }
            }
        )
    }

    /// 消しゴム半径
    fileprivate var eraserRadiusBinding: Binding<CGFloat> {
        Binding(
            get: { drawingSettings.eraser.radius },
            set: { drawingSettings.eraser.radius = $0 }
        )
    }
}
