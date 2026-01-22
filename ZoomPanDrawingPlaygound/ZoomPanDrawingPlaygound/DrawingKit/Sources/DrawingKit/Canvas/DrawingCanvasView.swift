import UIKit

public final class DrawingCanvasView: UIView, UIGestureRecognizerDelegate {

    // =========================================================
    // MARK: - Public (SwiftUI から設定される)
    // =========================================================

    public var mode: DrawMode = .pen

    public var penStyle: PenStyle = .initial

    public var stampStyle: StampStyle = .initial
    public var stampKind: StampKind = .check

    /// 消しゴム半径（pt）
    public var eraserRadius: CGFloat = 18 {
        didSet {
            withoutImplicitAnimations {
                eraserPreviewLayer.lineWidth = max(1, eraserRadius * 2)
            }
        }
    }

    /// View長さ(pt) → canvas長さ(=画像座標)
    public var viewLengthToCanvasLength: ((CGFloat) -> CGFloat)?

    /// canvas長さ(=画像座標) → View長さ(pt)（表示用）
    public var canvasLengthToViewLength: ((CGFloat) -> CGFloat)?

    /// View座標 → “描画座標(=画像座標)” への変換（未設定ならそのままView座標）
    public var viewPointToCanvasPoint: ((CGPoint) -> CGPoint?)?

    /// “描画座標(=画像座標)” → View座標（表示用。コミット描画で使う）
    public var canvasPointToViewPoint: ((CGPoint) -> CGPoint?)?

    /// view座標(pt) → canvas座標 へ変換するスケール（例: ズーム倍率）
    public var viewToCanvasScale: CGFloat = 1.0

    // =========================================================
    // MARK: - 2 finger gestures -> Zoomへ委譲
    // =========================================================

    public var onTwoFingerPan: ((UIPanGestureRecognizer) -> Void)?
    public var onPinch: ((UIPinchGestureRecognizer) -> Void)?

    // =========================================================
    // MARK: - State（状態と履歴）
    // =========================================================

    /// 現在キャンバス上に存在する要素（最終状態）
    private var elements: [DrawingElement] = []

    /// 操作履歴（Undo/Redo 用）
    private let history = DrawingHistory<DrawingCommand>()

    // =========================================================
    // MARK: - Pen state
    // =========================================================

    private var currentPoints: [CGPoint] = []

    // =========================================================
    // MARK: - Rect overlay (image coords)
    // =========================================================

    /// 外から渡された矩形（canvas座標）
    private var overlayRects: [CanvasRect] = []

    // =========================================================
    // MARK: - Eraser state
    // =========================================================

    private var eraserPathPoints: [CGPoint] = []
    private var erasingIDs = Set<UUID>()
    private var erasingRemovedItems: [RemovedItem] = []

    // =========================================================
    // MARK: - Layers（役割分離）
    // =========================================================

    /// 確定描画（ストローク/スタンプ）はここに積む
    /// - ✅ “確定時にちらつく” の原因になってた「全消し→全描き直し」を局所化できる
    private let committedContainerLayer = CALayer()

    /// ペン描き途中プレビュー（最前面寄り）
    private let currentStrokeLayer = CAShapeLayer()

    /// 消しゴムプレビュー（軌跡線）
    private let eraserPreviewLayer = CAShapeLayer()

    /// 矩形オーバーレイ専用コンテナ
    private let rectOverlayContainerLayer = CALayer()

    // =========================================================
    // MARK: - Gestures
    // =========================================================

    /// 1本指パン：Pen/Eraser の入力
    private lazy var drawPan: UIPanGestureRecognizer = {
        let g = UIPanGestureRecognizer(target: self, action: #selector(handleDrawPan(_:)))
        g.minimumNumberOfTouches = 1
        g.maximumNumberOfTouches = 1
        g.cancelsTouchesInView = true
        return g
    }()

    /// 1本指タップ：Stamp
    private lazy var stampTap: UITapGestureRecognizer = {
        let g = UITapGestureRecognizer(target: self, action: #selector(handleStampTap(_:)))
        g.numberOfTouchesRequired = 1
        g.cancelsTouchesInView = true
        return g
    }()

    /// 2本指パン：Zoom/Pan（ZoomPanUIView に委譲）
    private lazy var twoFingerPan: UIPanGestureRecognizer = {
        let g = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        g.minimumNumberOfTouches = 2
        g.maximumNumberOfTouches = 2
        g.cancelsTouchesInView = true
        return g
    }()

    /// ピンチ：Zoom（ZoomPanUIView に委譲）
    private lazy var pinch: UIPinchGestureRecognizer = {
        let g = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        g.cancelsTouchesInView = true
        return g
    }()

    // =========================================================
    // MARK: - Init
    // =========================================================

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isMultipleTouchEnabled = true
        backgroundColor = .clear

        // --- committed container ---
        // 暗黙アニメを極力無効化して「追従遅れ」を潰す
        committedContainerLayer.actions = [
            "sublayers": NSNull(),
            "bounds": NSNull(),
            "position": NSNull(),
            "contents": NSNull(),
        ]
        layer.addSublayer(committedContainerLayer)

        // --- current stroke preview ---
        currentStrokeLayer.fillColor = UIColor.clear.cgColor
        currentStrokeLayer.actions = [
            "path": NSNull(),
            "bounds": NSNull(),
            "position": NSNull(),
            "strokeColor": NSNull(),
            "lineWidth": NSNull(),
        ]
        layer.addSublayer(currentStrokeLayer)

        // --- eraser preview ---
        eraserPreviewLayer.fillColor = UIColor.clear.cgColor
        eraserPreviewLayer.strokeColor = UIColor.black.withAlphaComponent(0.25).cgColor
        eraserPreviewLayer.lineCap = .round
        eraserPreviewLayer.lineJoin = .round
        eraserPreviewLayer.lineWidth = max(1, eraserRadius * 2)
        eraserPreviewLayer.actions = [
            "path": NSNull(),
            "bounds": NSNull(),
            "position": NSNull(),
            "strokeColor": NSNull(),
            "lineWidth": NSNull(),
        ]
        layer.addSublayer(eraserPreviewLayer)

        // --- rect overlay container ---
        rectOverlayContainerLayer.actions = [
            "sublayers": NSNull(),
            "bounds": NSNull(),
            "position": NSNull(),
            "contents": NSNull(),
        ]
        layer.addSublayer(rectOverlayContainerLayer)

        // --- Gestures ---
        addGestureRecognizer(drawPan)
        addGestureRecognizer(stampTap)
        addGestureRecognizer(twoFingerPan)
        addGestureRecognizer(pinch)

        drawPan.delegate = self
        stampTap.delegate = self
        twoFingerPan.delegate = self
        pinch.delegate = self
    }

    // =========================================================
    // MARK: - Layout
    // =========================================================

    public override func layoutSubviews() {
        super.layoutSubviews()

        // ✅ レイヤーフレーム更新で暗黙アニメが乗ると「追従が遅い」に見えるのでOFF
        withoutImplicitAnimations {
            committedContainerLayer.frame = bounds
            currentStrokeLayer.frame = bounds
            eraserPreviewLayer.frame = bounds
            rectOverlayContainerLayer.frame = bounds
        }
    }

    // =========================================================
    // MARK: - Gesture delegate
    // =========================================================

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    /// “どのモードでどのジェスチャを開始してよいか” をここで制御
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer)
        -> Bool
    {

        // 2本指系は常に有効
        if gestureRecognizer === twoFingerPan { return true }
        if gestureRecognizer === pinch { return true }

        // 1本指描画はモードに応じてON/OFF
        if gestureRecognizer === drawPan {
            return (mode == .pen || mode == .eraser)
        }
        if gestureRecognizer === stampTap {
            return (mode == .stamp)
        }

        return true
    }

    // =========================================================
    // MARK: - Public
    // =========================================================

    public func undo() {
        guard let cmd = history.undo() else { return }
        applyReverse(cmd)

        // undo/redo は要素の増減があるので全再描画
        redrawCommittedElements()
    }

    public func redo() {
        guard let cmd = history.redo() else { return }
        apply(cmd, recordToHistory: false)

        // undo/redo は要素の増減があるので全再描画
        redrawCommittedElements()
    }

    public func clear() {
        elements.removeAll()
        history.clear()

        withoutImplicitAnimations {
            committedContainerLayer.sublayers?.removeAll()
            currentStrokeLayer.path = nil
            eraserPreviewLayer.path = nil

            overlayRects.removeAll()
            rectOverlayContainerLayer.sublayers?.removeAll()
        }
    }

    public func exportImage(scale: CGFloat = UIScreen.main.scale) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
        return renderer.image { ctx in
            layer.render(in: ctx.cgContext)
        }
    }

    // =========================================================
    // MARK: - ZoomPan 追従（外から呼ばれる想定）
    // =========================================================

    public func refreshForViewportChange() {
        // ✅ 追従遅れを減らす：暗黙アニメOFF + レイヤー再構築の一瞬を防ぐ
        withoutImplicitAnimations {
            redrawCommittedElements()  // 変換が変わるので確定レイヤは引き直す必要あり
            redrawOverlayRects()  // 矩形も追従

            if !currentPoints.isEmpty { updateCurrentStrokePreview() }
            if !eraserPathPoints.isEmpty { updateEraserStrokePreview() }
        }
    }

    // =========================================================
    // MARK: - Overlay Rect Public API（要件：Undo/Redo不要）
    // =========================================================

    /// 画像座標（canvas座標）で矩形を差し替える
    public func setOverlayRects(_ rects: [CanvasRect]) {
        overlayRects = rects
        redrawOverlayRects()
    }

    public func appendOverlayRect(_ rect: CanvasRect) {
        overlayRects.append(rect)
        redrawOverlayRects()
    }

    public func clearOverlayRects() {
        overlayRects.removeAll()
        redrawOverlayRects()
    }

    // =========================================================
    // MARK: - Serialize / Deserialize（elements を保存）
    // =========================================================

    public func exportDrawingData() throws -> Data {
        let envelopes = try elements.map { try ElementEnvelope.fromElement($0) }
        let doc = DrawingDocument(version: 2, elements: envelopes)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(doc)
    }

    public func importDrawingData(_ data: Data) throws {
        let decoder = JSONDecoder()
        guard let doc2 = try? decoder.decode(DrawingDocument.self, from: data) else {
            throw NSError(
                domain: "DrawingKit",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported drawing data format"]
            )
        }

        elements = doc2.elements.compactMap { $0.toElement() }
        history.clear()

        // 変換に合わせて全再描画
        redrawCommittedElements()
    }

    public func exportMergedImage(baseImage: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = baseImage.scale  // ★元画像と同じ scale
        format.opaque = false

        let size = baseImage.size  // ★元画像と同じ size（ポイント表現だけどOK）
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { ctx in
            // 1) 元画像
            baseImage.draw(in: CGRect(origin: .zero, size: size))

            // 2) ペン＆スタンプ（画像座標で描く）
            for el in elements {
                switch el {
                case .stroke(let s):
                    drawStrokeForExport(s, in: ctx.cgContext)
                case .stamp(let s):
                    drawStampForExport(s, in: ctx.cgContext)
                }
            }

            // 3) 必要なら overlayRects も合成（欲しければON）
            // drawOverlayRectsForExport(in: ctx.cgContext)
        }
    }

    private func drawStrokeForExport(_ stroke: Stroke, in cg: CGContext) {
        guard stroke.points.count >= 2 else { return }

        cg.saveGState()
        defer { cg.restoreGState() }

        cg.setLineCap(.round)
        cg.setLineJoin(.round)
        cg.setStrokeColor(stroke.style.color.withAlphaComponent(stroke.style.opacity).cgColor)
        cg.setLineWidth(stroke.style.lineWidth)  // ★画像座標の太さ

        cg.beginPath()
        cg.move(to: stroke.points[0])
        for p in stroke.points.dropFirst() {
            cg.addLine(to: p)
        }
        cg.strokePath()
    }

    private func drawStampForExport(_ stamp: Stamp, in cg: CGContext) {
        cg.saveGState()
        defer { cg.restoreGState() }

        let color = stamp.style.color.withAlphaComponent(stamp.style.opacity).cgColor
        cg.setStrokeColor(color)
        cg.setLineWidth(max(2, stamp.style.size * 0.12))  // ★画像座標のサイズ

        let c = stamp.center
        let s = stamp.style.size

        switch stamp.kind {
        case .check:
            let p1 = CGPoint(x: c.x - s * 0.30, y: c.y + s * 0.05)
            let p2 = CGPoint(x: c.x - s * 0.10, y: c.y + s * 0.25)
            let p3 = CGPoint(x: c.x + s * 0.35, y: c.y - s * 0.20)

            cg.beginPath()
            cg.move(to: p1)
            cg.addLine(to: p2)
            cg.addLine(to: p3)
            cg.strokePath()

        case .cross:
            let a = CGPoint(x: c.x - s * 0.30, y: c.y - s * 0.30)
            let b = CGPoint(x: c.x + s * 0.30, y: c.y + s * 0.30)
            let d = CGPoint(x: c.x + s * 0.30, y: c.y - s * 0.30)
            let e = CGPoint(x: c.x - s * 0.30, y: c.y + s * 0.30)

            cg.beginPath()
            cg.move(to: a)
            cg.addLine(to: b)
            cg.move(to: d)
            cg.addLine(to: e)
            cg.strokePath()

        case .circle:
            let rect = CGRect(
                x: c.x - s * 0.35, y: c.y - s * 0.35, width: s * 0.70, height: s * 0.70)
            cg.strokeEllipse(in: rect)
        }
    }

    // =========================================================
    // MARK: - Input (1 finger)
    // =========================================================

    @objc private func handleStampTap(_ g: UITapGestureRecognizer) {
        guard mode == .stamp else { return }

        let pView = g.location(in: self)
        let pCanvas = viewPointToCanvasPoint?(pView) ?? pView

        var st = stampStyle
        if let conv = viewLengthToCanvasLength {
            st.size = conv(stampStyle.size)
        }
        let stamp = Stamp(kind: stampKind, center: pCanvas, style: st)

        apply(.add(.stamp(stamp)), recordToHistory: true)

        // ✅ ちらつき対策：確定時に全再描画しない（差分で1枚追加）
        withoutImplicitAnimations {
            commitStamp(stamp)
        }
    }

    @objc private func handleDrawPan(_ g: UIPanGestureRecognizer) {
        let pView = g.location(in: self)
        let pCanvas = viewPointToCanvasPoint?(pView) ?? pView

        switch mode {
        case .pen:
            handlePenPan(g, point: pCanvas)
        case .eraser:
            handleEraserPan(g, point: pCanvas)
        default:
            break
        }
    }

    // =========================================================
    // MARK: - Input (2 fingers -> delegate to Zoom)
    // =========================================================

    @objc private func handleTwoFingerPan(_ g: UIPanGestureRecognizer) {
        onTwoFingerPan?(g)
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        onPinch?(g)
    }

    // =========================================================
    // MARK: - Pen
    // =========================================================

    private func handlePenPan(_ g: UIPanGestureRecognizer, point p: CGPoint) {
        switch g.state {
        case .began:
            currentPoints = [p]
            updateCurrentStrokePreview()

        case .changed:
            currentPoints.append(p)
            updateCurrentStrokePreview()

        case .ended, .cancelled, .failed:
            if currentPoints.count >= 2 {
                var style = penStyle
                if let conv = viewLengthToCanvasLength {
                    style.lineWidth = conv(penStyle.lineWidth)
                }
                let stroke = Stroke(points: currentPoints, style: style)
                apply(.add(.stroke(stroke)), recordToHistory: true)

                // ✅ ちらつき対策：確定時に全再描画しない（差分で1枚追加）
                withoutImplicitAnimations {
                    commitStroke(stroke)
                }
            }

            currentPoints.removeAll()
            withoutImplicitAnimations {
                currentStrokeLayer.path = nil
            }

        default:
            break
        }
    }

    private func updateCurrentStrokePreview() {
        withoutImplicitAnimations {
            currentStrokeLayer.strokeColor =
                penStyle.color.withAlphaComponent(penStyle.opacity).cgColor
            currentStrokeLayer.lineWidth = penStyle.lineWidth
            currentStrokeLayer.lineCap = .round
            currentStrokeLayer.lineJoin = .round
            currentStrokeLayer.path = makePath(points: currentPoints)
        }
    }

    // =========================================================
    // MARK: - Eraser（軌跡線プレビュー + リアルタイム消去）
    // =========================================================

    private func handleEraserPan(_ g: UIPanGestureRecognizer, point p: CGPoint) {
        switch g.state {
        case .began:
            erasingIDs.removeAll()
            erasingRemovedItems.removeAll()

            eraserPathPoints = [p]
            updateEraserStrokePreview()
            eraseHitTestAndApply(at: p)

        case .changed:
            eraserPathPoints.append(p)
            updateEraserStrokePreview()
            eraseHitTestAndApply(at: p)

        case .ended, .cancelled, .failed:
            withoutImplicitAnimations {
                eraserPreviewLayer.path = nil
            }
            eraserPathPoints.removeAll()

            // 消した内容を Undo できるよう、ここで履歴確定
            if !erasingRemovedItems.isEmpty {
                let cmd = DrawingCommand.erase(
                    EraseCommand(removed: erasingRemovedItems.sorted { $0.index < $1.index })
                )
                history.push(cmd)
            }

            erasingIDs.removeAll()
            erasingRemovedItems.removeAll()

        default:
            break
        }
    }

    private func updateEraserStrokePreview() {
        withoutImplicitAnimations {
            eraserPreviewLayer.lineWidth = max(1, eraserRadius * 2)

            guard eraserPathPoints.count >= 2 else {
                eraserPreviewLayer.path = nil
                return
            }

            func toView(_ p: CGPoint) -> CGPoint {
                canvasPointToViewPoint?(p) ?? p
            }

            let path = UIBezierPath()
            path.move(to: toView(eraserPathPoints[0]))
            for p in eraserPathPoints.dropFirst() {
                path.addLine(to: toView(p))
            }
            eraserPreviewLayer.path = path.cgPath
        }
    }

    /// ヒットした要素を“その場で消す”（リアルタイム）
    private func eraseHitTestAndApply(at p: CGPoint) {
        guard !elements.isEmpty else { return }

        let scale = max(0.0001, viewToCanvasScale)
        let r = eraserRadius / scale

        var hitIndices: [Int] = []
        for (idx, el) in elements.enumerated() {
            let id = el.id
            if erasingIDs.contains(id) { continue }

            if hit(element: el, eraserCenter: p, radius: r) {
                erasingIDs.insert(id)
                hitIndices.append(idx)
            }
        }

        guard !hitIndices.isEmpty else { return }

        for idx in hitIndices.sorted(by: >) {
            let el = elements[idx]
            erasingRemovedItems.append(RemovedItem(index: idx, element: el))
            elements.remove(at: idx)
        }

        // ✅ 消しゴムは“削除”があるので安全に全再描画
        redrawCommittedElements()
    }

    private func hit(element: DrawingElement, eraserCenter p: CGPoint, radius r: CGFloat) -> Bool {
        switch element {
        case .stroke(let s):
            return strokeHitsEraser(stroke: s, center: p, radius: r)
        case .stamp(let s):
            return stampHitsEraser(stamp: s, center: p, radius: r)
        }
    }

    private func stampHitsEraser(stamp: Stamp, center p: CGPoint, radius r: CGFloat) -> Bool {
        let stampR = stamp.style.size * 0.5
        let dx = stamp.center.x - p.x
        let dy = stamp.center.y - p.y
        return (dx * dx + dy * dy) <= (stampR + r) * (stampR + r)
    }

    private func strokeHitsEraser(stroke: Stroke, center p: CGPoint, radius r: CGFloat) -> Bool {
        let pts = stroke.points
        guard pts.count >= 2 else { return false }

        let effectiveR = r + stroke.style.lineWidth * 0.5

        for i in 0..<(pts.count - 1) {
            if distancePointToSegment(p, pts[i], pts[i + 1]) <= effectiveR {
                return true
            }
        }
        return false
    }

    private func distancePointToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let ap = CGPoint(x: p.x - a.x, y: p.y - a.y)

        let abLen2 = ab.x * ab.x + ab.y * ab.y
        if abLen2 == 0 {
            let dx = p.x - a.x
            let dy = p.y - a.y
            return sqrt(dx * dx + dy * dy)
        }

        var t = (ap.x * ab.x + ap.y * ab.y) / abLen2
        t = max(0, min(1, t))

        let closest = CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t)
        let dx = p.x - closest.x
        let dy = p.y - closest.y
        return sqrt(dx * dx + dy * dy)
    }

    // =========================================================
    // MARK: - Commands（Undo/Redoの核）
    // =========================================================

    private func apply(_ cmd: DrawingCommand, recordToHistory: Bool) {
        if recordToHistory { history.push(cmd) }

        switch cmd {
        case .add(let el):
            elements.append(el)

        case .erase(let erase):
            for item in erase.removed.sorted(by: { $0.index > $1.index }) {
                if item.index < elements.count, elements[item.index].id == item.element.id {
                    elements.remove(at: item.index)
                } else if let i = elements.firstIndex(where: { $0.id == item.element.id }) {
                    elements.remove(at: i)
                }
            }
        }
    }

    private func applyReverse(_ cmd: DrawingCommand) {
        switch cmd {
        case .add(let el):
            if let i = elements.lastIndex(where: { $0.id == el.id }) {
                elements.remove(at: i)
            }

        case .erase(let erase):
            for item in erase.removed.sorted(by: { $0.index < $1.index }) {
                let idx = min(max(0, item.index), elements.count)
                elements.insert(item.element, at: idx)
            }
        }
    }

    // =========================================================
    // MARK: - Rendering（確定要素）
    // =========================================================

    /// 変換が変わった時（ズームパン）や、Undo/Redo/消しゴム等で“整合”を取りたい時に使う
    private func redrawCommittedElements() {
        withoutImplicitAnimations {
            committedContainerLayer.sublayers?.removeAll()

            for element in elements {
                switch element {
                case .stroke(let s):
                    commitStroke(s)
                case .stamp(let s):
                    commitStamp(s)
                }
            }
        }
    }

    private func commitStroke(_ stroke: Stroke) {
        let l = CAShapeLayer()
        l.fillColor = UIColor.clear.cgColor
        l.strokeColor = stroke.style.color.withAlphaComponent(stroke.style.opacity).cgColor

        // 画像座標で保存している lineWidth を View(pt) に戻す
        let wView: CGFloat =
            canvasLengthToViewLength?(stroke.style.lineWidth) ?? stroke.style.lineWidth
        l.lineWidth = wView

        l.lineCap = .round
        l.lineJoin = .round
        l.path = makePath(points: stroke.points)
        l.actions = ["path": NSNull(), "strokeColor": NSNull(), "lineWidth": NSNull()]
        committedContainerLayer.addSublayer(l)
    }

    private func commitStamp(_ stamp: Stamp) {
        let l = CAShapeLayer()
        l.fillColor = UIColor.clear.cgColor
        l.strokeColor = stamp.style.color.withAlphaComponent(stamp.style.opacity).cgColor

        let sView: CGFloat = canvasLengthToViewLength?(stamp.style.size) ?? stamp.style.size
        l.lineWidth = max(2, sView * 0.12)

        l.lineCap = .round
        l.lineJoin = .round
        l.actions = ["path": NSNull(), "strokeColor": NSNull(), "lineWidth": NSNull()]

        let c = canvasPointToViewPoint?(stamp.center) ?? stamp.center
        let path = UIBezierPath()
        let s = sView

        switch stamp.kind {
        case .check:
            let p1 = CGPoint(x: c.x - s * 0.30, y: c.y + s * 0.05)
            let p2 = CGPoint(x: c.x - s * 0.10, y: c.y + s * 0.25)
            let p3 = CGPoint(x: c.x + s * 0.35, y: c.y - s * 0.20)
            path.move(to: p1)
            path.addLine(to: p2)
            path.addLine(to: p3)

        case .cross:
            let a = CGPoint(x: c.x - s * 0.30, y: c.y - s * 0.30)
            let b = CGPoint(x: c.x + s * 0.30, y: c.y + s * 0.30)
            let d = CGPoint(x: c.x + s * 0.30, y: c.y - s * 0.30)
            let e = CGPoint(x: c.x - s * 0.30, y: c.y + s * 0.30)
            path.move(to: a)
            path.addLine(to: b)
            path.move(to: d)
            path.addLine(to: e)

        case .circle:
            let rect = CGRect(
                x: c.x - s * 0.35, y: c.y - s * 0.35, width: s * 0.70, height: s * 0.70)
            path.append(UIBezierPath(ovalIn: rect))
        }

        l.path = path.cgPath
        committedContainerLayer.addSublayer(l)
    }

    private func makePath(points: [CGPoint]) -> CGPath? {
        guard let firstRaw = points.first else { return nil }

        func toView(_ p: CGPoint) -> CGPoint {
            canvasPointToViewPoint?(p) ?? p
        }

        let path = UIBezierPath()
        path.move(to: toView(firstRaw))
        for p in points.dropFirst() {
            path.addLine(to: toView(p))
        }
        return path.cgPath
    }

    public func cancelAllGestures() {
        gestureRecognizers?.forEach { g in
            g.isEnabled = false
            g.isEnabled = true
        }
    }

    // =========================================================
    // MARK: - Overlay Rect Rendering（追従）
    // =========================================================

    private func redrawOverlayRects() {
        withoutImplicitAnimations {
            rectOverlayContainerLayer.sublayers?.removeAll()
            guard !overlayRects.isEmpty else { return }

            for r in overlayRects {
                let l = CAShapeLayer()
                l.strokeColor = r.style.strokeColor.cgColor
                l.lineWidth = max(0.5, r.style.strokeWidth)
                l.lineJoin = .round
                l.fillColor = fillColor(from: r.style.fill)

                l.actions = [
                    "path": NSNull(),
                    "strokeColor": NSNull(),
                    "fillColor": NSNull(),
                    "lineWidth": NSNull(),
                ]

                l.path = makeRectPathInView(fromCanvasRect: r.rect)
                rectOverlayContainerLayer.addSublayer(l)
            }
        }
    }

    private func fillColor(from fill: RectFill) -> CGColor? {
        switch fill {
        case .none:
            return UIColor.clear.cgColor
        case .solid(let c):
            return c.cgColor
        }
    }

    private func makeRectPathInView(fromCanvasRect rect: CGRect) -> CGPath? {
        let p0 = CGPoint(x: rect.minX, y: rect.minY)
        let p1 = CGPoint(x: rect.maxX, y: rect.minY)
        let p2 = CGPoint(x: rect.maxX, y: rect.maxY)
        let p3 = CGPoint(x: rect.minX, y: rect.maxY)

        func toView(_ p: CGPoint) -> CGPoint? {
            canvasPointToViewPoint?(p) ?? p
        }

        guard
            let v0 = toView(p0),
            let v1 = toView(p1),
            let v2 = toView(p2),
            let v3 = toView(p3)
        else { return nil }

        let path = UIBezierPath()
        path.move(to: v0)
        path.addLine(to: v1)
        path.addLine(to: v2)
        path.addLine(to: v3)
        path.close()
        return path.cgPath
    }

    // =========================================================
    // MARK: - Util（暗黙アニメOFF）
    // =========================================================

    private func withoutImplicitAnimations(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }
}

// =========================================================
// MARK: - DrawingElement id（消しゴム重複判定用）
// =========================================================

extension DrawingElement {
    fileprivate var id: UUID {
        switch self {
        case .stroke(let s): return s.id
        case .stamp(let s): return s.id
        }
    }
}
