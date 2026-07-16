import Foundation
import AppKit

/// Copies attachment files into
/// `~/Library/Application Support/InterviewTracker/attachments/` so they
/// survive the original file being moved or deleted.
enum AttachmentStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base
            .appendingPathComponent("InterviewTracker", isDirectory: true)
            .appendingPathComponent("attachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    /// Copy a file in; returns the stored file name.
    static func copyIn(from source: URL) -> String? {
        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension
        let name = "\(UUID().uuidString).\(ext)"
        do {
            try FileManager.default.copyItem(at: source, to: url(for: name))
            return name
        } catch {
            print("AttachmentStore copy failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Save raw image data (e.g. pasted from clipboard) as PNG.
    static func saveImageData(_ data: Data, ext: String = "png") -> String? {
        let name = "\(UUID().uuidString).\(ext)"
        do {
            try data.write(to: url(for: name))
            return name
        } catch {
            print("AttachmentStore save failed: \(error.localizedDescription)")
            return nil
        }
    }

    static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }

    static func image(for fileName: String) -> NSImage? {
        NSImage(contentsOf: url(for: fileName))
    }
}
