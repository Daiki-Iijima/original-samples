import SwiftUI
import DrawingKit

/// 未確認部材一覧パネル（ダミーUI）
///
/// - rects: 表示対象の矩形（OperationScreen側で「未確認のみ」などをフィルタして渡す想定）
/// - selectedRectIDs: 選択状態（OperationScreenと共有して Canvas 側のハイライトとも連動させる）
struct UnconfirmedPartsPanelView: View {

    // 表示対象（OperationScreen側でフィルタして渡す）
    let rects: [CanvasRect]

    // OperationScreenの選択と直結（複数選択可）
    @Binding var selectedRectIDs: Set<UUID>

    // 行タップ時：該当Rectへズームさせる（呼び出し元で zoomRequest を発行）
    var onZoom: (CanvasRect) -> Void = { _ in }

    // 下部ボタン押下時：選択中のRect一覧をまとめて返す
    var onCameraCheckback: (_ selected: [CanvasRect]) -> Void = { _ in }
    
    // 行タップ時：そのプロジェクトを開く（画像切替・overlay再描画は呼び出し元がやる）
    var onOpenProject: (_ projectID: String, _ zoomRect: CanvasRect?) -> Void = { _,_  in }

    // 選択があるかどうか（可読性のため）
    private var hasSelection: Bool { !selectedRectIDs.isEmpty }

    /// プロジェクトごとにグルーピングした表示用セクション
    /// - projectID は識別用（安定）
    /// - projectName は表示用（UI）
    private var projectSections: [ProjectSection] {
        let dict = Dictionary(grouping: rects) { $0.projectID }

        return dict.map { (projectID, rects) in
            ProjectSection(
                projectID: projectID,
                projectName: rects.first?.projectName ?? "（不明）",
                rects: rects
            )
        }
        // 表示順は projectName で揃える（ID順にしたいならここを projectID に）
        .sorted { $0.projectName.localizedStandardCompare($1.projectName) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {

            // パネル上部（全体件数・全解除など）
            headerRow

            // 一覧本体
            ScrollView {
                VStack(spacing: 0) {
                    if rects.isEmpty {
                        // 空状態表示
                        Text("未確認の項目がありません")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    } else {
                        // プロジェクト単位のセクション表示
                        ForEach(projectSections) { section in
                            projectHeader(section)

                            ForEach(section.rects) { rect in
                                row(rect)
                                Divider().opacity(0.25)
                            }
                        }
                    }
                }
            }

            // 選択がある時だけチェックバックボタンを表示
            if hasSelection {
                Button {
                    // 選択中のRectを抽出してコールバックに渡す
                    let selected = rects.filter { selectedRectIDs.contains($0.id) }
                    onCameraCheckback(selected)
                } label: {
                    Text("カメラチェックバック")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .foregroundStyle(.black)
                .background(Color.green.opacity(0.65))
            }
        }
    }

    // MARK: - Header (Panel)

    private var headerRow: some View {
        HStack {
            Text("未確認部材数 : \(rects.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // 選択がある時だけ全解除を表示
            if hasSelection {
                Button("全解除") {
                    selectedRectIDs.removeAll()
                }
                .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
    }

    // MARK: - Header (Project Section)

    /// プロジェクト見出し（ヘッダー）
    private func projectHeader(_ section: ProjectSection) -> some View {
        HStack(spacing: 8) {
            Text(section.projectName)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Text("\(section.rects.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color(.systemGray5))
    }

    // MARK: - Row

    /// 1行表示
    /// - 右端チェックは「選択トグル」
    /// - 行タップは「ズーム」（選択は変えない）
    @ViewBuilder
    private func row(_ rect: CanvasRect) -> some View {
        let isSelected = selectedRectIDs.contains(rect.id)

        HStack(spacing: 10) {

            // メイン表示：externalID があればそれを優先
            VStack(alignment: .leading, spacing: 4) {
                Text(primaryTitle(for: rect))
                    .font(.body)
                    .lineLimit(1)

                // externalID があり、かつ name もある場合は補助として name を表示
                if rect.pipeCheckBackID != nil, !rect.name.isEmpty {
                    Text(rect.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // 選択トグル（複数選択OK）
            Button {
                toggle(rect.id)
            } label: {
                Image(systemName: isSelected ? "checkmark.square" : "square")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isSelected
                ? Color.accentColor.opacity(0.12)
                : Color(.systemBackground)
        )
        // 行全体をタップ領域にする（チェックボタン以外のタップでズームしたい）
        .contentShape(Rectangle())
        .onTapGesture {
            // プロジェクトとズームを依頼
            onOpenProject(rect.projectID,rect)
        }
    }

    // MARK: - Helpers

    /// 行の主タイトル
    /// - externalID があれば externalID
    /// - 無ければ name
    /// - name も無ければプレースホルダ
    private func primaryTitle(for rect: CanvasRect) -> String {
        if let ext = rect.pipeCheckBackID, !ext.isEmpty {
            return ext
        }
        if !rect.name.isEmpty {
            return rect.name
        }
        return "（名称未設定）"
    }

    /// 選択トグル
    private func toggle(_ id: UUID) {
        if selectedRectIDs.contains(id) {
            selectedRectIDs.remove(id)
        } else {
            selectedRectIDs.insert(id)
        }
    }
}

// MARK: - Section Model (View internal)

/// View内でだけ使う、プロジェクト単位のセクションモデル
private struct ProjectSection: Identifiable {
    let projectID: String
    let projectName: String
    let rects: [CanvasRect]

    var id: String { projectID }
}

#Preview {
    UnconfirmedPartsPanelPreviewHost()
}

private struct UnconfirmedPartsPanelPreviewHost: View {
    @State private var selected: Set<UUID> = []

    // Preview用のダミーデータ
    private let rects: [CanvasRect] = SampleData.overlayRects
        .filter { !$0.isHidden && !$0.isChecked }  // 未確認だけ表示したいなら

    var body: some View {
        UnconfirmedPartsPanelView(
            rects: rects,
            selectedRectIDs: $selected,
            onZoom: { rect in
                print("onZoom:", rect.pipeCheckBackID ?? rect.name)
            },
            onCameraCheckback: { selectedRects in
                print("onCameraCheckback count:", selectedRects.count)
            },
            onOpenProject: { pid, rect in
                print("onOpenProject:", pid, rect?.pipeCheckBackID ?? rect?.name ?? "-")
            }
        )
    }
}
