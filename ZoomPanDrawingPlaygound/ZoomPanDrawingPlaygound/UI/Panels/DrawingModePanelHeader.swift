import DrawingKit
import SwiftUI

struct DrawingModePanelHeader: View {
    let drawMode: DrawMode

    var body: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
            Text(titleText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.001))
    }

    private var titleText: String {
        switch drawMode {
        case .pen: return "ペンモード"
        case .stamp: return "スタンプモード"
        case .eraser: return "消しゴムモード"
        case .none: return "描画OFF"
        }
    }

}
