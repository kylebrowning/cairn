import Foundation
import ProfileKit

/// Runs an external plugin executable: JSON `{snapshot, options}` on stdin,
/// a `Card` as JSON on stdout, 20-second timeout.
public struct ExternalPluginRunner: Sendable {
    public var path: String
    public static let timeout: Duration = .seconds(20)

    public init(path: String) {
        self.path = path
    }

    /// The card id for cache purposes — the executable's basename.
    public var id: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    public struct RunError: Error, CustomStringConvertible {
        public var message: String

        public var description: String {
            message
        }
    }

    public func render(_ snapshot: Snapshot, options: PluginOptions) async throws -> Card {
        struct Input: Encodable {
            var snapshot: Snapshot
            var options: PluginOptions
        }
        let input = try Snapshot.encoder().encode(Input(snapshot: snapshot, options: options))

        // A plugin that exits before reading all of stdin must fail cleanly
        // (broken pipe), not kill us with SIGPIPE.
        signal(SIGPIPE, SIG_IGN)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()

        // Feed stdin and drain stdout off the cooperative pool so a large
        // snapshot can't deadlock the pipe buffers.
        let output = try await withThrowingTaskGroup(of: Data?.self) { group in
            group.addTask {
                // A plugin may exit without reading stdin — a broken pipe here
                // is not an error; the exit status decides success.
                try? stdin.fileHandleForWriting.write(contentsOf: input)
                try? stdin.fileHandleForWriting.close()
                return nil
            }
            group.addTask {
                stdout.fileHandleForReading.readDataToEndOfFile()
            }
            group.addTask {
                try await Task.sleep(for: Self.timeout)
                process.terminate()
                throw RunError(message: "external plugin \(path) timed out after \(Self.timeout)")
            }
            var data: Data?
            for _ in 0..<2 {
                if let result = try await group.next(), let result {
                    data = result
                }
            }
            group.cancelAll()
            return data ?? Data()
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let error = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw RunError(message: "external plugin \(path) exited \(process.terminationStatus): \(error.prefix(512))")
        }
        return try Snapshot.decoder().decode(Card.self, from: output)
    }
}
