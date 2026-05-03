import AVFoundation
import Foundation
import ScreenCaptureKit

protocol SystemAudioCapturing {
    func startRecording(to fileURL: URL?, activityHandler: @escaping (Double) -> Void) async throws
    func stopRecording() async throws
}

final class SystemAudioCaptureEngine: NSObject, SystemAudioCapturing {
    private var stream: SCStream?
    private var writer: SampleBufferAudioFileWriter?
    private var activityHandler: ((Double) -> Void)?
    private let sampleQueue = DispatchQueue(label: "meeting-second-brain.system-audio")

    func startRecording(to fileURL: URL?, activityHandler: @escaping (Double) -> Void) async throws {
        guard let fileURL else {
            return
        }

        self.activityHandler = activityHandler
        writer = SampleBufferAudioFileWriter(fileURL: fileURL)

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let display = content.displays.first else {
            throw SystemAudioCaptureError.noDisplayAvailable
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = false
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stopRecording() async throws {
        guard let stream else {
            return
        }

        try await stream.stopCapture()
        writer?.stop()
        writer = nil
        self.stream = nil
        activityHandler = nil
    }
}

extension SystemAudioCaptureEngine: SCStreamOutput {
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .audio, sampleBuffer.isValid else {
            return
        }

        try? writer?.append(sampleBuffer)
        activityHandler?(Self.level(for: sampleBuffer))
    }

    private static func level(for sampleBuffer: CMSampleBuffer) -> Double {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return 0
        }

        let length = CMBlockBufferGetDataLength(blockBuffer)
        guard length > 0 else {
            return 0
        }

        var data = [UInt8](repeating: 0, count: length)
        CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: &data)
        let average = data.reduce(0) { $0 + Int($1) } / max(data.count, 1)
        return min(1, Double(average) / 255)
    }
}

enum SystemAudioCaptureError: Error, LocalizedError {
    case noDisplayAvailable

    var errorDescription: String? {
        switch self {
        case .noDisplayAvailable:
            return "No display is available for system audio capture."
        }
    }
}
