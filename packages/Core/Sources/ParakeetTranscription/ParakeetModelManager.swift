import Foundation

#if canImport(FluidAudio)
import FluidAudio
#endif

public struct ParakeetModelManager: Sendable {
    public enum ModelChoice: String, Sendable {
        case englishV2 = "parakeet-tdt-0.6b-v2"
        case multilingualV3 = "parakeet-tdt-0.6b-v3"
    }

    public static let fluidAudioPackageURL = "https://github.com/FluidInference/FluidAudio.git"
    public static let pinnedFluidAudioVersion = "0.14.3"

    public static func modelChoice(forLanguage language: String) -> ModelChoice {
        let normalized = language
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalized.isEmpty || normalized == "en" || normalized.hasPrefix("en-") {
            return .englishV2
        }

        return .multilingualV3
    }

    #if canImport(FluidAudio)
    static func modelVersion(forLanguage language: String) -> AsrModelVersion {
        switch modelChoice(forLanguage: language) {
        case .englishV2:
            return .v2
        case .multilingualV3:
            return .v3
        }
    }
    #endif
}
