import Foundation

struct ManualEvidenceSummaryBuilder {
    func build(
        artifact: RecordingArtifact,
        audioRows: [AudioInspectionRow],
        loadResult: RecordingArtifactLoadResult?,
        transcriptionArtifact: TranscriptionArtifact?
    ) -> String {
        var lines: [String] = [
            "## Phase 2 Evidence",
            "",
            "- Session ID: \(artifact.sessionId)",
            "- Artifact folder: \(artifact.directoryURL.path)",
            "- Started at: \(formatDate(artifact.startedAt))",
            "- Ended at: \(artifact.endedAt.map(formatDate) ?? "Not recorded")",
            "- Recording duration: \(artifact.duration.map(formatDuration) ?? "Unknown")",
            "",
            "### Files",
            fileLine("System audio", artifact.systemAudioURL, row: row(.system, in: audioRows)),
            fileLine("Microphone audio", artifact.microphoneAudioURL, row: row(.microphone, in: audioRows)),
            fileLine("Mixed audio", artifact.mixedAudioURL, row: row(.mixed, in: audioRows)),
            fileLine("Metadata", artifact.metadataURL, row: nil),
            fileLine("Transcript JSON", transcriptJSONURL(loadResult: loadResult, transcriptionArtifact: transcriptionArtifact), row: nil),
            fileLine("Transcript markdown", transcriptMarkdownURL(loadResult: loadResult, transcriptionArtifact: transcriptionArtifact), row: nil),
            "",
            "### Manual Checks",
            "- System audio audible:",
            "- Microphone audio audible:",
            "- Mixed audio audible:",
            "- Transcript timestamp quality:",
            "- Speaker label quality:",
            "- Notes:",
            ""
        ]

        let warnings = loadResult?.warnings ?? []
        if !warnings.isEmpty {
            lines.append("### Warnings")
            lines.append(contentsOf: warnings.map { "- \($0.errorDescription ?? "Artifact warning")" })
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func fileLine(_ label: String, _ url: URL?, row: AudioInspectionRow?) -> String {
        guard let url else {
            return "- \(label): missing"
        }

        if let row {
            let state = row.exists ? "present" : "missing"
            let duration = row.duration.map(formatDuration) ?? "duration unknown"
            let size = row.byteSize.map(formatBytes) ?? "size unknown"
            return "- \(label): \(state), \(duration), \(size), \(url.path)"
        }

        return "- \(label): \(url.path)"
    }

    private func row(_ kind: AudioArtifactKind, in rows: [AudioInspectionRow]) -> AudioInspectionRow? {
        rows.first { $0.kind == kind }
    }

    private func transcriptJSONURL(
        loadResult: RecordingArtifactLoadResult?,
        transcriptionArtifact: TranscriptionArtifact?
    ) -> URL? {
        transcriptionArtifact?.jsonURL ?? loadResult?.transcriptJSONURL
    }

    private func transcriptMarkdownURL(
        loadResult: RecordingArtifactLoadResult?,
        transcriptionArtifact: TranscriptionArtifact?
    ) -> URL? {
        transcriptionArtifact?.markdownURL ?? loadResult?.transcriptMarkdownURL
    }

    private func formatDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
