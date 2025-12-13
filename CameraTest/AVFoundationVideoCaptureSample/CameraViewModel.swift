//
//  CameraViewModel.swift
//  CameraTest
//
//  Created by 飯島 大樹 on 2025/12/12.
//

import Combine
import SwiftUI

final class CameraViewModel: ObservableObject, CameraServiceDelegate {
    //  デバッグ表示用
    @Published var debugImage: CGImage?

    let service = CameraService()

    private let context = CIContext()

    init() {
        service.cameraServiceDelegate = self
    }

    func cameraService(_: CameraService, didOutput pixcelBuffer: CVPixelBuffer) {
        //  CIImageの依存はCoreImage
        let ciImage = CIImage(cvPixelBuffer: pixcelBuffer)

        //  生の向きのまま CGImageにする
        let rect = ciImage.extent
        guard let cgImage = CIContext().createCGImage(ciImage, from: rect) else {
            return
        }

        //  UIをいじるのでメインスレッドで動かす
        DispatchQueue.main.async { [weak self] in
            self?.debugImage = cgImage
        }
    }
}
