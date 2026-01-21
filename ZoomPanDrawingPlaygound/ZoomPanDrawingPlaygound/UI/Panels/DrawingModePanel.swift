import DrawingKit
import SwiftUI

struct DrawingModePanel: View {
    @Binding var drawMode: DrawMode

    @Binding var color: Color
    @Binding var lineWidth: CGFloat
    @Binding var opacity: CGFloat
    @Binding var eraserRadius: CGFloat

    // 将来 StampStyle に寄せるならこの辺も増やす
    // @Binding var stampSize: CGFloat
    // @Binding var stampOpacity: CGFloat
    // @Binding var stampKind: StampKind

    let onUndo: () -> Void
    let onRedo: () -> Void
    let onClear: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            toolRow

            colorRow

            toolControls

            bottomRow
        }
        .padding(14)
    }

    private var colorRow: some View {
        HStack {
            Text("右の色をタップで\n色を変更できます")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            ColorPicker("", selection: $color)
                .labelsHidden()
        }
    }

    @ViewBuilder
    private var toolControls: some View {
        switch drawMode {
        case .pen:
            sliderRow(title: "太さ", value: $lineWidth, range: 1...20, display: { "\(Int($0))" })
            sliderRow(
                title: "透明度", value: $opacity, range: 0.1...1.0,
                display: { String(format: "%.2f", $0) })

        case .stamp:
            // まずは暫定で lineWidth を「サイズ扱い」にしてる（後で stampSize に置き換え推奨）
            sliderRow(title: "サイズ", value: $lineWidth, range: 10...120, display: { "\(Int($0))" })
            sliderRow(
                title: "透明度", value: $opacity, range: 0.1...1.0,
                display: { String(format: "%.2f", $0) })

        case .eraser:
            sliderRow(title: "半径", value: $eraserRadius, range: 6...60, display: { "\(Int($0))" })

        case .none:
            EmptyView()
        }
    }

    private var bottomRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button("↩︎") { onUndo() }
                    .buttonStyle(.borderedProminent)

                Button("↪︎") { onRedo() }
                    .buttonStyle(.borderedProminent)

                Spacer()

                Button("保存") { onSave() }
                    .buttonStyle(.borderedProminent)
            }

            //  クリアは使わないのでコメントアウト
            // Button("クリア") { onClear() }
            //     .buttonStyle(.bordered)
            //     .tint(.red)
        }
    }

    private func toolButton(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View
    {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .tint(isOn ? .blue : .gray)
    }

    private func sliderRow(
        title: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        display: (CGFloat) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title): \(display(value.wrappedValue))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Slider(value: value, in: range)
        }
    }

    private var toolRow: some View {
        HStack(spacing: 10) {
            ForEach([DrawMode.pen, .stamp, .eraser], id: \.self) { mode in
                toolIconButton(mode)
            }
        }
    }

    private func toolIconButton(_ mode: DrawMode) -> some View {
        Button {
            drawMode = mode
        } label: {
            Image(systemName: mode.icon)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(drawMode == mode ? Color.blue.opacity(0.25) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

}
