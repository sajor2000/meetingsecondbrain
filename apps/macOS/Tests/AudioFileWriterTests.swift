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

    func testSystemWriterClosesWithoutBuffers() {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("system.caf")
        let writer = SampleBufferAudioFileWriter(fileURL: fileURL)

        writer.stop()

        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testMixDiagnosticsReportNoInputs() async throws {
        let directory = try makeTemporaryDirectory()

        let result = try await AudioFileWriter.mixAudioTracksWithDiagnostics(
            systemAudioURL: nil,
            microphoneAudioURL: nil,
            outputDirectory: directory
        )

        XCTAssertNil(result.outputURL)
        XCTAssertTrue(result.diagnostics.attempted)
        XCTAssertEqual(result.diagnostics.inputFileCount, 0)
        XCTAssertEqual(result.diagnostics.insertedTrackCount, 0)
        XCTAssertEqual(result.diagnostics.skippedInputCount, 0)
        XCTAssertEqual(result.diagnostics.exportStatus, "no-inputs")
    }

    func testMixDiagnosticsReportNoAudioTracks() async throws {
        let directory = try makeTemporaryDirectory()
        let invalidURL = directory.appendingPathComponent("not-audio.txt")
        try Data("not audio".utf8).write(to: invalidURL)

        let result = try await AudioFileWriter.mixAudioTracksWithDiagnostics(
            systemAudioURL: invalidURL,
            microphoneAudioURL: nil,
            outputDirectory: directory
        )

        XCTAssertNil(result.outputURL)
        XCTAssertEqual(result.diagnostics.inputFileCount, 1)
        XCTAssertEqual(result.diagnostics.insertedTrackCount, 0)
        XCTAssertEqual(result.diagnostics.skippedInputCount, 1)
        XCTAssertEqual(result.diagnostics.exportStatus, "no-audio-tracks")
        XCTAssertTrue(result.diagnostics.lastInputError?.contains("not-audio.txt") == true)
    }

    func testMixDiagnosticsSkipBadInputAndExportValidInput() async throws {
        let directory = try makeTemporaryDirectory()
        let invalidURL = directory.appendingPathComponent("not-audio.txt")
        let validURL = directory.appendingPathComponent("valid.caf")
        try Data("not audio".utf8).write(to: invalidURL)
        try writeSilentAudio(to: validURL)

        let result = try await AudioFileWriter.mixAudioTracksWithDiagnostics(
            systemAudioURL: invalidURL,
            microphoneAudioURL: validURL,
            outputDirectory: directory
        )

        XCTAssertEqual(result.outputURL, directory.appendingPathComponent("mixed.m4a"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.outputURL?.path ?? ""))
        XCTAssertEqual(result.diagnostics.inputFileCount, 2)
        XCTAssertEqual(result.diagnostics.insertedTrackCount, 1)
        XCTAssertEqual(result.diagnostics.skippedInputCount, 1)
        XCTAssertEqual(result.diagnostics.exportStatus, "completed")
        XCTAssertTrue(result.diagnostics.lastInputError?.contains("not-audio.txt") == true)
    }

    func testMixDiagnosticsReportExportFailure() async throws {
        let directory = try makeTemporaryDirectory()
        let validURL = directory.appendingPathComponent("valid.caf")
        let missingOutputDirectory = directory.appendingPathComponent("missing", isDirectory: true)
        try writeSilentAudio(to: validURL)

        let result = try await AudioFileWriter.mixAudioTracksWithDiagnostics(
            systemAudioURL: validURL,
            microphoneAudioURL: nil,
            outputDirectory: missingOutputDirectory
        )

        XCTAssertNil(result.outputURL)
        XCTAssertEqual(result.diagnostics.inputFileCount, 1)
        XCTAssertEqual(result.diagnostics.insertedTrackCount, 1)
        XCTAssertEqual(result.diagnostics.skippedInputCount, 0)
        XCTAssertNotEqual(result.diagnostics.exportStatus, "completed")
        XCTAssertNotNil(result.diagnostics.exportError)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeSilentAudio(to url: URL) throws {
        let format = AVAudioFormat(
            standardFormatWithSampleRate: 44_100,
            channels: 1
        )!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frameCount: AVAudioFrameCount = 4_410
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        try file.write(from: buffer)
    }
}
