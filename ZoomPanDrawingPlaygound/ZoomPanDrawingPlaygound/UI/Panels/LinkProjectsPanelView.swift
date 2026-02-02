import SwiftUI

struct LinkProjectItem: Identifiable {
    let id: String          // projectID
    let name: String
}

struct LinkProjectsPanelView: View {
    let items: [LinkProjectItem]
    var onTap: (LinkProjectItem) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(items) { item in
                    Button {
                        onTap(item)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).font(.body)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Divider().opacity(0.25)
                }
            }
        }
    }
}
