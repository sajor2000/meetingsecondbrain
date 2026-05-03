import AVFoundation
import Foundation

protocol MicrophoneCapturing {
    func startRecording(to fileURL: URL?, activityHandler: @escaping (Double) -> Void) async throws
    func stopRecording() async throws
}

final class MicrophoneCaptureEngine: MicrophoneCapturing {
    private let engine = AVAudioEngine()
    private var writer: MicrophoneAudioFileWriter?

    func startRecording(to fileURL: URL?, activityHandler: @escaping (Double) -> Void) async throws {
        guard let fileURL else {
            return
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let writer = MicrophoneAudioFileWriter(fileURL: fileURL)
        try writer.start(format: format)
        self.writer = writer

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            try? writer.write(buffer: buffer)
            activityHandler(Self.level(for: buffer))
        }

        engine.prepare()
        try engine.start()
    }

    func stopRecording() async throws {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        writer?.stop()
        writer = nil
    }

    private static func level(for buffer: AVAudioPCMBuffer) -> Double {
        guard let channelData = buffer.floatChannelData else {
            return 0
        }

        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            return 0
        }

        var sum: Float = 0
        let samples = channelData[0]
        for index in 0..<frameLength {
            let sample = samples[index]
            sum += sample * sample
        }

        return min(1, Double(sqrt(sum / Float(frameLength))))
    }
}
