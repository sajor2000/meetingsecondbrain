import AVFoundation
import Foundation

final class MicrophoneAudioFileWriter {
    private let fileURL: URL
    private var audioFile: AVAudioFile?

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func start(format: AVAudioFormat) throws {
        audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)
    }

    func write(buffer: AVAudioPCMBuffer) throws {
        try audioFile?.write(from: buffer)
    }

    func stop() {
        audioFile = nil
    }
}

final class SampleBufferAudioFileWriter {
    private let fileURL: URL
    private var audioFile: AVAudioFile?

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func append(_ sampleBuffer: CMSampleBuffer) throws {
        let buffer = try makePCMBuffer(from: sampleBuffer)
        if audioFile == nil {
            audioFile = try AVAudioFile(forWriting: fileURL, settings: buffer.format.settings)
        }

        try audioFile?.write(from: buffer)
    }

    func stop() {
        audioFile = nil
    }

    private func makePCMBuffer(from sampleBuffer: CMSampleBuffer) throws -> AVAudioPCMBuffer {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            throw AudioFileWriterError.missingSystemAudioFormat
        }
        let format = AVAudioFormat(cmAudioFormatDescription: formatDescription)

        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioFileWriterError.cannotCreateSystemAudioBuffer
        }
        buffer.frameLength = frameCount

        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frameCount),
            into: buffer.mutableAudioBufferList
        )
        guard status == noErr else {
            throw AudioFileWriterError.cannotCopySystemAudioData(status)
        }

        return buffer
    }
}

enum AudioFileWriterError: Error, LocalizedError {
    case missingSystemAudioFormat
    case cannotCreateSystemAudioBuffer
    case cannotCopySystemAudioData(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingSystemAudioFormat:
            return "System audio sample is missing an audio format."
        case .cannotCreateSystemAudioBuffer:
            return "System audio buffer could not be created."
        case let .cannotCopySystemAudioData(status):
            return "System audio sample could not be copied. Status \(status)."
        }
    }
}

enum AudioFileWriter {
    static func mixAudioTracks(
        systemAudioURL: URL?,
        microphoneAudioURL: URL?,
        outputDirectory: URL
    ) async throws -> URL? {
        let result = try await mixAudioTracksWithDiagnostics(
            systemAudioURL: systemAudioURL,
            microphoneAudioURL: microphoneAudioURL,
            outputDirectory: outputDirectory
        )
        return result.outputURL
    }

    static func mixAudioTracksWithDiagnostics(
        systemAudioURL: URL?,
        microphoneAudioURL: URL?,
        outputDirectory: URL
    ) async throws -> AudioMixResult {
        let urls = [systemAudioURL, microphoneAudioURL].compactMap { $0 }
        var diagnostics = RecordingMixDiagnostics(
            attempted: true,
            inputFileCount: urls.count,
            insertedTrackCount: 0,
            skippedInputCount: 0,
            lastInputError: nil,
            outputPath: nil,
            exportStatus: nil,
            exportError: nil
        )

        guard !urls.isEmpty else {
            diagnostics.exportStatus = "no-inputs"
            return AudioMixResult(outputURL: nil, diagnostics: diagnostics)
        }

        let composition = AVMutableComposition()
        for url in urls {
            do {
                let asset = AVURLAsset(url: url)
                let tracks = try await asset.loadTracks(withMediaType: .audio)
                let duration = try await asset.load(.duration)
                guard let sourceTrack = tracks.first else {
                    diagnostics.skippedInputCount += 1
                    continue
                }
                guard let compositionTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else {
                    diagnostics.skippedInputCount += 1
                    continue
                }
                try compositionTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: sourceTrack,
                    at: .zero
                )
                diagnostics.insertedTrackCount += 1
            } catch {
                diagnostics.skippedInputCount += 1
                diagnostics.lastInputError = "\(url.lastPathComponent): \(error.localizedDescription)"
            }
        }

        guard diagnostics.insertedTrackCount > 0 else {
            diagnostics.exportStatus = "no-audio-tracks"
            return AudioMixResult(outputURL: nil, diagnostics: diagnostics)
        }

        let outputURL = outputDirectory.appendingPathComponent("mixed.m4a")
        diagnostics.outputPath = outputURL.path
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            diagnostics.exportStatus = "export-session-unavailable"
            return AudioMixResult(outputURL: nil, diagnostics: diagnostics)
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        await exportSession.export()

        diagnostics.exportStatus = exportSession.status.diagnosticName
        diagnostics.exportError = exportSession.error?.localizedDescription
        let completedURL = exportSession.status == .completed ? outputURL : nil
        return AudioMixResult(outputURL: completedURL, diagnostics: diagnostics)
    }
}

struct AudioMixResult: Equatable, Sendable {
    let outputURL: URL?
    let diagnostics: RecordingMixDiagnostics
}

private extension AVAssetExportSession.Status {
    var diagnosticName: String {
        switch self {
        case .unknown:
            return "unknown"
        case .waiting:
            return "waiting"
        case .exporting:
            return "exporting"
        case .completed:
            return "completed"
        case .failed:
            return "failed"
        case .cancelled:
            return "cancelled"
        @unknown default:
            return "unrecognized"
        }
    }
}
