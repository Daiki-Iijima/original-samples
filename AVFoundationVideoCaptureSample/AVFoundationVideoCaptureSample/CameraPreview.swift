import AVFoundation
import SwiftUI

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        videoPreviewLayer.frame = bounds

        //  iPadは充電器側を右側にした横画面にするので、AVCaptureVideoPreviewLayerで自動補正しないように明示的に指定
        if UIDevice.current.userInterfaceIdiom == .pad {
            videoPreviewLayer.connection?.videoRotationAngle = 0
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    //  外部からセッションを受け取る
    let session: AVCaptureSession

    //  Viewオブジェクトを作成、初期状態の構成
    //  1回だけ呼ばれる
    func makeUIView(context _: Context) -> some UIView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspect
        // .resizeAspect     : 黒帯付きで全部表示（クロップなし）
        // .resizeAspectFill : はみ出す部分はクロップして画面を埋める
        // .resize           : 伸び縮みさせてピッタリ（歪む）

        return view
    }

    //  Viewの状態を更新する
    func updateUIView(_: UIViewType, context _: Context) {}
}
