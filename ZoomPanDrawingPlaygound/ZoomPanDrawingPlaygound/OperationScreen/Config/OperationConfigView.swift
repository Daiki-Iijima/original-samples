import SwiftUI

struct OperationConfigView: View {

    @ObservedObject private var store = OperationConfigStore.shared

    /// 編集中のドラフト（保存ボタンで確定）
    @State private var draft: OperationConfig = .default

    var onClose: () -> Void = {}

    var body: some View {
        NavigationStack {
            Form {
                selectionSection
                checkedSection
                unconfirmedSection
                panelWidthSection

                Section {
                    Button(role: .destructive) {
                        store.resetToDefault()
                        draft = store.config
                    } label: {
                        Text("デフォルトに戻す")
                    }
                }
            }
            .navigationTitle("Operation設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { onClose() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.update(draft)
                        onClose()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                draft = store.config
            }
        }
    }

    // MARK: - Sections

    private var selectionSection: some View {
        Section("選択済み矩形") {
            colorRow("線の色", color: $draft.selection.strokeColor)
            sliderRow("線の透明度", value: $draft.selection.strokeAlpha, range: 0...1, format: "%.2f")
            sliderRow("線の太さ", value: $draft.selection.strokeWidth, range: 1...10, format: "%.0f")

            Toggle("背景を塗る", isOn: $draft.selection.fillEnabled)
            colorRow("背景の色", color: $draft.selection.fillColor)
                .disabled(!draft.selection.fillEnabled)
            sliderRow("背景の透明度", value: $draft.selection.fillAlpha, range: 0...1, format: "%.2f")
                .disabled(!draft.selection.fillEnabled)
        }
    }

    private var checkedSection: some View {
        Section("チェック済み矩形（常時表示）") {
            colorRow("線の色", color: $draft.checked.strokeColor)
            sliderRow("線の透明度", value: $draft.checked.strokeAlpha, range: 0...1, format: "%.2f")
            sliderRow("線の太さ", value: $draft.checked.strokeWidth, range: 1...10, format: "%.0f")

            Toggle("背景を塗る", isOn: $draft.checked.fillEnabled)
            colorRow("背景の色", color: $draft.checked.fillColor)
                .disabled(!draft.checked.fillEnabled)
            sliderRow("背景の透明度", value: $draft.checked.fillAlpha, range: 0...1, format: "%.2f")
                .disabled(!draft.checked.fillEnabled)
        }
    }

    private var unconfirmedSection: some View {
        Section("未確認矩形（一覧ONの時だけ）") {
            colorRow("線の色", color: $draft.unconfirmed.strokeColor)
            sliderRow("線の透明度", value: $draft.unconfirmed.strokeAlpha, range: 0...1, format: "%.2f")
            sliderRow("線の太さ", value: $draft.unconfirmed.strokeWidth, range: 1...10, format: "%.0f")

            Toggle("背景を塗る", isOn: $draft.unconfirmed.fillEnabled)
            colorRow("背景の色", color: $draft.unconfirmed.fillColor)
                .disabled(!draft.unconfirmed.fillEnabled)
            sliderRow("背景の透明度", value: $draft.unconfirmed.fillAlpha, range: 0...1, format: "%.2f")
                .disabled(!draft.unconfirmed.fillEnabled)
        }
    }

    private var panelWidthSection: some View {
        Section("パネル横幅（iPad）") {
            sliderRow("ツール選択", value: $draft.panels.drawingTools, range: 240...520, format: "%.0f")
            sliderRow("未確認部材", value: $draft.panels.unconfirmedParts, range: 260...600, format: "%.0f")
            sliderRow("メモ", value: $draft.panels.memo, range: 260...600, format: "%.0f")
            sliderRow("リンク", value: $draft.panels.linkProjects, range: 260...600, format: "%.0f")
        }
    }

    // MARK: - UI Parts

    private func colorRow(_ title: String, color: Binding<HexColor>) -> some View {
        HStack {
            Text(title)
            Spacer()
            ColorPicker(
                "",
                selection: color.asColorBindingLossy(),
                supportsOpacity: false // 透明度は別スライダーで管理
            )
            .labelsHidden()
        }
    }

    private func sliderRow(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title): \(String(format: format, value.wrappedValue))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Slider(value: value, in: range)
        }
        .padding(.vertical, 4)
    }
}
