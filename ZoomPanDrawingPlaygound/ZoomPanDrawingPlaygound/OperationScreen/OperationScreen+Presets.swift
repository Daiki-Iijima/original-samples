import DrawingKit
import SwiftUI
import UIKit

extension OperationScreen {

    @ViewBuilder
    var modePanelLayer: some View {
        if interactionMode == .zoomPreset {
            VStack {
                zoomPresetPanel
                Spacer()
            }.padding()
        } else if interactionMode == .rectPreset {
            VStack {
                rectPresetPanel
                Spacer()
            }.padding()
        }
    }

    var zoomPresetPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Zoom指定（画像座標）").font(.headline)
                Spacer()
                Button("閉じる") { interactionMode = .normal }
            }

            HStack {
                numberField("centerX", value: $zoomPreset.centerX, width: 110)
                numberField("centerY", value: $zoomPreset.centerY, width: 110)
                numberField("scale", value: $zoomPreset.scale, width: 90)
            }

            HStack {
                Button("この値でZoom") {
                    zoomRequest = .set(
                        scale: zoomPreset.scale,
                        centerInImage: CGPoint(x: zoomPreset.centerX, y: zoomPreset.centerY)
                    )
                }

                Button("中心を現在表示中心に") {
                    zoomPreset.centerX = viewportState.centerInImage.x
                    zoomPreset.centerY = viewportState.centerInImage.y
                }

                Spacer()
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    var rectPresetPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("矩形追加（overlay / 画像座標）").font(.headline)
                Spacer()
                Button("閉じる") { interactionMode = .normal }
            }

            HStack {
                numberField("centerX", value: $rectPreset.centerX, width: 110)
                numberField("centerY", value: $rectPreset.centerY, width: 110)
            }

            HStack {
                numberField("width", value: $rectPreset.width, width: 110)
                numberField("height", value: $rectPreset.height, width: 110)
            }

            HStack {
                Button("矩形を追加") { appendOverlayRectFromPreset() }
                Button("全部クリア") {
                    overlayRects.removeAll()
                    selectedRectIDs.removeAll()
                }
                Spacer()
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func appendOverlayRectFromPreset() {
        let rect = CGRect(
            x: rectPreset.centerX - rectPreset.width * 0.5,
            y: rectPreset.centerY - rectPreset.height * 0.5,
            width: rectPreset.width,
            height: rectPreset.height
        )

        let style = CanvasRectStyle(
            strokeColor: .systemYellow,
            strokeWidth: 3,
            fill: .solid(UIColor.systemYellow.withAlphaComponent(0.15))
        )

        overlayRects.append(
            CanvasRect(
                externalID: nil,
                name: "新規Rect",
                isChecked: false,
                isHidden: false,
                rect: rect,
                style: style
            )
        )
    }

    func numberField(_ title: String, value: Binding<CGFloat>, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(
                title,
                text: Binding(
                    get: { String(format: "%.2f", value.wrappedValue) },
                    set: { newText in
                        let filtered = newText.replacingOccurrences(of: ",", with: ".")
                        if let v = Double(filtered) {
                            value.wrappedValue = CGFloat(v)
                        }
                    }
                )
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
            .keyboardType(.decimalPad)
        }
    }
}
