import Foundation
import YamatoAPIKit
import YamatoAppContracts

public enum PreviewPayloadFactory {

    public static func makeProjectOpenPayload(
        projectID: String = "P-12-3456-001",
        seed: String = "yamato-demo"
    ) -> ProjectOpenPayload {

        let auth = AuthSession(
            token: "mock-token-\(seed)",
            id: 1,
            name: "Mock User",
            roles: [.admin]
        )

        // payload も “整合済み seed 集合” から作る
        let (entry, _) = ProjectSeedCollectionFactory.makeLinkProjects(
            entryProjectID: projectID,
            entrySeed: seed,
            linkCount: 6
        )

        let project = entry.toDisplayProject()
        let selectedDrawingURL: URL? = entry.drawingImageURLs.first

        let cacheKey: ProjectOpenPayload.CacheKey? = .init(
            projectID: projectID,
            kind: .drawing(url: selectedDrawingURL ?? entry.drawingImageURLs[0])
        )

        return ProjectOpenPayload(
            authSession: auth,
            project: project,
            selectedDrawingURL: selectedDrawingURL,
            cacheKey: cacheKey
        )
    }
}
