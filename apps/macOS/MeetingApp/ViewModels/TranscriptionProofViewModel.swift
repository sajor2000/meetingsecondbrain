import Core
import Foundation

@MainActor
final class TranscriptionProofViewModel: ObservableObject {
    @Published private(set) var state: TranscriptionProofState = .idle

    private let runner: any TranscriptionRunning
    private let config: TranscriptionConfig

    init(
        runner: any TranscriptionRunning = TranscriptionRunner(),
        config: TranscriptionConfig = .english
    ) {
        self.runner = runner
        self.config = config
    }

    var canTranscribe: Bool {
        state.canTranscribe
    }

    func canTranscribe(artifact: RecordingArtifact) -> Bool {
        state.canTranscribe && artifact.mixedAudioURL != nil
    }

    func unavailableReason(for artifact: RecordingArtifact) -> String? {
        artifact.mixedAudioURL == nil ? "Mixed audio file is required." : nil
    }

    var statusText: String {
        switch state {
        case .idle:
            return "Ready to transcribe"
        case .transcribing:
            return "Transcribing"
        case .completed:
            return "Transcription complete"
        case let .failed(_, reason):
            return reason.errorDescription ?? "Transcription failed"
        }
    }

    var completedArtifact: TranscriptionArtifact? {
        if case let .completed(_, artifact) = state {
            return artifact
        }
        return nil
    }

    func reset() {
        guard case .transcribing = state else {
            state = .idle
            return
        }
    }

    func transcribe(artifact: RecordingArtifact) async {
        guard canTranscribe else {
            return
        }

        state = .transcribing(artifact)
        do {
            let transcriptionArtifact = try await runner.transcribe(
                artifact: artifact,
                config: config
            )
            state = .completed(artifact, transcriptionArtifact)
        } catch {
            state = .failed(artifact, TranscriptionProofFailureReason(error: error))
        }
    }
}

enum TranscriptionProofState: Equatable {
    case idle
    case transcribing(RecordingArtifact)
    case completed(RecordingArtifact, TranscriptionArtifact)
    case failed(RecordingArtifact, TranscriptionProofFailureReason)

    var canTranscribe: Bool {
        if case .transcribing = self {
            return false
        }
        return true
    }
}

enum TranscriptionProofFailureReason: Equatable, LocalizedError {
    case missingMixedAudio
    case missingAudioFile(String)
    case transcriptionFailed(String)

    init(error: Error) {
        if let runnerError = error as? TranscriptionRunnerError {
            switch runnerError {
            case .missingMixedAudio:
                self = .missingMixedAudio
            case let .missingAudioFile(path):
                self = .missingAudioFile(path)
            }
            return
        }

        self = .transcriptionFailed(error.localizedDescription)
    }

    var errorDescription: String? {
        switch self {
        case .missingMixedAudio:
            return "Recording artifact does not have a mixed audio file."
        case let .missingAudioFile(path):
            return "Audio file does not exist at \(path)."
        case let .transcriptionFailed(message):
            return message
        }
    }
}
