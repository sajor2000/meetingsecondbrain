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

    static func fromEnvironment() -> ConvexRecallOSRepository? {
        guard let url = ProcessInfo.processInfo.environment["CONVEX_URL"], !url.isEmpty else {
            return nil
        }
        return ConvexRecallOSRepository(deploymentURL: url)
    }
}
