import AVFoundation
import Foundation

enum AudioArtifactKind: String, CaseIterable, Sendable {
    case system
    case microphone
    case mixed

    var label: String {
        switch self {
        case .system:
            return "System"
        case .microphone:
            return "Mic"
        case .mixed:
            return "Mixed"
        }
    }
}

struct AudioInspectionRow: Equatable, Identifiable, Sendable {
    let kind: AudioArtifactKind
    let url: URL?
    let exists: Bool
    let byteSize: Int64?
    let duration: TimeInterval?
    let modifiedAt: Date?
    var isPlaying: Bool

    var id: AudioArtifactKind {
        kind
    }

    var label: String {
        kind.label
    }
}

protocol AudioFileInspecting: Sendable {
    func inspect(kind: AudioArtifactKind, url: URL?) -> AudioInspectionRow
}

protocol AudioFilePlaying: AnyObject, Sendable {
    var currentURL: URL? { get }
    var onFinish: (@Sendable () -> Void)? { get set }

    func play(url: URL) throws
    func stop()
}

@MainActor
final class AudioInspectionViewModel: ObservableObject {
    @Published private(set) var rows: [AudioInspectionRow] = []
    @Published private(set) var errorMessage: String?

    private let inspector: AudioFileInspecting
    private let player: AudioFilePlaying

    init(
        inspector: AudioFileInspecting = AudioFileInspector(),
        player: AudioFilePlaying = AVAudioFilePlayer()
    ) {
        self.inspector = inspector
        self.player = player
        self.player.onFinish = { [weak self] in
            Task { @MainActor in
                self?.markPlaybackFinished()
            }
        }
    }

    func load(artifact: RecordingArtifact?) {
        stop()
        guard let artifact else {
            rows = []
            return
        }

        rows = [
            inspector.inspect(kind: .system, url: artifact.systemAudioURL),
            inspector.inspect(kind: .microphone, url: artifact.microphoneAudioURL),
            inspector.inspect(kind: .mixed, url: artifact.mixedAudioURL)
        ]
        errorMessage = nil
    }

    func togglePlayback(for row: AudioInspectionRow) {
        if row.isPlaying {
            stop()
            return
        }

        guard row.exists, let url = row.url else {
            errorMessage = "\(row.label) audio file is missing."
            return
        }

        do {
            try player.play(url: url)
            rows = rows.map { current in
                var updated = current
                updated.isPlaying = current.id == row.id
                return updated
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            stop()
        }
    }

    func stop() {
        player.stop()
        markPlaybackFinished()
    }

    private func markPlaybackFinished() {
        rows = rows.map { current in
            var updated = current
            updated.isPlaying = false
            return updated
        }
    }
}

struct AudioFileInspector: AudioFileInspecting, @unchecked Sendable {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func inspect(kind: AudioArtifactKind, url: URL?) -> AudioInspectionRow {
        guard let url else {
            return AudioInspectionRow(
                kind: kind,
                url: nil,
                exists: false,
                byteSize: nil,
                duration: nil,
                modifiedAt: nil,
                isPlaying: false
            )
        }

        let exists = fileManager.fileExists(atPath: url.path)
        let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        return AudioInspectionRow(
            kind: kind,
            url: url,
            exists: exists,
            byteSize: attributes?[.size] as? Int64,
            duration: exists ? Self.audioDuration(for: url) : nil,
            modifiedAt: attributes?[.modificationDate] as? Date,
            isPlaying: false
        )
    }

    private static func audioDuration(for url: URL) -> TimeInterval? {
        guard let player = try? AVAudioPlayer(contentsOf: url), player.duration.isFinite else {
            return nil
        }
        return player.duration
    }
}

final class AVAudioFilePlayer: NSObject, AudioFilePlaying, AVAudioPlayerDelegate, @unchecked Sendable {
    private var player: AVAudioPlayer?
    var onFinish: (@Sendable () -> Void)?

    var currentURL: URL? {
        player?.url
    }

    func play(url: URL) throws {
        stop()
        let nextPlayer = try AVAudioPlayer(contentsOf: url)
        nextPlayer.delegate = self
        nextPlayer.prepareToPlay()
        nextPlayer.play()
        player = nextPlayer
    }

    func stop() {
        player?.stop()
        player = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedURL = player.url
        DispatchQueue.main.async { [weak self] in
            guard self?.player?.url == finishedURL else {
                return
            }

            self?.player = nil
            self?.onFinish?()
        }
    }
}
