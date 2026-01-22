import DrawingKit
import SwiftUI

struct DrawingModePanel: View {
    @Binding var drawMode: DrawMode
    @Binding var stampKind: StampKind

    @Binding var color: Color
    @Binding var lineWidth: CGFloat
    @Binding var opacity: CGFloat
    @Binding var eraserRadius: CGFloat

    let onUndo: () -> Void
    let onRedo: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            toolRow
            colorRow
            controls
            bottomRow
        }
        .padding(14)
    }

    // MARK: - Rows

    private var toolRow: some View {
        HStack(spacing: 10) {
            ForEach([DrawMode.pen, .stamp, .eraser], id: \.self) { mode in
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
    private var controls: some View {
        switch drawMode {
        case .pen:
            slider("太さ", $lineWidth, 1...20, format: { "\(Int($0))" })
            slider("透明度", $opacity, 0.1...1.0, format: { String(format: "%.2f", $0) })

        case .stamp:
            stampKindRow
            slider("サイズ", $lineWidth, 10...120, format: { "\(Int($0))" })
            slider("透明度", $opacity, 0.1...1.0, format: { String(format: "%.2f", $0) })

        case .eraser:
            slider("半径", $eraserRadius, 6...60, format: { "\(Int($0))" })

        case .none:
            EmptyView()
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 10) {
            Button("↩︎", action: onUndo).buttonStyle(.borderedProminent)
            Button("↪︎", action: onRedo).buttonStyle(.borderedProminent)

            Spacer()

            Button("保存", action: onSave).buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Parts

    private func slider(
        _ title: String,
        _ value: Binding<CGFloat>,
        _ range: ClosedRange<CGFloat>,
        format: (CGFloat) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title): \(format(value.wrappedValue))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Slider(value: value, in: range)
        }
    }

    private var stampKindRow: some View {
        HStack(spacing: 10) {
            stampButton(.check, label: "✓")
            stampButton(.cross, label: "✕")
            stampButton(.circle, label: "○")
        }
    }

    private func stampButton(_ kind: StampKind, label: String) -> some View {
        Button {
            stampKind = kind
        } label: {
            Text(label)
                .font(.system(size: 20, weight: .bold))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            stampKind == kind
                                ? Color.orange.opacity(0.25) : Color.gray.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }
}
