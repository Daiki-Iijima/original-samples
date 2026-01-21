import UIKit

final class ZoomPanUIView: UIView, UIGestureRecognizerDelegate {

    // MARK: - UI

    private let imageView = UIImageView()

    // MARK: - State

    public var currentViewportState: ViewportState { viewportState }

    private var viewportState = ViewportState.initial

    /// UIKitの状態が変わったらSwiftUIへ通知
    var onViewportChanged: ((ViewportState) -> Void)?

    // MARK: - Config

    /// true: パンは2本指のみ / false: 1〜2本指パン
    var isTwoFingerPanOnly: Bool = false {
        didSet { applyPanTouchPolicy() }
    }

    // MARK: - Gestures (owned by ZoomPanUIView)

    private lazy var panGR: UIPanGestureRecognizer = {
        let g = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        g.maximumNumberOfTouches = 2
        g.cancelsTouchesInView = true
        return g
    }()

    private lazy var pinchGR: UIPinchGestureRecognizer = {
        let g = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        g.cancelsTouchesInView = true
        return g
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .blue

        imageView.layer.anchorPoint = .zero
        imageView.contentMode = .scaleAspectFit
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)

        setupGestures()
        applyPanTouchPolicy()
    }

    private func setupGestures() {
        panGR.delegate = self
        pinchGR.delegate = self
        addGestureRecognizer(panGR)
        addGestureRecognizer(pinchGR)
    }

    private func applyPanTouchPolicy() {
        panGR.minimumNumberOfTouches = isTwoFingerPanOnly ? 2 : 1
        panGR.maximumNumberOfTouches = 2
    }

    // MARK: - Public API

    func setImage(_ image: UIImage) {
        imageView.image = image
        updateDerivedViewportState()
        onViewportChanged?(viewportState)
    }

    func resetViewport() {
        viewportState = .initial
        applyTransformAndNotify()
    }

    func setViewport(scale targetScale: CGFloat, centerInImage targetCenter: CGPoint) {
        guard let image = imageView.image else { return }

        let drawRect = imageDrawingRect(image: image, in: imageView.bounds)
        guard drawRect.width > 0, drawRect.height > 0 else { return }

        // 画像上の座標 → imageViewローカル座標
        let localX = drawRect.minX + (targetCenter.x / image.size.width) * drawRect.width
        let localY = drawRect.minY + (targetCenter.y / image.size.height) * drawRect.height
        let centerInImageView = CGPoint(x: localX, y: localY)

        // ZoomPanUIViewの中心（画面中心）
        let viewCenter = CGPoint(x: bounds.midX, y: bounds.midY)

        viewportState.scale = targetScale
        viewportState.translation = CGPoint(
            x: viewCenter.x - targetScale * centerInImageView.x,
            y: viewCenter.y - targetScale * centerInImageView.y
        )

        applyTransformAndNotify()
    }

    // --- 外部ジェスチャ（Canvas側など）を受けて処理する入口 ---

    func handleExternalPan(_ g: UIPanGestureRecognizer) {
        // translation / location は「ZoomPanUIView座標系」で扱う
        handlePanInternal(g, in: self, isExternal: true)
    }

    func handleExternalPinch(_ g: UIPinchGestureRecognizer) {
        handlePinchInternal(g, in: self, isExternal: true)
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    // MARK: - Gesture handlers (owned)

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        handlePanInternal(g, in: self, isExternal: false)
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        handlePinchInternal(g, in: self, isExternal: false)
    }

    // MARK: - Core gesture logic (shared)

    private func handlePanInternal(_ g: UIPanGestureRecognizer, in view: UIView, isExternal: Bool) {
        // 2本指パン限定モードの場合、途中で指が足りなくなったらキャンセル
        if isTwoFingerPanOnly, g.numberOfTouches < 2 {
            // ownのときだけ確実にキャンセルできる
            if !isExternal {
                panGR.isEnabled = false
                panGR.isEnabled = true
            }
            return
        }

        guard g.state == .began || g.state == .changed else { return }

        let delta = g.translation(in: view)
        g.setTranslation(.zero, in: view)

        viewportState.translation = CGPoint(
            x: viewportState.translation.x + delta.x,
            y: viewportState.translation.y + delta.y
        )

        applyTransformAndNotify()
    }

    private func handlePinchInternal(
        _ g: UIPinchGestureRecognizer, in view: UIView, isExternal: Bool
    ) {
        guard g.state == .began || g.state == .changed else { return }

        let anchorInView = g.location(in: view)

        let scaleDelta = g.scale
        g.scale = 1.0

        let scaleBefore = viewportState.scale
        let translationBefore = viewportState.translation

        // anchor を「画像Viewローカル」座標として扱う（現行方式）
        let anchorInImage = CGPoint(
            x: (anchorInView.x - translationBefore.x) / max(0.0001, scaleBefore),
            y: (anchorInView.y - translationBefore.y) / max(0.0001, scaleBefore)
        )

        let scaleAfter = scaleBefore * scaleDelta

        let translationAfter = CGPoint(
            x: anchorInView.x - (scaleAfter * anchorInImage.x),
            y: anchorInView.y - (scaleAfter * anchorInImage.y)
        )

        viewportState.scale = scaleAfter
        viewportState.translation = translationAfter

        applyTransformAndNotify()
    }

    // MARK: - Transform / Notify

    private func applyTransformAndNotify() {
        applyTransform()
        updateDerivedViewportState()
        onViewportChanged?(viewportState)
    }

    private func applyTransform() {
        let s = viewportState.scale
        let t = viewportState.translation
        imageView.transform = CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: t.x, ty: t.y)
    }

    // MARK: - Geometry helpers

    private func imageDrawingRect(image: UIImage, in imageViewBounds: CGRect) -> CGRect {
        let imageSize = image.size
        let viewSize = imageViewBounds.size

        guard imageSize.width > 0, imageSize.height > 0,
            viewSize.width > 0, viewSize.height > 0
        else { return .zero }

        let scaleW = viewSize.width / imageSize.width
        let scaleH = viewSize.height / imageSize.height
        let scale = min(scaleW, scaleH)

        let w = imageSize.width * scale
        let h = imageSize.height * scale

        let x = (viewSize.width - w) / 2
        let y = (viewSize.height - h) / 2

        return CGRect(x: x, y: y, width: w, height: h)
    }

    // view(画面) → image(画像座標)
    public func viewPointToImagePoint(_ pInView: CGPoint) -> CGPoint? {
        guard let image = imageView.image else { return nil }

        // transform を打ち消して imageView ローカルへ
        let inv = imageView.transform.inverted()
        let pInImageView = pInView.applying(inv)

        let drawRect = imageDrawingRect(image: image, in: imageView.bounds)
        guard drawRect.width > 0, drawRect.height > 0 else { return nil }

        let nx = (pInImageView.x - drawRect.minX) / drawRect.width
        let ny = (pInImageView.y - drawRect.minY) / drawRect.height

        return CGPoint(x: nx * image.size.width, y: ny * image.size.height)
    }

    // image(画像座標) → view(画面)
    public func imagePointToViewPoint(_ pInImage: CGPoint) -> CGPoint? {
        guard let image = imageView.image else { return nil }

        let drawRect = imageDrawingRect(image: image, in: imageView.bounds)
        guard drawRect.width > 0, drawRect.height > 0 else { return nil }

        let localX = drawRect.minX + (pInImage.x / image.size.width) * drawRect.width
        let localY = drawRect.minY + (pInImage.y / image.size.height) * drawRect.height
        let pInImageView = CGPoint(x: localX, y: localY)

        return pInImageView.applying(imageView.transform)
    }

    /// View上の長さ(pt) → 画像座標の長さ(px)（消しゴム等）
    public func viewLengthToImageLength(_ viewLen: CGFloat) -> CGFloat {
        guard let image = imageView.image else { return viewLen }
        let drawRect = imageDrawingRect(image: image, in: imageView.bounds)
        guard drawRect.width > 0, drawRect.height > 0 else { return viewLen }

        let s = max(0.0001, viewportState.scale)
        let kx = (image.size.width / drawRect.width) * (1.0 / s)
        let ky = (image.size.height / drawRect.height) * (1.0 / s)
        return viewLen * min(kx, ky)
    }

    private func updateDerivedViewportState() {
        guard let image = imageView.image else { return }

        // view中心
        let centerInView = CGPoint(x: bounds.midX, y: bounds.midY)
        viewportState.centerInImage =
            viewPointToImagePoint(centerInView)
            ?? CGPoint(x: image.size.width / 2, y: image.size.height / 2)

        // view四隅 -> 画像座標
        let p0 = CGPoint(x: bounds.minX, y: bounds.minY)
        let p1 = CGPoint(x: bounds.maxX, y: bounds.minY)
        let p2 = CGPoint(x: bounds.minX, y: bounds.maxY)
        let p3 = CGPoint(x: bounds.maxX, y: bounds.maxY)

        let pts = [p0, p1, p2, p3].compactMap { viewPointToImagePoint($0) }
        guard !pts.isEmpty else {
            viewportState.visibleRectInImage = .zero
            return
        }

        let minX = pts.map(\.x).min()!
        let maxX = pts.map(\.x).max()!
        let minY = pts.map(\.y).min()!
        let maxY = pts.map(\.y).max()!

        viewportState.visibleRectInImage = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
}
