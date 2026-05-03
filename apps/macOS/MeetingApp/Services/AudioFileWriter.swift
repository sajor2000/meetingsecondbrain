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
        let urls = [systemAudioURL, microphoneAudioURL].compactMap { $0 }
        guard !urls.isEmpty else {
            return nil
        }

        let composition = AVMutableComposition()
        for url in urls {
            let asset = AVURLAsset(url: url)
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let sourceTrack = tracks.first,
                  let compositionTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                  ) else {
                continue
            }

            let duration = try await asset.load(.duration)
            try compositionTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: duration),
                of: sourceTrack,
                at: .zero
            )
        }

        guard !composition.tracks.isEmpty else {
            return nil
        }

        let outputURL = outputDirectory.appendingPathComponent("mixed.m4a")
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            return nil
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        await exportSession.export()

        return exportSession.status == .completed ? outputURL : nil
    }
}
