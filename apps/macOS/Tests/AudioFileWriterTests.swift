import AVFoundation
import XCTest
@testable import MeetingApp

final class AudioFileWriterTests: XCTestCase {
    func testMicrophoneWriterClosesWithoutBuffers() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("empty.caf")
        let format = AVAudioFormat(
            standardFormatWithSampleRate: 44_100,
            channels: 1
        )!
        let writer = MicrophoneAudioFileWriter(fileURL: fileURL)

        try writer.start(format: format)
        writer.stop()

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
