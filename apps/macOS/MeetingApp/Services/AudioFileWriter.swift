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
    private var assetWriter: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var didStartSession = false

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func append(_ sampleBuffer: CMSampleBuffer) throws {
        if assetWriter == nil {
            try startWriter()
        }

        guard let assetWriter, let input else {
            return
        }

        if !didStartSession {
            assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            didStartSession = true
        }

        if input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        }
    }

    func stop() async {
        guard let assetWriter, let input else {
            return
        }

        input.markAsFinished()
        await withCheckedContinuation { continuation in
            assetWriter.finishWriting {
                continuation.resume()
            }
        }
    }

    private func startWriter() throws {
        let writer = try AVAssetWriter(outputURL: fileURL, fileType: .m4a)
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
        writerInput.expectsMediaDataInRealTime = true

        if writer.canAdd(writerInput) {
            writer.add(writerInput)
        }

        writer.startWriting()
        assetWriter = writer
        input = writerInput
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
