import SwiftUI
import DrawingKit

struct ContentView: View {

    // MARK: - DrawingKit 操作用
    @State private var canvas: DrawingCanvasView?

    // MARK: - Draw settings
    @State private var mode: DrawMode = .pen
    @State private var color: Color = .red
    @State private var lineWidth: CGFloat = 4
    @State private var opacity: CGFloat = 1.0
    @State private var eraserRadius: CGFloat = 18

    // MARK: - ZoomPan 用
    @State private var viewportState = ViewportState.initial
    @State private var zoomRequest: ZoomRequest = .none

    var body: some View {
        ZStack {

            // ==== Zoom + Drawing ====
            ZoomableDrawingRepresentable(
                image: UIImage(named: "sample1")!, // Assetsに入れておく
                canvasRef: $canvas,
                viewportState: $viewportState,
                zoomRequest: $zoomRequest
            )
            .ignoresSafeArea()

            // ==== UI Overlay ====
            VStack {
                topBar
                Spacer()
                bottomBar
            }
            .padding()
        }
    }
}

private extension ContentView {

    var topBar: some View {
        HStack(spacing: 12) {

            Button("Reset Zoom") {
                zoomRequest = .reset
            }

            Text(String(format: "scale: %.2f", viewportState.scale))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

private extension ContentView {

    var bottomBar: some View {
        VStack(spacing: 12) {

            // ==== Mode ====
            HStack {
                Button("Pen")   { mode = .pen }
                Button("Stamp") { mode = .stamp }
                Button("Erase") { mode = .eraser }
            }

            // ==== Color ====
            ColorPicker("Color", selection: $color)
                .labelsHidden()

            // ==== Pen ====
            if mode == .pen {
                VStack {
                    Slider(value: $lineWidth, in: 1...20) {
                        Text("Line")
                    }
                    Slider(value: Binding(
                        get: { Double(opacity) },
                        set: { opacity = CGFloat($0) }
                    ), in: 0.1...1.0) {
                        Text("Opacity")
                    }
                }
            }

            // ==== Eraser ====
            if mode == .eraser {
                Slider(value: $eraserRadius, in: 6...60) {
                    Text("Eraser")
                }
            }

            // ==== Commands ====
            HStack {
                Button("Undo") { canvas?.undo() }
                Button("Redo") { canvas?.redo() }
                Button("Clear") { canvas?.clear() }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .onChange(of: mode) { _ in syncCanvas() }
        .onChange(of: color) { _ in syncCanvas() }
        .onChange(of: lineWidth) { _ in syncCanvas() }
        .onChange(of: opacity) { _ in syncCanvas() }
        .onChange(of: eraserRadius) { _ in syncCanvas() }
    }

    /// SwiftUI State → DrawingCanvasView へ反映
    func syncCanvas() {
        guard let canvas else { return }

        canvas.mode = mode

        canvas.penStyle = PenStyle(
            color: UIColor(color),
            lineWidth: lineWidth,
            opacity: opacity
        )
        canvas.eraserRadius = eraserRadius
    }
}
