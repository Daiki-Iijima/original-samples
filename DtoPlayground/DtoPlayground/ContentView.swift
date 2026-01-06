import SwiftUI

struct ContentView: View {
    @State private var store = TimelineStore()

    @State private var text: String = ""
    @State private var moodEmoji: String = "😀"
    @State private var intensity: Double = 3

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                inputPanel

                List {
                    if store.unknownCount > 0 {
                        Section {
                            Text("未対応の投稿タイプが \(store.unknownCount) 件あります（壊さず保持中）")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        ForEach(store.posts) { post in
                            row(post)
                        }
                    }
                }
            }
            .navigationTitle("Mini Timeline")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("未知を混ぜる") { store.injectUnknown() }
                    Button("全削除") { store.clearAllAndSave() }
                }
            }
            .onAppear { store.load() }
        }
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("ひとこと", text: $text)
                    .textFieldStyle(.roundedBorder)

                Button("投稿") {
                    store.addText(text)
                    text = ""
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 10) {
                Picker("気分", selection: $moodEmoji) {
                    Text("😀").tag("😀")
                    Text("😇").tag("😇")
                    Text("😡").tag("😡")
                    Text("😭").tag("😭")
                    Text("🤯").tag("🤯")
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("強さ \(Int(intensity))")
                    Slider(value: $intensity, in: 1...5, step: 1)
                        .frame(maxWidth: 160)
                }

                Button("スタンプ") {
                    store.addMood(emoji: moodEmoji, intensity: Int(intensity))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func row(_ post: Post) -> some View {
        switch post {
        case .text(let p):
            VStack(alignment: .leading, spacing: 4) {
                Text(p.message)
                Text(p.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .mood(let p):
            HStack(spacing: 10) {
                Text(p.emoji).font(.largeTitle)
                VStack(alignment: .leading, spacing: 4) {
                    Text("強さ: " + String(repeating: "★", count: p.intensity))
                    Text(p.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
