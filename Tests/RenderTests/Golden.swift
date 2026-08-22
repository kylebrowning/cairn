import Foundation
import Testing

/// Compares rendered SVG against a checked-in golden file.
/// `UPDATE_GOLDENS=1 swift test` regenerates.
func assertGolden(
    _ name: String, _ rendered: String,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let dir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Golden")
    let file = dir.appendingPathComponent("\(name).svg")
    if ProcessInfo.processInfo.environment["UPDATE_GOLDENS"] == "1" {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try rendered.write(to: file, atomically: true, encoding: .utf8)
        return
    }
    guard let expected = try? String(contentsOf: file, encoding: .utf8) else {
        Issue.record(
            "missing golden \(name).svg — run UPDATE_GOLDENS=1 swift test",
            sourceLocation: sourceLocation)
        return
    }
    if rendered != expected {
        // Write the actual output next to the golden for easy diffing.
        let actual = dir.appendingPathComponent("\(name).actual.svg")
        try? rendered.write(to: actual, atomically: true, encoding: .utf8)
        Issue.record(
            "rendered SVG differs from Golden/\(name).svg (actual written to \(name).actual.svg)",
            sourceLocation: sourceLocation)
    }
}
