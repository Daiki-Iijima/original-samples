import DrawingKit
import SwiftUI

struct ContentView: View {

    // MARK: - DrawingKit 操作用（Representableから注入）
    @State private var canvas: DrawingCanvasView?

    // MARK: - App Mode（アプリ全体のモード）
    @State private var appMode: AppMode = .normal

    // MARK: - Draw tool settings（描画モード内ツール）
    @State private var drawMode: DrawMode = .pen
    @State private var color: Color = .red
    @State private var lineWidth: CGFloat = 4
    @State private var opacity: CGFloat = 1.0
    @State private var eraserRadius: CGFloat = 18

    // MARK: - ZoomPan 用
    @State private var viewportState = ViewportState.initial
    @State private var zoomRequest: ZoomRequest = .none

    // MARK: - 右下パネル位置（ドラッグ移動）
    @State private var panelPos: CGPoint = .zero
    @State private var didInitPanelPos: Bool = false

    private let panelSize = CGSize(width: 260, height: 180)

    var body: some View {
        ZStack {
            canvasLayer
            topBarLayer
            drawingPanelLayer
        }
        .onChange(of: canvas) { _ in
            applyAppModeToCanvas()
            syncCanvasToolState()
        }
        .onChange(of: appMode) { _ in
            applyAppModeToCanvas()
            syncCanvasToolState()
        }
        .onChange(of: drawMode) { _ in syncCanvasToolState() }
        .onChange(of: color) { _ in syncCanvasToolState() }
        .onChange(of: lineWidth) { _ in syncCanvasToolState() }
        .onChange(of: opacity) { _ in syncCanvasToolState() }
        .onChange(of: eraserRadius) { _ in syncCanvasToolState() }
    }
}

// MARK: - Layers（ここに分割すると型推論が軽くなる）

extension ContentView {

    fileprivate var canvasLayer: some View {
        ZoomableDrawingRepresentable(
            image: UIImage(named: "sample1")!,
            canvasRef: $canvas,
            viewportState: $viewportState,
            zoomRequest: $zoomRequest
        )
        .ignoresSafeArea()
    }

    fileprivate var topBarLayer: some View {
        VStack {
            topBar
            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    fileprivate var drawingPanelLayer: some View {
        if appMode == .drawing {
            GeometryReader { proxy in
                DraggableAutoPanel(
                    containerSize: proxy.size,
                    width: 260,
                    margin: 12,
                    headerHeight: 44,
                    position: $panelPos
                ) {
                    DrawingModePanelHeader(drawMode: drawMode)
                        .padding(.horizontal, 12)
                } content: {
                    DrawingModePanel(
                        drawMode: $drawMode,
                        color: $color,
                        lineWidth: $lineWidth,
                        opacity: $opacity,
                        eraserRadius: $eraserRadius,
                        onUndo: { canvas?.undo() },
                        onRedo: { canvas?.redo() },
                        onClear: { canvas?.clear() },
                        onSave: {}
                    )
                    .padding(.horizontal, 12)
                }
                .onAppear {
                    guard !didInitPanelPos else { return }
                    didInitPanelPos = true

                    // 初期位置（右下寄せ）
                    panelPos = CGPoint(
                        x: proxy.size.width - 260 / 2 - 16,
                        y: proxy.size.height - 120  // 高さは自動で伸びるので “だいたい” でOK
                    )
                }
            }
            .ignoresSafeArea()
        }
    }

    fileprivate func initPanelPositionIfNeeded(in container: CGSize) {
        guard !didInitPanelPos else { return }
        didInitPanelPos = true

        panelPos = CGPoint(
            x: container.width - panelSize.width / 2 - 16,
            y: container.height - panelSize.height / 2 - 24
        )
    }
}

// MARK: - UI

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

            Button {
                appMode = (appMode == .drawing) ? .normal : .drawing
            } label: {
                Text("描画")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(appMode == .drawing ? Color.blue.opacity(0.25) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Canvas sync

extension ContentView {

    fileprivate func applyAppModeToCanvas() {
        guard let canvas else { return }

        switch appMode {
        case .drawing:
            canvas.mode = drawMode
        default:
            canvas.mode = .none
        }
    }

    fileprivate func syncCanvasToolState() {
        guard let canvas else { return }
        guard appMode == .drawing else { return }

        canvas.mode = drawMode

        canvas.penStyle = PenStyle(
            color: UIColor(color),
            lineWidth: lineWidth,
            opacity: opacity
        )

        canvas.eraserRadius = eraserRadius
    }
}
