import DrawingKit
import SwiftUI

// =========================================================
// ContentView（UI整理版）
// - normal: 1本指Pan/Pinch
// - drawing: 描画パネル + 1本指描画
// - zoomPreset: 指定座標 + 指定倍率でズーム
// - rectPreset: 指定座標 + 指定サイズの矩形を追加（overlay）
// =========================================================
struct ContentView: View {

    // DrawingKit 操作用（Representable から注入される UIKit View）
    @State private var canvas: DrawingCanvasView?

    // UIのモード
    @State private var interactionMode: InteractionMode = .normal

    // 描画ツールの状態
    @State private var drawingSettings = DrawingSettings()

    // ZoomPan 用
    @State private var viewportState = ViewportState.initial
    @State private var zoomRequest: ZoomRequest = .none

    // 右下パネル位置
    @State private var panelPos: CGPoint = .zero
    @State private var didInitPanelPos: Bool = false
    private let panelWidth: CGFloat = 260

    // Rect一覧パネル位置
    @State private var rectListPanelPos: CGPoint = .zero
    @State private var didInitRectListPanelPos: Bool = false
    private let rectListPanelWidth: CGFloat = 320

    // overlay矩形（Undo不要の表示要素）
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

    // 保存キー（画像と紐づく想定）
    @State private var imageKey: String = "sample1"
    @State private var drawingKey: String = "v1"

    // ズーム指定（画像座標）
    @State private var zoomPreset = ZoomPreset(
        centerX: 300,
        centerY: 300,
        scale: 2.0
    )

    // 矩形追加指定（画像座標）
    @State private var rectPreset = RectPreset(
        centerX: 200,
        centerY: 200,
        width: 200,
        height: 140
    )

    var body: some View {
        ZStack {
            canvasLayer
            topBarLayer
            drawingPanelLayer
            modePanelLayer
            rectListPanelLayer
        }
        // canvas が注入されたら、今の状態を反映
        .onChange(of: canvas) { _ in
            applyInteractionModeToCanvas()
            syncCanvasToolState()
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
    }
}

// MARK: - Layers

extension ContentView {

    /// 下層：画像 + ズームパン + 描画キャンバス
    fileprivate var canvasLayer: some View {
        ZoomableDrawingRepresentable(
            image: UIImage(named: "sample1")!,
            isDrawing: Binding(
                get: { interactionMode == .drawing },
                set: { interactionMode = $0 ? .drawing : .normal }
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

    /// モード別の小パネル（zoomPreset / rectPreset）
    @ViewBuilder
    fileprivate var modePanelLayer: some View {
        if interactionMode == .zoomPreset {
            VStack {
                zoomPresetPanel
                Spacer()
            }
            .padding()
        } else if interactionMode == .rectPreset {
            VStack {
                rectPresetPanel
                Spacer()
            }
            .padding()
        }
    }

    fileprivate func initPanelPositionIfNeeded(in container: CGSize) {
        guard !didInitPanelPos else { return }
        didInitPanelPos = true
        panelPos = CGPoint(
            x: container.width - panelWidth / 2 - 16,
            y: container.height - 140
        )
    }
}

// MARK: - TopBar

extension ContentView {

    fileprivate var topBar: some View {
        VStack(spacing: 10) {

            HStack(spacing: 10) {

                // ✅ 追加：いまnormal以外なら「戻る」
                if interactionMode != .normal {
                    Button {
                        interactionMode = .normal
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                    .background(Color.black.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                modeButton("Normal", .normal)
                modeButton("描画", .drawing)
                modeButton("Zoom指定", .zoomPreset)
                modeButton("Rect追加", .rectPreset)
                modeButton("Rect一覧", .rectList)

                Spacer()

                Button("Reset Zoom") { zoomRequest = .reset }

                Text(String(format: "scale: %.2f", viewportState.scale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                TextField("imageKey", text: $imageKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)

                TextField("drawingKey", text: $drawingKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)

                Button("Save(Local)") { saveDrawingLocal() }
                Button("Load(Local)") { loadDrawingLocal() }

                Spacer()

                Button("Save(Photos)") { saveMergedToPhotos() }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    fileprivate func modeButton(_ title: String, _ mode: InteractionMode) -> some View {
        Button {
            interactionMode = mode
        } label: {
            Text(title)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(interactionMode == mode ? Color.blue.opacity(0.25) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

// MARK: - Panels (CommonFloatingPanel)

extension ContentView {

    @ViewBuilder
    fileprivate var drawingPanelLayer: some View {
        if interactionMode == .drawing {
            GeometryReader { proxy in
                CommonFloatingPanel(
                    kind: .drawing,
                    containerSize: proxy.size,
                    width: panelWidth,
                    margin: 12,
                    headerHeight: 44,
                    title: "書き込みモード",
                    onClose: { interactionMode = .normal },
                    trailing: {
                        AnyView(
                            EmptyView()
                        )
                    },
                    position: $panelPos,
                    didInitPosition: $didInitPanelPos
                ) {
                    DrawingModePanel(
                        drawMode: toolBinding,
                        stampKind: stampKindBinding,
                        color: activeColorBinding,
                        lineWidth: activeSizeBinding,
                        opacity: activeOpacityBinding,
                        eraserRadius: eraserRadiusBinding,
                        onUndo: { canvas?.undo() },
                        onRedo: { canvas?.redo() },
                        onSave: { saveMergedToPhotos() }
                    )
                    .padding(.horizontal, 12)
                }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    fileprivate var rectListPanelLayer: some View {
        if interactionMode == .rectList {
            GeometryReader { proxy in
                CommonFloatingPanel(
                    kind: .rectList,
                    containerSize: proxy.size,
                    width: rectListPanelWidth,
                    margin: 12,
                    headerHeight: 44,
                    title: "Rect一覧（overlay）",
                    onClose: { interactionMode = .normal },
                    trailing: { AnyView(EmptyView()) },
                    position: $rectListPanelPos,
                    didInitPosition: $didInitRectListPanelPos
                ) {
                    rectListPanelContent
                        .padding(.horizontal, 12)
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Zoom指定パネル

extension ContentView {

    fileprivate var zoomPresetPanel: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text("Zoom指定（画像座標）")
                    .font(.headline)

                Spacer()

                // ✅ 追加：閉じる（Normalへ）
                Button("閉じる") { interactionMode = .normal }
            }

            HStack {
                numberField("centerX", value: $zoomPreset.centerX, width: 110)
                numberField("centerY", value: $zoomPreset.centerY, width: 110)
                numberField("scale", value: $zoomPreset.scale, width: 90)
            }

            HStack {
                Button("この値でZoom") {
                    zoomRequest = .set(
                        scale: zoomPreset.scale,
                        centerInImage: CGPoint(x: zoomPreset.centerX, y: zoomPreset.centerY)
                    )
                }

                Button("中心を現在表示中心に") {
                    zoomPreset.centerX = viewportState.centerInImage.x
                    zoomPreset.centerY = viewportState.centerInImage.y
                }

                Spacer()
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Rect追加パネル

extension ContentView {

    fileprivate var rectPresetPanel: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text("矩形追加（overlay / 画像座標）")
                    .font(.headline)

                Spacer()

                // ✅ 追加：閉じる（Normalへ）
                Button("閉じる") { interactionMode = .normal }
            }

            HStack {
                numberField("centerX", value: $rectPreset.centerX, width: 110)
                numberField("centerY", value: $rectPreset.centerY, width: 110)
            }

            HStack {
                numberField("width", value: $rectPreset.width, width: 110)
                numberField("height", value: $rectPreset.height, width: 110)
            }

            HStack {
                Button("矩形を追加") { appendOverlayRectFromPreset() }
                Button("全部クリア") { overlayRects.removeAll() }
                Spacer()
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Canvas 反映

extension ContentView {

    fileprivate func applyInteractionModeToCanvas() {
        guard let canvas else { return }

        switch interactionMode {
        case .drawing:
            canvas.mode = drawingSettings.tool
        case .normal, .zoomPreset, .rectPreset, .rectList:
            canvas.mode = .none
        }
    }

    fileprivate func syncCanvasToolState() {
        guard let canvas else { return }
        guard interactionMode == .drawing else { return }

        canvas.mode = drawingSettings.tool

        canvas.penStyle = PenStyle(
            color: UIColor(drawingSettings.pen.color),
            lineWidth: drawingSettings.pen.width,
            opacity: drawingSettings.pen.opacity
        )

        canvas.eraserRadius = drawingSettings.eraser.radius

        canvas.stampKind = drawingSettings.stamp.kind
        canvas.stampStyle = StampStyle(
            color: UIColor(drawingSettings.stamp.color),
            size: drawingSettings.stamp.size,
            opacity: drawingSettings.stamp.opacity
        )

        // overlayは描画モードでも見せる
        canvas.setOverlayRects(overlayRects)
    }

    fileprivate func syncOverlayRects() {
        // overlayは描画モードじゃなくても追従して欲しいので、
        // canvasが生きてる限り毎回反映してOK
        canvas?.setOverlayRects(overlayRects)
    }
}

// MARK: - Actions（Save/Load/Photos + Rect追加）

extension ContentView {

    fileprivate func saveMergedToPhotos() {
        guard let canvas else { return }
        guard let base = UIImage(named: "sample1") else { return }
        let merged = canvas.exportMergedImage(baseImage: base)
        UIImageWriteToSavedPhotosAlbum(merged, nil, nil, nil)
    }

    fileprivate func saveDrawingLocal() {
        guard let canvas else { return }
        do {
            let data = try canvas.exportDrawingData()
            var pkg = DrawingPackage(
                imageKey: imageKey,
                drawingKey: drawingKey,
                drawingData: data
            )
            pkg.updatedAt = Date()
            try DrawingLocalStore.shared.save(pkg)
            print("✅ saved:", imageKey, drawingKey)
        } catch {
            print("❌ save failed:", error)
        }
    }

    fileprivate func loadDrawingLocal() {
        guard let canvas else { return }
        do {
            let pkg = try DrawingLocalStore.shared.load(imageKey: imageKey, drawingKey: drawingKey)
            try canvas.importDrawingData(pkg.drawingData)
            print("✅ loaded:", imageKey, drawingKey)

            // overlayも再反映（見た目がズレてたら即戻せる）
            syncOverlayRects()
        } catch {
            print("❌ load failed:", error)
        }
    }

    fileprivate func appendOverlayRectFromPreset() {
        let rect = CGRect(
            x: rectPreset.centerX - rectPreset.width * 0.5,
            y: rectPreset.centerY - rectPreset.height * 0.5,
            width: rectPreset.width,
            height: rectPreset.height
        )

        let style = CanvasRectStyle(
            strokeColor: .systemGreen,
            strokeWidth: 3,
            fill: .solid(UIColor.systemGreen.withAlphaComponent(0.15))
        )

        overlayRects.append(CanvasRect(rect: rect, style: style))
    }
}

// MARK: - Bindings（DrawingModePanel互換）

extension ContentView {

    fileprivate var toolBinding: Binding<DrawMode> {
        Binding(
            get: { drawingSettings.tool },
            set: { drawingSettings.tool = $0 }
        )
    }

    fileprivate var stampKindBinding: Binding<StampKind> {
        Binding(
            get: { drawingSettings.stamp.kind },
            set: { drawingSettings.stamp.kind = $0 }
        )
    }

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

    fileprivate var eraserRadiusBinding: Binding<CGFloat> {
        Binding(
            get: { drawingSettings.eraser.radius },
            set: { drawingSettings.eraser.radius = $0 }
        )
    }
}

extension ContentView {

    fileprivate var rectListPanelContent: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text("count: \(overlayRects.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("全部クリア") { overlayRects.removeAll() }
            }

            // 長くなったら困るので ScrollView + 高さ上限
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if overlayRects.isEmpty {
                        Text("Rectがありません")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(Array(overlayRects.enumerated()), id: \.offset) { index, item in
                            rectRow(index: index, rect: item.rect)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(minHeight: 200, maxHeight: 400)  // パネルが巨大化しないように
        }
    }

    @ViewBuilder
    fileprivate func rectRow(index: Int, rect: CGRect) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("#\(index)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Button("Zoom") {
                    let center = CGPoint(x: rect.midX, y: rect.midY)
                    // とりあえず「中心へ寄せて少し拡大」
                    let targetScale = max(viewportState.scale, 2.0)
                    zoomRequest = .set(scale: targetScale, centerInImage: center)
                }

                Button(role: .destructive) {
                    if overlayRects.indices.contains(index) {
                        overlayRects.remove(at: index)
                    }
                } label: {
                    Text("削除")
                }
            }

            Text(rectSummary(rect))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider().opacity(0.2)
        }
        .padding(.vertical, 4)
    }

    fileprivate func rectSummary(_ r: CGRect) -> String {
        String(
            format: "x: %.1f  y: %.1f  w: %.1f  h: %.1f",
            r.origin.x, r.origin.y, r.size.width, r.size.height)
    }
}

// MARK: - UI helpers / Local types

private enum InteractionMode: Equatable {
    case normal
    case drawing
    case zoomPreset
    case rectPreset
    case rectList
}

private struct ZoomPreset: Equatable {
    var centerX: CGFloat
    var centerY: CGFloat
    var scale: CGFloat
}

private struct RectPreset: Equatable {
    var centerX: CGFloat
    var centerY: CGFloat
    var width: CGFloat
    var height: CGFloat
}

extension ContentView {
    fileprivate func numberField(_ title: String, value: Binding<CGFloat>, width: CGFloat)
        -> some View
    {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)

            TextField(
                title,
                text: Binding(
                    get: { String(format: "%.2f", value.wrappedValue) },
                    set: { newText in
                        let filtered = newText.replacingOccurrences(of: ",", with: ".")
                        if let v = Double(filtered) {
                            value.wrappedValue = CGFloat(v)
                        }
                    }
                )
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
            .keyboardType(.decimalPad)
        }
    }
}
