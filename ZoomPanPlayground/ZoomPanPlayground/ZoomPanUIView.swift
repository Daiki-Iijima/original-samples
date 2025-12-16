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

    private func applyTransform() {
        let s = viewportState.scale
        let t = viewportState.translation
        imageView.transform = CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: t.x, ty: t.y)
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
}
