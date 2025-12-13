import AVFoundation
import Combine
import CoreImage
import SwiftUI // UIDeviceでデバイス判定のためにインポート

//  カメラから取得した名前のピクセル情報を渡す
protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ service: CameraService, didOutput pixelBuffer: CVPixelBuffer)
}

final class CameraService: NSObject, ObservableObject {
    //  カメラとのやり取りを仲介する
    //  外部に公開する
    let session = AVCaptureSession()

    //  カメラ映像ハンドリング処理に渡すデリゲート
    weak var cameraServiceDelegate: CameraServiceDelegate?

    //  メインスレッドで処理しないように別スレッドを用意
    private let cameraSessionQueue = DispatchQueue(label: "camera-session")

    override init() {
        super.init()

        cameraSessionQueue.async { [weak self] in
            //  セッションの設定
            self?.configureSession()
            //  セッション開始
            self?.session.startRunning()
        }
    }

    private func configureSession() {
        //  設定開始
        session.beginConfiguration()

        //  解像度
        session.sessionPreset = .hd1920x1080

        //  ビデオデバイス(ハード)の指定と取得
        //  AVCaptureDeviceInputの生成
        //  入力として使えるかチェック
        guard
            let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .back
            ),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            //  だめだったら設定を終了させて戻す
            session.commitConfiguration()
            return
        }

        //  入力デバイスを追加
        session.addInput(input)

        //  出力先の生成
        let output = AVCaptureVideoDataOutput()
        //  処理していないフレームが蓄積した場合古いフレームを破棄する
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            //  ピクセルバッファの色の順番をBGRAに指定
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA,
        ]

        //  ビデオ出力用のキューを生成
        let outputQueue = DispatchQueue(label: "video-output")

        //  サンプルバッファの処理キューの紐づけ
        output.setSampleBufferDelegate(self, queue: outputQueue)

        //  生成した出力先にアウトプットが設定できるかチェック
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }

        //  outputをセッションに登録
        session.addOutput(output)

        //  設定終了(反映)
        session.commitConfiguration()
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // フレーム画像を使った処理
        //  iPadは横画面(充電ポートが右)のフレームがくるのでそのまま
        //  iPhoneは縦画面のフレームだが、横画面(充電ポートが右)に回転したフレームがくるので90度回転して縦にする
        if UIDevice.current.userInterfaceIdiom == .phone {
            connection.videoRotationAngle = 90
        }

        //  サンプルバッファからピクセルバッファを取得
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        //  デリゲートで処理ピクセルバッファを伝達
        cameraServiceDelegate?.cameraService(self, didOutput: pixelBuffer)
    }
}
