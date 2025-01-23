//
//  EvernoteNote.swift
//  EvernoteKit
//
//  Created by Adam Wulf on 1/22/25.
//
import Foundation
import CryptoKit

public class EvernoteNote: Codable {
    public var id: String = ""
    public var title: String = ""
    public var content: String = ""
    public var created: Date?
    public var updated: Date?
    public var tags: [String] = []
    public var attributes: NoteAttributes?
    public var resources: [EvernoteResource] = []

    enum CodingKeys: String, CodingKey {
        case id, title, content, created, updated, tags, attributes, resources
    }

    public init() {}
}

public extension EvernoteNote {
    static func parse(from element: XMLElement) throws -> EvernoteNote {
        let note = EvernoteNote()

        note.title = element.elements(forName: "title").first?.stringValue ?? ""
        note.content = element.elements(forName: "content").first?.stringValue ?? ""

        if let createdStr = element.elements(forName: "created").first?.stringValue {
            note.created = DateFormatter.enex.date(from: createdStr)
        }

        // Generate deterministic ID using SHA-256
        let idSource = "\(note.created?.description ?? "")||\(note.title.isEmpty ? note.content : note.title)"
        let hash = SHA256.hash(data: idSource.data(using: .utf8) ?? Data())
        note.id = hash.prefix(16).compactMap { String(format: "%02x", $0) }.joined()

        if let updatedStr = element.elements(forName: "updated").first?.stringValue {
            note.updated = DateFormatter.enex.date(from: updatedStr)
        }

        note.tags = element.elements(forName: "tag").compactMap { $0.stringValue }

        if let attrElement = element.elements(forName: "note-attributes").first {
            note.attributes = NoteAttributes.parse(from: attrElement)
        }

        note.resources = element.elements(forName: "resource").compactMap {
            try? EvernoteResource.parse(from: $0)
        }

        return note
    }
}

public extension EvernoteNote {
    func exportToDirectory(baseNoteDir: String) throws {
        try createDirectoryStructure(baseNoteDir: baseNoteDir)
        try exportLocalizedStrings(baseNoteDir: baseNoteDir)
        try exportJSON(baseNoteDir: baseNoteDir)
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

    private func exportMarkdown(baseNoteDir: String) throws {
        let noteDir = (baseNoteDir as NSString).appendingPathComponent("\(id).localized")
        var markdown = "# \(title)\n\n"
        if let created = created {
            markdown += "Created: \(created)\n\n"
        }
        if !tags.isEmpty {
            markdown += "Tags: \(tags.joined(separator: ", "))\n\n"
        }
        markdown += content

        try markdown.write(to: URL(fileURLWithPath: (noteDir as NSString).appendingPathComponent("content.md")),
                         atomically: true,
                         encoding: .utf8)
    }

    private func exportResources(baseNoteDir: String) throws {
        guard !resources.isEmpty else { return }

        let noteDir = (baseNoteDir as NSString).appendingPathComponent("\(id).localized")
        let assetsDir = (noteDir as NSString).appendingPathComponent("assets")

        print("Note \(id) has \(resources.count) resources")

        // Only create assets directory if we have resources with data
        let resourcesWithData = resources.filter { $0.data != nil }
        guard !resourcesWithData.isEmpty else {
            print("  - No resources have data")
            return
        }

        try FileManager.default.createDirectory(atPath: assetsDir, withIntermediateDirectories: true)

        for (index, resource) in resources.enumerated() {
            guard let data = resource.data else {
                print("  - Resource \(index) has no data (mime: \(resource.mime), filename: \(resource.attributes?.fileName ?? "unknown"))")
                continue
            }

            // Generate filename based on resource attributes or fallback to index
            let filename: String
            if let originalName = resource.attributes?.fileName {
                filename = originalName
            } else {
                let ext = mimeTypeToExtension(resource.mime)
                filename = "attachment_\(index)\(ext)"
            }

            print("  + Writing resource \(index) to \(filename) (\(data.count) bytes)")

            let filePath = (assetsDir as NSString).appendingPathComponent(filename)
            try data.write(to: URL(fileURLWithPath: filePath))

            // Set file dates if available
            if let timestamp = resource.attributes?.timestamp {
                try FileManager.default.setAttributes([
                    .creationDate: timestamp,
                    .modificationDate: timestamp
                ], ofItemAtPath: filePath)
            }
        }
    }

    private func mimeTypeToExtension(_ mime: String) -> String {
        switch mime.lowercased() {
        case "image/jpeg", "image/jpg": return ".jpg"
        case "image/png": return ".png"
        case "image/gif": return ".gif"
        case "application/pdf": return ".pdf"
        case "audio/wav": return ".wav"
        case "audio/mpeg": return ".mp3"
        case "application/vnd.evernote.ink": return ".ink"
        default: return ""
        }
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
