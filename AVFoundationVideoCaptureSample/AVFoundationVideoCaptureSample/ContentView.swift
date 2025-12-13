//
//  ContentView.swift
//  CameraTest
//
//  Created by 飯島 大樹 on 2025/12/10.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        ZStack {
            //  通常のPreviewlayer
            CameraPreview(session: viewModel.service.session)
                .ignoresSafeArea()

            if let cgImage = viewModel.debugImage {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(
                            decorative: cgImage,
                            scale: 1.0,
                            orientation: .up
                        )  // ここもあえて回さない
                        .resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 160)
                        .padding(8)
                        .background(.black.opacity(0.6))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
