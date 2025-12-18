//
//  ContentView.swift
//  DrawingPlayground
//
//  DrawingKit の動作確認用 UI。
//  - Pen / Stamp / Eraser のモード切替
//  - ペン/スタンプ/消しゴムのパラメータ調整
//  - Undo/Redo/Clear/Export
//
//  SwiftUI は「状態（@State）を変更するとUIが再構築される」ので、
//  UIの各種設定値は @State で持つのが基本。
//  それを DrawingCanvasRepresentable に渡して UIKit 側へ反映する。
//

import SwiftUI
import DrawingKit

struct ContentView: View {

    // UIKit View 参照（Undo/Redo/Exportなどの“命令系”に使う）
    @State private var canvas: DrawingCanvasView? = nil

    // モード
    @State private var mode: DrawMode = .pen

    // 共通色（まずは簡単に：ペン/スタンプ共通にしてる）
    @State private var color: Color = .red

    // Pen 設定
    @State private var lineWidth: CGFloat = 4
    @State private var penOpacity: Double = 1.0

    // Stamp 設定
    @State private var stampKind: StampKind = .check
    @State private var stampSize: CGFloat = 36
    @State private var stampOpacity: Double = 1.0

    // Eraser 設定（★追加：SwiftUIから変更できる）
    @State private var eraserRadius: CGFloat = 18

    // Export
    @State private var exported: UIImage? = nil
    @State private var showExport = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // UIKit の DrawingCanvasView を SwiftUI の View として表示
            DrawingCanvasRepresentable(
                mode: mode,

                penStyle: PenStyle(
                    color: UIColor(color),
                    lineWidth: lineWidth,
                    opacity: CGFloat(penOpacity)
                ),

                stampKind: stampKind,
                stampStyle: StampStyle(
                    color: UIColor(color),
                    size: stampSize,
                    opacity: CGFloat(stampOpacity)
                ),

                // ★SwiftUIから消しゴム半径を調整できる
                eraserRadius: eraserRadius,

                canvasRef: $canvas
            )
            .ignoresSafeArea()
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                // モード切替
                Button("Pen") { mode = .pen }
                Button("Stamp") { mode = .stamp }
                Button("Eraser") { mode = .eraser }
                Button("None") { mode = .none }

                Spacer()

                // 命令系：UIKit参照から呼ぶ
                Button("Undo") { canvas?.undo() }
                Button("Redo") { canvas?.redo() }
                Button("Clear") { canvas?.clear() }

                Spacer()

                Button("Export") {
                    exported = canvas?.exportImage()
                    showExport = (exported != nil)
                }
            }
        }
        .overlay(alignment: .top) {
            controls.padding()
        }
        .sheet(isPresented: $showExport) {
            if let img = exported {
                VStack {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding()

                    Button("Close") { showExport = false }
                        .padding()
                }
            }
        }
    }

    // 上部の調整パネル（モードに応じて出すUIを切替）
    private var controls: some View {
        VStack(spacing: 12) {

            // 共通色
            HStack {
                Text("Color")
                ColorPicker("", selection: $color)
                    .labelsHidden()
            }

            // Pen 設定
            if mode == .pen {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("LineWidth")
                        Slider(value: $lineWidth, in: 1...20)
                    }
                    HStack {
                        Text("Opacity")
                        Slider(value: $penOpacity, in: 0.1...1.0)
                    }
                }
            }

            // Stamp 設定
            if mode == .stamp {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("", selection: $stampKind) {
                        Text("✓").tag(StampKind.check)
                        Text("✕").tag(StampKind.cross)
                        Text("○").tag(StampKind.circle)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Size")
                        Slider(value: $stampSize, in: 12...120)
                    }
                    HStack {
                        Text("Opacity")
                        Slider(value: $stampOpacity, in: 0.1...1.0)
                    }
                }
            }

            // Eraser 設定（★ここが今回の追加）
            if mode == .eraser {
                VStack(alignment: .leading, spacing: 8) {
                    // UIとしては “半径” より “太さ” の方が分かりやすいこともあるが、
                    // まずは内部値と一致させるため半径で出す。
                    HStack {
                        Text("EraserRadius")
                        Slider(value: $eraserRadius, in: 6...60)
                    }

                    // 現在値を表示（デバッグ・調整に便利）
                    Text("radius: \(Int(eraserRadius))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}
