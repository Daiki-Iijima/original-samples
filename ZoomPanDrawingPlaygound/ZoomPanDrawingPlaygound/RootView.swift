import SwiftUI
import YamatoAPIKit
import YamatoAppContracts

@available(iOS 16.0, *)
struct RootView: View {
    let tokenStore: TokenStore = UserDefaultsTokenStore(key: "auth.token")
    let useMock = true

    @State private var services: YamatoServices? = nil
    @State private var isBooting: Bool = true

    // ✅ ここを “唯一の起点” にする（payload と stub を同じ seed で作る）
    private let entryProjectID: String = "12345"
    private let entrySeed: String = "yamato-demo"

    var body: some View {
        NavigationStack {
            Group {
                if isBooting {
                    ProgressView("初期化中…")
                } else if let services {
                    let payload = PreviewPayloadFactory.makeProjectOpenPayload(
                        projectID: entryProjectID,
                        seed: entrySeed
                    )

                    OperationScreen(
                        services: services,
                        payload: payload,
                        selectedImageURL: payload.selectedDrawingURL ?? payload.project.drawingImageURLs.first ?? URL(string: "https://picsum.photos/seed/fallback/1200/800")!
                    )
                } else {
                    VStack(spacing: 12) {
                        Text("Servicesの初期化に失敗しました")
                        Button("再試行") { boot() }
                    }
                    .padding()
                }
            }
            .task {
                if services == nil { boot() }
            }
        }
    }

    private func boot() {
        isBooting = true
        Task {
            if useMock {
                let s = YamatoMock.makeServices(
                    tokenStore: tokenStore,
                    baseURL: URL(string: "https://mock.local")!
                )

                setupMockStubs(entryProjectID: entryProjectID, seed: entrySeed)

                await MainActor.run {
                    self.services = s
                    self.isBooting = false
                }
            } else {
                let s = await YamatoServices(tokenStore: tokenStore)
                await MainActor.run {
                    self.services = s
                    self.isBooting = false
                }
            }
        }
    }

    private func setupMockStubs(entryProjectID: String, seed: String) {
        YamatoMockAPI.reset()

        // どの endpoint にも当たらない場合の fallback
        MockStubStore.shared.setDefaultStub(.init(statusCode: 200, body: Data("[]".utf8)))

        YamatoMockAPI.presetDynamicTree(
            rootProjects: 6, rootFolders: 2,
            childrenProjects: 3, childrenFolders: 1,
            depth: 1, seed: 42
        )

        // linkProjects も payload も “同じ seed” から生成する
        let (_, seeds) = ProjectSeedCollectionFactory.makeLinkProjects(
            entryProjectID: entryProjectID,
            entrySeed: seed,
            linkCount: 4
        )

        let dtoItems = seeds.map { $0.toProjectStubDTO() }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let body = try! encoder.encode(dtoItems)
        YamatoMockAPI.presetLinkProjects(for: entryProjectID, body: body)
        
        YamatoMockAPI.pipeCheckBackSuccess(
            ids: ["P-002", "P-003"],
            results: [
                .init(
                    pipeCheckID: "P-002",
                    pipeName: "部材2",
                    checkbacked: true,
                    checkbackUser: "ダミーユーザー",
                    checkbackAt: Date()
                ),
                .init(
                    pipeCheckID: "P-003",
                    pipeName: "部材3",
                    checkbacked: true,
                    checkbackUser: "ダミーユーザー",
                    checkbackAt: Date()
                ),
            ],
            delay: 2.0
        )

    }
}
