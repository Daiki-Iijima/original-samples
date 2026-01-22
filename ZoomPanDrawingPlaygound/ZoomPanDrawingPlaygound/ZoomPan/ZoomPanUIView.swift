import UIKit

final class ZoomPanUIView: UIView, UIGestureRecognizerDelegate {

    // MARK: - UI
    private let imageView = UIImageView()

    // MARK: - State
    private var viewportState = ViewportState.initial
    var onViewportChanged: ((ViewportState) -> Void)?

    // MARK: - Gestures
    private lazy var panGR: UIPanGestureRecognizer = {
        let g = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        g.minimumNumberOfTouches = 1
        g.maximumNumberOfTouches = 2
        g.cancelsTouchesInView = true
        g.delegate = self
        return g
    }()

    private lazy var pinchGR: UIPinchGestureRecognizer = {
        let g = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        g.cancelsTouchesInView = true
        g.delegate = self
        return g
    }()

    // Representable から制御したい
    func setOwnGesturesEnabled(_ enabled: Bool) {
        panGR.isEnabled = enabled
        pinchGR.isEnabled = enabled
    }

    func cancelAllGestures() {
        gestureRecognizers?.forEach { g in
            g.isEnabled = false
            g.isEnabled = true
        }
    }

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
        backgroundColor = .clear

        imageView.layer.anchorPoint = .zero
        imageView.contentMode = .scaleAspectFit
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)

        addGestureRecognizer(panGR)
        addGestureRecognizer(pinchGR)
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

        // 画像座標 → imageViewローカル座標
        let localX = drawRect.minX + (targetCenter.x / image.size.width) * drawRect.width
        let localY = drawRect.minY + (targetCenter.y / image.size.height) * drawRect.height
        let centerInImageView = CGPoint(x: localX, y: localY)

        // 画面中心に持ってくる
        let viewCenter = CGPoint(x: bounds.midX, y: bounds.midY)

        viewportState.scale = targetScale
        viewportState.translation = CGPoint(
            x: viewCenter.x - targetScale * centerInImageView.x,
            y: viewCenter.y - targetScale * centerInImageView.y
        )

        applyTransformAndNotify()
    }

    // Canvas側から forward されたジェスチャ
    func handleExternalPan(_ g: UIPanGestureRecognizer) {
        handlePanInternal(g, in: self)
    }

    func handleExternalPinch(_ g: UIPinchGestureRecognizer) {
        handlePinchInternal(g, in: self)
    }

    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }

    // MARK: - Gesture handlers
    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        handlePanInternal(g, in: self)
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        handlePinchInternal(g, in: self)
    }

    private func handlePanInternal(_ g: UIPanGestureRecognizer, in view: UIView) {
        guard g.state == .began || g.state == .changed else { return }

        let delta = g.translation(in: view)
        g.setTranslation(.zero, in: view)

        viewportState.translation = CGPoint(
            x: viewportState.translation.x + delta.x,
            y: viewportState.translation.y + delta.y
        )
        applyTransformAndNotify()
    }

    private func handlePinchInternal(_ g: UIPinchGestureRecognizer, in view: UIView) {
        guard g.state == .began || g.state == .changed else { return }

        let anchorInView = g.location(in: view)

        let scaleDelta = g.scale
        g.scale = 1.0

        let scaleBefore = viewportState.scale
        let translationBefore = viewportState.translation

        // anchor を「画像Viewローカル」として扱う
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

    // MARK: - Geometry
    private func imageDrawingRect(image: UIImage, in imageViewBounds: CGRect) -> CGRect {
        let imageSize = image.size
        let viewSize = imageViewBounds.size
        guard imageSize.width > 0, imageSize.height > 0, viewSize.width > 0, viewSize.height > 0
        else {
            return .zero
        }

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

        // imageViewローカル → 画面（transform適用）
        return pInImageView.applying(imageView.transform)
    }

    private func updateDerivedViewportState() {
        guard let image = imageView.image else { return }

        let centerInView = CGPoint(x: bounds.midX, y: bounds.midY)
        viewportState.centerInImage =
            viewPointToImagePoint(centerInView)
            ?? CGPoint(x: image.size.width / 2, y: image.size.height / 2)

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
