import Foundation

/// “整合したデータセット” を一箇所で作る
/// - payload と stub の元になる seed 群をここで決める
public enum ProjectSeedCollectionFactory {

    /// entry + links を必ず整合した状態で返す
    public static func makeLinkProjects(
        entryProjectID: String,
        entrySeed: String,
        linkCount: Int = 6
    ) -> (entry: ProjectSeed, all: [ProjectSeed]) {

        let entry = ProjectSeedFactory.make(
            projectID: entryProjectID,
            seed: "\(entrySeed)-entry",
            name: "エントリープロジェクト"
        )

        let links: [ProjectSeed] = (0..<linkCount).map { i in
            let pid = "\(entryProjectID)-LINK-\(i+1)"
            let seed = "\(entrySeed)-link-\(i+1)"
            return ProjectSeedFactory.make(
                projectID: pid,
                seed: seed,
                name: "リンクプロジェクト\(i+1)"
            )
        }

        return (entry: entry, all: [entry] + links)
    }
}
