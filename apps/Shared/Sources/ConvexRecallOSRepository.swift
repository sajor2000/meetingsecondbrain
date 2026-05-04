import Foundation

#if os(iOS) && canImport(ConvexMobile)
import ConvexMobile
#endif

struct ConvexRecallOSRepository {
    static let supportsLiveUse = false

    let deploymentURL: String

    init(deploymentURL: String) {
        self.deploymentURL = deploymentURL
    }

    static func fromEnvironment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> ConvexRecallOSRepository? {
        guard let url = environment["CONVEX_URL"], !url.isEmpty else {
            return nil
        }
        return ConvexRecallOSRepository(deploymentURL: url)
    }
}
