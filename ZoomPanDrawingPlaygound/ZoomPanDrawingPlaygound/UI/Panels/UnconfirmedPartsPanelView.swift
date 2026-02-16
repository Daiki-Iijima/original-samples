import SwiftUI
import DrawingKit

enum UnconfirmedPartsPanelMode: Equatable {
    case review
    case checkbackSelect
}

struct UnconfirmedPartsPanelView: View {

    let rects: [CanvasRect]
    @Binding var selectedRectIDs: Set<UUID>
    let mode: UnconfirmedPartsPanelMode
    let actionButtonText: String

    ///  追加：チェックバック送信中の pipeCheckID 群（表示用）
    var checkingPipeIDs: Set<String> = []

    var onZoom: (CanvasRect) -> Void = { _ in }
    var onTapActionButtn: (_ selected: [CanvasRect]) -> Void = { _ in }
    var onOpenProject: (_ projectID: String, _ zoomRect: CanvasRect?) -> Void = { _,_  in }

    private var hasSelection: Bool { !selectedRectIDs.isEmpty }

    private var projectSections: [ProjectSection] {
        let dict = Dictionary(grouping: rects) { $0.projectID }
        return dict.map { (projectID, rects) in
            ProjectSection(
                projectID: projectID,
                projectName: rects.first?.projectName ?? "（不明）",
                rects: rects
            )
        }
        .sorted { $0.projectName.localizedStandardCompare($1.projectName) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow

            ScrollView {
                VStack(spacing: 0) {
                    if rects.isEmpty {
                        Text("未確認の項目がありません")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    } else {
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

            if hasSelection {
                Button {
                    let selected = rects.filter { selectedRectIDs.contains($0.id) }
                    onTapActionButtn(selected)
                } label: {
                    Text(actionButtonText)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .foregroundStyle(.black)
                .background(Color.green.opacity(0.65))
            }
            
            //  チェックバックモードですべてのチェックバックが終わったら表示する要素
            if rects.allSatisfy({$0.isChecked}) && mode == .checkbackSelect{
                Button {
                    //  TODO : アクション
                } label: {
                    Text("再度確認")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .foregroundStyle(.black)
                .background(Color.green.opacity(0.65))
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text("件数 : \(rects.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if hasSelection {
                Button("全解除") { selectedRectIDs.removeAll() }
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
    }

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

    @ViewBuilder
    private func row(_ rect: CanvasRect) -> some View {
        let isSelected = selectedRectIDs.contains(rect.id)
        

        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(primaryTitle(for: rect))
                    .font(.body)
                    .lineLimit(1)

                if rect.pipeCheckBackID != nil, !rect.name.isEmpty {
                    Text(rect.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // checkbackSelect の時だけ追加UI
            if mode == .review{
                Button {
                    toggle(rect.id)
                    print("\(rect.id)")
                } label: {
                    Image(systemName: isSelected ? "checkmark.square" : "square")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
            }

            
            if mode == .checkbackSelect{
                statusIcon(rect)
                
                if !rect.isChecked {
                    Button {
                        toggle(rect.id)
                        print("\(rect.id)")
                    } label: {
                        Image(systemName: isSelected ? "checkmark.square" : "square")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            // ここは review と同じ挙動を維持
            onOpenProject(rect.projectID, rect)
        }
    }

    @ViewBuilder
    private func statusIcon(_ rect: CanvasRect) -> some View {
        let pipeID = rect.pipeCheckBackID ?? ""
        if !pipeID.isEmpty, checkingPipeIDs.contains(pipeID) {
            ProgressView()
                .scaleEffect(0.9)
                .frame(width: 22, height: 22)
        } else if rect.isChecked {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        } else {
            Image(systemName: "circle")
                .font(.title3)
                .foregroundStyle(.yellow)
        }
    }

    private func primaryTitle(for rect: CanvasRect) -> String {
        if let ext = rect.pipeCheckBackID, !ext.isEmpty { return ext }
        if !rect.name.isEmpty { return rect.name }
        return "（名称未設定）"
    }

    private func toggle(_ id: UUID) {
        if selectedRectIDs.contains(id) {
            selectedRectIDs.remove(id)
        } else {
            selectedRectIDs.insert(id)
        }
    }
}

private struct ProjectSection: Identifiable {
    let projectID: String
    let projectName: String
    let rects: [CanvasRect]
    var id: String { projectID }
}
