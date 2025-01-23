//
//  EvernoteNote+Extensions.swift
//  EvernoteKit
//
//  Created by Adam Wulf on 1/22/25.
//
import EvernoteKit
import Foundation
import UniformTypeIdentifiers

public extension EvernoteNote {
    func exportToDirectory(baseNoteDir: String) throws {
        try createDirectoryStructure(baseNoteDir: baseNoteDir)
        try exportLocalizedStrings(baseNoteDir: baseNoteDir)
        try exportJSON(baseNoteDir: baseNoteDir)
        try exportHTML(baseNoteDir: baseNoteDir)
        try exportMarkdown(baseNoteDir: baseNoteDir)
        try exportResources(baseNoteDir: baseNoteDir)
        try setDirectoryDates(baseNoteDir: baseNoteDir)
    }

    private func createDirectoryStructure(baseNoteDir: String) throws {
        let baseLocalizedDir = (baseNoteDir as NSString).appendingPathComponent(".localized")
        let noteDir = (baseNoteDir as NSString).appendingPathComponent("\(id).localized")
        let noteLocalizedDir = (noteDir as NSString).appendingPathComponent(".localized")

        try FileManager.default.createDirectory(atPath: baseNoteDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: baseLocalizedDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: noteDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: noteLocalizedDir, withIntermediateDirectories: true)
    }

    private func exportLocalizedStrings(baseNoteDir: String) throws {
        let baseLocalizedDir = (baseNoteDir as NSString).appendingPathComponent(".localized")
        let baseStringsPath = (baseLocalizedDir as NSString).appendingPathComponent("Base.strings")

        // Read existing strings if any
        var existingStrings = [String: String]()
        if FileManager.default.fileExists(atPath: baseStringsPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: baseStringsPath)),
           let str = String(data: data, encoding: .utf8) {
            let pattern = #""([^"]+)"\s*=\s*"([^"]+)";"#
            let regex = try? NSRegularExpression(pattern: pattern)
            regex?.enumerateMatches(in: str, range: NSRange(str.startIndex..., in: str)) { match, _, _ in
                guard let match = match,
                      let keyRange = Range(match.range(at: 1), in: str),
                      let valueRange = Range(match.range(at: 2), in: str) else { return }
                existingStrings[String(str[keyRange])] = String(str[valueRange])
            }
        }

        // Escape the title for strings file
        let escapedTitle = (title.isEmpty ? id : title)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\t", with: "\\t")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: "")

        // Add/update our note's entry
        existingStrings[id] = escapedTitle

        // Write back strings file
        let stringsContent = existingStrings
            .map { "\"\($0)\" = \"\($1)\";" }
            .sorted()
            .joined(separator: "\n")
        try stringsContent.write(to: URL(fileURLWithPath: baseStringsPath), atomically: true, encoding: .utf8)

        // Create note's Base.strings file
        let noteDir = (baseNoteDir as NSString).appendingPathComponent("\(id).localized")
        let noteLocalizedDir = (noteDir as NSString).appendingPathComponent(".localized")
        let noteStringsPath = (noteLocalizedDir as NSString).appendingPathComponent("Base.strings")
        try "\"\(id)\" = \"\(escapedTitle)\";"
            .write(to: URL(fileURLWithPath: noteStringsPath), atomically: true, encoding: .utf8)
    }

    private func exportJSON(baseNoteDir: String) throws {
        let noteDir = (baseNoteDir as NSString).appendingPathComponent("\(id).localized")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(self)
        try jsonData.write(to: URL(fileURLWithPath: (noteDir as NSString).appendingPathComponent("content.json")))
    }

    private func exportHTML(baseNoteDir: String) throws {
        let noteDir = (baseNoteDir as NSString).appendingPathComponent("\(id).localized")
        try content.write(to: URL(fileURLWithPath: (noteDir as NSString).appendingPathComponent("content.html")),
                         atomically: true,
                         encoding: .utf8)
    }

    private func exportMarkdown(baseNoteDir: String) throws {
        let noteDir = (baseNoteDir as NSString).appendingPathComponent("\(id).localized")
        try markdown.write(to: URL(fileURLWithPath: (noteDir as NSString).appendingPathComponent("content.md")),
                         atomically: true,
                         encoding: .utf8)
    }

    private func exportResources(baseNoteDir: String) throws {
        guard !resources.isEmpty else { return }

        let noteDir = (baseNoteDir as NSString).appendingPathComponent("\(id).localized")
        let assetsDir = (noteDir as NSString).appendingPathComponent("assets")

        // Only create assets directory if we have resources
        let resourcesWithData = resources.filter { $0.data != nil }
        guard !resourcesWithData.isEmpty else {
            return
        }

        try FileManager.default.createDirectory(atPath: assetsDir, withIntermediateDirectories: true)
        var failedResources: [(name: String, error: Error)] = []

        for (index, resource) in resources.enumerated() {
            guard let data = resource.data else {
                continue
            }

            do {
                // Generate filename based on resource attributes or fallback to index
                let filename: String
                if let originalName = resource.attributes?.fileName {
                    filename = originalName
                } else {
                    let ext = mimeTypeToExtension(resource.mime)
                    filename = "attachment_\(index)\(ext)"
                }

                let filePath = (assetsDir as NSString).appendingPathComponent(filename)
                try data.write(to: URL(fileURLWithPath: filePath))

                // Set file dates if available
                if let timestamp = resource.attributes?.timestamp {
                    try FileManager.default.setAttributes([
                        .creationDate: timestamp,
                        .modificationDate: timestamp
                    ], ofItemAtPath: filePath)
                }
            } catch {
                failedResources.append((name: resource.attributes?.fileName ?? "attachment_\(index)", error: error))
            }
        }

        if !failedResources.isEmpty {
            print("Warning: Failed to export \(failedResources.count) resources in note '\(id)':")
            for (name, error) in failedResources {
                print("- '\(name)': \(error)")
            }
        }
    }

    private func mimeTypeToExtension(_ mime: String) -> String {
        guard let utType = UTType(mimeType: mime) else { return "" }
        return utType.preferredFilenameExtension ?? "dat"
    }

    private func setDirectoryDates(baseNoteDir: String) throws {
        if let created = created {
            let noteDir = (baseNoteDir as NSString).appendingPathComponent("\(id).localized")
            let attributes: [FileAttributeKey: Any] = [
                .creationDate: created,
                .modificationDate: updated ?? created
            ]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: noteDir)
        }
    }
}
