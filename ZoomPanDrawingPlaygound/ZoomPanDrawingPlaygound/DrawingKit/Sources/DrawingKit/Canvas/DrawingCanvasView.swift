import UIKit

public final class DrawingCanvasView: UIView, UIGestureRecognizerDelegate {

    // MARK: - Public (SwiftUI から設定される)

    public var mode: DrawMode = .pen

    public var penStyle: PenStyle = .initial

    public var stampStyle: StampStyle = .initial
    public var stampKind: StampKind = .check

    /// 消しゴム半径（pt）
    /// - プレビュー線の太さ = 直径(=radius*2) にするので視覚と当たり判定が揃う
    public var eraserRadius: CGFloat = 18 {
        didSet {
            eraserPreviewLayer.lineWidth = max(1, eraserRadius * 2)
        }
    }

    /// View座標 → “描画座標(=画像座標)” への変換（未設定ならそのままView座標）
    public var viewPointToCanvasPoint: ((CGPoint) -> CGPoint?)?

    /// “描画座標(=画像座標)” → View座標（表示用。コミット描画で使う）
    public var canvasPointToViewPoint: ((CGPoint) -> CGPoint?)?

    /// view座標(pt) → canvas座標 へ変換するスケール（例: ズーム倍率）
    /// ※ aspectFit 等が絡むので「単純なscale」では正確にならないことが多い。
    ///    消しゴムの当たり判定は別途 zoom 側変換を使うのが安全。
    public var viewToCanvasScale: CGFloat = 1.0

    // MARK: - 2 finger gestures -> Zoomへ委譲

    /// 2本指パンをZoomへ渡す
    public var onTwoFingerPan: ((UIPanGestureRecognizer) -> Void)?

    /// ピンチをZoomへ渡す
    public var onPinch: ((UIPinchGestureRecognizer) -> Void)?

    // MARK: - State（重要：状態と履歴を分ける）

    /// 現在キャンバス上に存在する要素（最終状態）
    private var elements: [DrawingElement] = []

    /// 操作履歴（Undo/Redo 用）
    private let history = DrawingHistory<DrawingCommand>()

    // MARK: - Pen state

    private var currentPoints: [CGPoint] = []
    private let currentStrokeLayer = CAShapeLayer()

    // MARK: - Layers

    private var committedLayers: [CAShapeLayer] = []

    // MARK: - Eraser state

    /// 消しゴムプレビュー（軌跡線）
    private let eraserPreviewLayer = CAShapeLayer()
    private var eraserPathPoints: [CGPoint] = []

    /// 消しゴム中に「すでに消した要素」を重複ヒットしないように覚えておく
    private var erasingIDs = Set<UUID>()

    /// Undo 用：消した要素と元の位置
    private var erasingRemovedItems: [RemovedItem] = []

    // MARK: - Gestures

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

    // MARK: - Init

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

        // ペンの描き途中プレビュー
        currentStrokeLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(currentStrokeLayer)

        // 消しゴムの軌跡プレビュー（線）
        eraserPreviewLayer.fillColor = UIColor.clear.cgColor
        eraserPreviewLayer.strokeColor = UIColor.black.withAlphaComponent(0.25).cgColor
        eraserPreviewLayer.lineCap = .round
        eraserPreviewLayer.lineJoin = .round
        eraserPreviewLayer.lineWidth = max(1, eraserRadius * 2)
        layer.addSublayer(eraserPreviewLayer)

        // Gestures
        addGestureRecognizer(drawPan)
        addGestureRecognizer(stampTap)
        addGestureRecognizer(twoFingerPan)
        addGestureRecognizer(pinch)

        drawPan.delegate = self
        stampTap.delegate = self
        twoFingerPan.delegate = self
        pinch.delegate = self
    }

    // MARK: - Gesture delegate

    /// 同時認識を許可（2本指パンしながらピンチ等）
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    /// “どのモードでどのジェスチャを開始してよいか” をここで制御
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {

        // 2本指系は常に有効（描画モード中もズーム/パンできる）
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

    // MARK: - Public

    public func undo() {
        guard let cmd = history.undo() else { return }
        applyReverse(cmd)
        redrawAllCommittedElements()
    }

    public func redo() {
        guard let cmd = history.redo() else { return }
        apply(cmd, recordToHistory: false)
        redrawAllCommittedElements()
    }

    public func clear() {
        elements.removeAll()
        history.clear()

        committedLayers.removeAll()
        currentStrokeLayer.path = nil
        eraserPreviewLayer.path = nil
        layer.sublayers?.removeAll(where: { $0 !== currentStrokeLayer && $0 !== eraserPreviewLayer })
    }

    public func exportImage(scale: CGFloat = UIScreen.main.scale) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(bounds: bounds, format: format)
        return renderer.image { ctx in
            layer.render(in: ctx.cgContext)
        }
    }

    // MARK: - Serialize / Deserialize（最終状態 elements を保存）

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
        redrawAllCommittedElements()
    }

    // MARK: - Input (1 finger)

    @objc private func handleStampTap(_ g: UITapGestureRecognizer) {
        guard mode == .stamp else { return }
        let pView = g.location(in: self)
        let pCanvas = viewPointToCanvasPoint?(pView) ?? pView

        let stamp = Stamp(kind: stampKind, center: pCanvas, style: stampStyle)
        apply(.add(.stamp(stamp)), recordToHistory: true)
        redrawAllCommittedElements()
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
    
    public func refreshForViewportChange() {
        // 既存の確定要素を “今の変換” で描き直す
        redrawAllCommittedElements()

        // 描き途中があればプレビューも更新
        if !currentPoints.isEmpty {
            updateCurrentStrokePreview()
        }
        if !eraserPathPoints.isEmpty {
            updateEraserStrokePreview()
        }
    }


    // MARK: - Input (2 fingers -> delegate to Zoom)

    @objc private func handleTwoFingerPan(_ g: UIPanGestureRecognizer) {
        print("[Canvas] twoFingerPan state=\(g.state.rawValue) touches=\(g.numberOfTouches)")
        onTwoFingerPan?(g)
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        print("[Canvas] pinch state=\(g.state.rawValue) touches=\(g.numberOfTouches) scale=\(g.scale)")
        onPinch?(g)
    }

    // MARK: - Pen

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
                let stroke = Stroke(points: currentPoints, style: penStyle)
                apply(.add(.stroke(stroke)), recordToHistory: true)
            }
            currentPoints.removeAll()
            currentStrokeLayer.path = nil
            redrawAllCommittedElements()

        default:
            break
        }
    }

    private func updateCurrentStrokePreview() {
        currentStrokeLayer.strokeColor = penStyle.color.withAlphaComponent(penStyle.opacity).cgColor
        currentStrokeLayer.lineWidth = penStyle.lineWidth
        currentStrokeLayer.lineCap = .round
        currentStrokeLayer.lineJoin = .round
        currentStrokeLayer.path = makePath(points: currentPoints)
    }

    // MARK: - Eraser（軌跡線プレビュー + リアルタイム消去）

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
            eraserPreviewLayer.path = nil
            eraserPathPoints.removeAll()

            // リアルタイムで消した内容を Undo できるよう、ここで“まとめて”履歴に確定
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

        // index降順でremove（ズレ防止）
        for idx in hitIndices.sorted(by: >) {
            let el = elements[idx]
            erasingRemovedItems.append(RemovedItem(index: idx, element: el))
            elements.remove(at: idx)
        }

        redrawAllCommittedElements()
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
        return (dx*dx + dy*dy) <= (stampR + r) * (stampR + r)
    }

    private func strokeHitsEraser(stroke: Stroke, center p: CGPoint, radius r: CGFloat) -> Bool {
        let pts = stroke.points
        guard pts.count >= 2 else { return false }

        // 線の太さ分も考慮
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

        let abLen2 = ab.x*ab.x + ab.y*ab.y
        if abLen2 == 0 {
            let dx = p.x - a.x
            let dy = p.y - a.y
            return sqrt(dx*dx + dy*dy)
        }

        var t = (ap.x*ab.x + ap.y*ab.y) / abLen2
        t = max(0, min(1, t))

        let closest = CGPoint(x: a.x + ab.x * t, y: a.y + ab.y * t)
        let dx = p.x - closest.x
        let dy = p.y - closest.y
        return sqrt(dx*dx + dy*dy)
    }

    // MARK: - Commands（Undo/Redoの核）

    private func apply(_ cmd: DrawingCommand, recordToHistory: Bool) {
        if recordToHistory { history.push(cmd) }

        switch cmd {
        case .add(let el):
            elements.append(el)

        case .erase(let erase):
            // index降順で消す
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
            // index昇順で戻す
            for item in erase.removed.sorted(by: { $0.index < $1.index }) {
                let idx = min(max(0, item.index), elements.count)
                elements.insert(item.element, at: idx)
            }
        }
    }

    // MARK: - Rendering

    private func redrawAllCommittedElements() {
        // 確定レイヤを消して描き直し（v1: まずはシンプルに）
        layer.sublayers?.removeAll(where: { $0 !== currentStrokeLayer && $0 !== eraserPreviewLayer })
        committedLayers.removeAll()

        for element in elements {
            switch element {
            case .stroke(let s):
                commitStroke(s)
            case .stamp(let s):
                commitStamp(s)
            }
        }

        currentStrokeLayer.path = nil
    }

    private func commitStroke(_ stroke: Stroke) {
        let l = CAShapeLayer()
        l.fillColor = UIColor.clear.cgColor
        l.strokeColor = stroke.style.color.withAlphaComponent(stroke.style.opacity).cgColor
        l.lineWidth = stroke.style.lineWidth
        l.lineCap = .round
        l.lineJoin = .round
        l.path = makePath(points: stroke.points)

        layer.insertSublayer(l, below: currentStrokeLayer)
        committedLayers.append(l)
    }

    private func commitStamp(_ stamp: Stamp) {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = stamp.style.color.withAlphaComponent(stamp.style.opacity).cgColor
        layer.lineWidth = max(2, stamp.style.size * 0.12)
        layer.lineCap = .round
        layer.lineJoin = .round

        // 中心を View座標へ変換
        let c = canvasPointToViewPoint?(stamp.center) ?? stamp.center

        let path = UIBezierPath()
        let s = stamp.style.size

        switch stamp.kind {
        case .check:
            let p1 = CGPoint(x: c.x - s * 0.30, y: c.y + s * 0.05)
            let p2 = CGPoint(x: c.x - s * 0.10, y: c.y + s * 0.25)
            let p3 = CGPoint(x: c.x + s * 0.35, y: c.y - s * 0.20)
            path.move(to: p1); path.addLine(to: p2); path.addLine(to: p3)

        case .cross:
            let a = CGPoint(x: c.x - s * 0.30, y: c.y - s * 0.30)
            let b = CGPoint(x: c.x + s * 0.30, y: c.y + s * 0.30)
            let d = CGPoint(x: c.x + s * 0.30, y: c.y - s * 0.30)
            let e = CGPoint(x: c.x - s * 0.30, y: c.y + s * 0.30)
            path.move(to: a); path.addLine(to: b)
            path.move(to: d); path.addLine(to: e)

        case .circle:
            let rect = CGRect(x: c.x - s * 0.35, y: c.y - s * 0.35, width: s * 0.70, height: s * 0.70)
            path.append(UIBezierPath(ovalIn: rect))
        }

        layer.path = path.cgPath
        self.layer.insertSublayer(layer, below: currentStrokeLayer)
        committedLayers.append(layer)
    }

    private func makePath(points: [CGPoint]) -> CGPath? {
        guard let firstRaw = points.first else { return nil }

        func toView(_ p: CGPoint) -> CGPoint {
            canvasPointToViewPoint?(p) ?? p
        }

        let path = UIBezierPath()
        path.move(to: toView(firstRaw))
        for p in points.dropFirst() { path.addLine(to: toView(p)) }
        return path.cgPath
    }
}

// MARK: - DrawingElement id（消しゴム重複判定用）

private extension DrawingElement {
    var id: UUID {
        switch self {
        case .stroke(let s): return s.id
        case .stamp(let s):  return s.id
        }
    }
}
