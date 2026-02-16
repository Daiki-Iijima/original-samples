import YamatoAPIKit
import YamatoAppContracts

@MainActor
public final class PipeCheckServiceAdapter: PipeCheckServicing {
    private let services: YamatoServices

    public init(services: YamatoServices) {
        self.services = services
    }

    public func check(projectID: String, pipeName: String) async throws -> [PipeCheckResult] {
        let resp = try await services.pipeCheck.check(projectID: projectID, pipeName: pipeName)
        return resp
    }

    public func checkBack(ids: [String]) async throws -> [PipeCheckBackResult] {
        let resp = try await services.pipeCheck.checkBack(ids: ids)
        return resp
    }
}
