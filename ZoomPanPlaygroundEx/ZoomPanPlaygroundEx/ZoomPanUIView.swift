import UIKit

final class ZoomPanUIView: UIView, UIGestureRecognizerDelegate {
    //  UIKit標準の画像表示コンポーネント
    private let imageView = UIImageView()

    //  UIKit側で保持する状態の構造体
    private var viewportState = ViewportState.initial

    //  UIKitの状態が変わったらSwiftUIへ通知するためのコールバック
    var onViewportChanged: ((ViewportState) -> Void)?

    //  2本指でのみパン移動できるようにする
    var isTwoFingerPanOnly: Bool = false
    //  Pinchと違って判定処理があるのでここで初期化してしまう
    private lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))

    //  == 初期化 ==
    //  コードから作られるケース
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    //  Storyboard/XIBから復元されるケース
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    //  初期化時セットアップ
    private func setup() {
        backgroundColor = .blue

        //  アンカーポイントを左上にして移動がずれないように
        imageView.layer.anchorPoint = .zero

        //  アスペクト比を保って表示できる最大サイズで表示
        imageView.contentMode = .scaleAspectFit
        //  親ビュー(bounds)と同じ大きさ、位置に画像を配置する
        imageView.frame = bounds
        //  親ビューのサイズが変更された場合に追従させる
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        //  イメージをビューに追加
        addSubview(imageView)

        //  ジェスチャーを設定
        setupGesture()
    }

    //  画像を設定
    func setImage(_ image: UIImage) {
        imageView.image = image
    }

    //  ジェスチャーのハンドリグ設定
    private func setupGesture() {
        //  2本指ズーム(ピンチ)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))

        //  デリゲートを登録
        pinch.delegate = self
        pan.delegate = self

        //  ジェスチャーを登録
        addGestureRecognizer(pinch)
        addGestureRecognizer(pan)
    }
    
    //  リセットする
    func resetViewport() {
        viewportState = .initial
        applyTransform()
        onViewportChanged?(viewportState)
    }

    //  移動を適応する
    private func applyTransform() {
        let s = viewportState.scale
        let t = viewportState.translation
        imageView.transform = CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: t.x, ty: t.y)

        updateDerivedViewportState()
        onViewportChanged?(viewportState)
    }
    
    func setViewport(scale targetScale: CGFloat, centerInImage targetCenter: CGPoint){
        guard let image = imageView.image else { return }
        
        //  aspectFitで画像が表示されている領域を算出
        //  imageViewのローカル座標内の画像のRectを取得
        let drawRect = imageDrawingRect(image: image, in: imageView.bounds)
        guard drawRect.width > 0, drawRect.height > 0 else {
            return
        }
        
        //  指定された画像上の座標 / 画像サイズ = 画像上でどのぐらいの割合の位置にいるか
        //  画像上でどのくらいの割合の位置にいるか * imageViewのサイズ = imageView上では何処の位置なのか
        //  aspectFitによる左上の余白 + imageView上の座標 = 画像上の点はimageViewの中では何処の座標なのか
        let localX = drawRect.minX + (targetCenter.x / image.size.width) * drawRect.width
        let localY = drawRect.minY + (targetCenter.y / image.size.height) * drawRect.height
        
        let centerInImageView = CGPoint(x: localX, y: localY)
        
        //  ZoomPanUIViewの中心を取得(画面中心)
        let viewCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        
        //  scaleをセット
        viewportState.scale = targetScale
        
        // viewCenter = centerInImageView * s + translation になるように translation を決める
        viewportState.translation = CGPoint(
            x: viewCenter.x - targetScale * centerInImageView.x,
            y: viewCenter.y - targetScale * centerInImageView.y
        )

        applyTransform()
        onViewportChanged?(viewportState)
    }

    //  ズームとパン同時にできるように
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    //  指を認識し始めた時に呼ばれる
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === pan {
            if isTwoFingerPanOnly {
                //  開始時点で指の本数が2本以上でないとパンさせない
                return pan.numberOfTouches >= 2
            }
        }

        return true
    }

    //  拡大縮小動作のハンドリング
    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        guard g.state == .began || g.state == .changed else { return }

        //  View上の対象点を取得
        let anchorInView: CGPoint = g.location(in: self)

        //  前のフレームの移動量を1.0としてそこからの倍率
        let scaleDelta: CGFloat = g.scale
        g.scale = 1.0

        //  前フレームのスケール・座標を取得
        let scaleBefore: CGFloat = viewportState.scale
        let tranlationBefor: CGPoint = viewportState.translation

        //  2本指の中心位置の座標が画像上のどこにあるか
        let anchorInImage = CGPoint(
            x: (anchorInView.x - tranlationBefor.x) / scaleBefore,
            y: (anchorInView.y - tranlationBefor.y) / scaleBefore
        )

        //  新しいスケール
        let scaleAfter = scaleBefore * scaleDelta

        //  移動量を求める
        let translationAfter = CGPoint(
            x: anchorInView.x - (scaleAfter * anchorInImage.x),
            y: anchorInView.y - (scaleAfter * anchorInImage.y),
        )

        //  保存
        viewportState.scale = scaleAfter
        viewportState.translation = translationAfter

        applyTransform()
    }

    //  パン動作のハンドリング
    @objc private func handlePan(_ g: UIPanGestureRecognizer) {

        //  2本指パン限定モードの場合は、指が途中で1本から2本に増えても弾く
        if isTwoFingerPanOnly, g.numberOfTouches < 2 {
            //  一旦無効化してすぐに戻して入力をキャンセルする
            pan.isEnabled = false
            pan.isEnabled = true
            return
        }

        guard g.state == .began || g.state == .changed else { return }

        let deltaInView = g.translation(in: self)
        g.setTranslation(.zero, in: self)

        viewportState.translation = CGPoint(
            x: viewportState.translation.x + deltaInView.x,
            y: viewportState.translation.y + deltaInView.y
        )

        applyTransform()
    }

    //  aspectFitした画像が表示されている領域を算出する
    private func imageDrawingRect(image: UIImage, in imageViewBounds: CGRect) -> CGRect {

        let imageSize = image.size
        let viewSize = imageViewBounds.size

        //  画像とビューのサイズが正常ではない場合は0を返す
        guard imageSize.width > 0, imageSize.height > 0,
            viewSize.width > 0, viewSize.height > 0
        else { return .zero }

        //  aspectFitした場合の倍率を計算
        let scaleW = viewSize.width / imageSize.width
        let scaleH = viewSize.height / imageSize.height
        let scale = min(scaleW, scaleH)

        //  aspectFitした場合の画像サイズを計算
        let w = imageSize.width * scale
        let h = imageSize.height * scale

        // 余った領域を計算の左上の座標を計算
        let x = (viewSize.width - w) / 2
        let y = (viewSize.height - h) / 2

        return CGRect(x: x, y: y, width: w, height: h)
    }

    //  viewの座標(画面座標)からimageの座標に変換
    private func viewPointToImagePoint(_ pInView: CGPoint) -> CGPoint? {
        guard let image = imageView.image else { return nil }

        //  imageViewの逆行列を取得
        //  imageViewの移動量やスケールを打ち消す行列
        let inv = imageView.transform.inverted()
        //  引数で受け取ったpInViewの値(View座標)に逆行列をかけて本来のimageView上の座標を算出
        let pInImageView = pInView.applying(inv)

        //  画像が表示されている領域を取得
        let drawRect = imageDrawingRect(image: image, in: imageView.bounds)
        guard drawRect.width > 0, drawRect.height > 0 else {
            return nil
        }

        //  imageView上に表示されている画像上の座標を算出
        //  画像内の相対位置として、正規化
        let nx = (pInImageView.x - drawRect.minX) / drawRect.width
        let ny = (pInImageView.y - drawRect.minY) / drawRect.height

        //  正規化した値を元の画像座標の数値に戻す
        return CGPoint(x: nx * image.size.width, y: ny * image.size.height)
    }

    private func updateDerivedViewportState() {
        guard let image = imageView.image else { return }

        // view中心
        let centerInView = CGPoint(x: bounds.midX, y: bounds.midY)
        viewportState.centerInImage =
            viewPointToImagePoint(centerInView)
            ?? CGPoint(x: image.size.width / 2, y: image.size.height / 2)

        // viewの表示範囲（四隅）を画像座標へ
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
