import Foundation
import CryptoKit

// MARK: - Types

public struct NoteAttributes: Codable {
    public var subjectDate: Date?
    public var latitude: Double?
    public var longitude: Double?
    public var altitude: Double?
    public var author: String?
    public var source: String?
    public var sourceUrl: String?
    public var sourceApplication: String?
    public var reminderOrder: Int?
    public var reminderTime: Date?
    public var reminderDoneTime: Date?
    public var placeName: String?
    public var contentClass: String?
    public var applicationData: [String: String] = [:]

    public init(
        subjectDate: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        altitude: Double? = nil,
        author: String? = nil,
        source: String? = nil,
        sourceUrl: String? = nil,
        sourceApplication: String? = nil,
        reminderOrder: Int? = nil,
        reminderTime: Date? = nil,
        reminderDoneTime: Date? = nil,
        placeName: String? = nil,
        contentClass: String? = nil,
        applicationData: [String: String] = [:]
    ) {
        self.subjectDate = subjectDate
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.author = author
        self.source = source
        self.sourceUrl = sourceUrl
        self.sourceApplication = sourceApplication
        self.reminderOrder = reminderOrder
        self.reminderTime = reminderTime
        self.reminderDoneTime = reminderDoneTime
        self.placeName = placeName
        self.contentClass = contentClass
        self.applicationData = applicationData
    }
}

public struct ResourceAttributes: Codable {
    public var sourceUrl: String?
    public var timestamp: Date?
    public var latitude: Double?
    public var longitude: Double?
    public var altitude: Double?
    public var cameraMake: String?
    public var cameraModel: String?
    public var recoType: String?
    public var fileName: String?
    public var attachment: Bool?
    public var applicationData: [String: String] = [:]

    public init(
        sourceUrl: String? = nil,
        timestamp: Date? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        altitude: Double? = nil,
        cameraMake: String? = nil,
        cameraModel: String? = nil,
        recoType: String? = nil,
        fileName: String? = nil,
        attachment: Bool? = nil,
        applicationData: [String: String] = [:]
    ) {
        self.sourceUrl = sourceUrl
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.cameraMake = cameraMake
        self.cameraModel = cameraModel
        self.recoType = recoType
        self.fileName = fileName
        self.attachment = attachment
        self.applicationData = applicationData
    }
}

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

public struct EvernoteResource: Codable {
    public var data: Data?
    public var mime: String = ""
    public var width: Int?
    public var height: Int?
    public var duration: Int?
    public var recognition: String?
    public var attributes: ResourceAttributes?
    public var alternateData: Data?

    public init(
        data: Data? = nil,
        mime: String = "",
        width: Int? = nil,
        height: Int? = nil,
        duration: Int? = nil,
        recognition: String? = nil,
        attributes: ResourceAttributes? = nil,
        alternateData: Data? = nil
    ) {
        self.data = data
        self.mime = mime
        self.width = width
        self.height = height
        self.duration = duration
        self.recognition = recognition
        self.attributes = attributes
        self.alternateData = alternateData
    }
}

// MARK: - Parsing Extensions

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

public extension EvernoteResource {
    static func parse(from element: XMLElement) throws -> EvernoteResource {
        let resource = EvernoteResource()

        print("Parsing resource:")
        if let dataElement = element.elements(forName: "data").first {
            let dataStr = dataElement.stringValue ?? ""
            print("  Found data element: \(dataStr.prefix(50))...")

            // Try different base64 decoding options
            let options: [Data.Base64DecodingOptions] = [
                [],
                .ignoreUnknownCharacters
            ]

            for option in options {
                if let data = Data(base64Encoded: dataStr, options: option) {
                    resource.data = data
                    print("  Successfully decoded \(data.count) bytes with options: \(option)")
                    break
                }
            }

            if resource.data == nil {
                // Try cleaning the string first
                let cleaned = dataStr
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: "\r", with: "")

                if let data = Data(base64Encoded: cleaned, options: .ignoreUnknownCharacters) {
                    resource.data = data
                    print("  Successfully decoded \(data.count) bytes after cleaning")
                } else {
                    print("  Failed to decode base64 data. First 10 chars: \(String(dataStr.prefix(10)))")
                    print("  Last 10 chars: \(String(dataStr.suffix(10)))")
                }
            }
        } else {
            print("  No data element found")
        }

        resource.mime = element.elements(forName: "mime").first?.stringValue ?? ""
        print("  Mime type: \(resource.mime)")

        resource.width = element.elements(forName: "width").first?.stringValue.flatMap(Int.init)
        resource.height = element.elements(forName: "height").first?.stringValue.flatMap(Int.init)
        resource.duration = element.elements(forName: "duration").first?.stringValue.flatMap(Int.init)
        resource.recognition = element.elements(forName: "recognition").first?.stringValue

        if let altDataStr = element.elements(forName: "alternate-data").first?.stringValue {
            resource.alternateData = Data(base64Encoded: altDataStr, options: .ignoreUnknownCharacters)
        }

        if let attrElement = element.elements(forName: "resource-attributes").first {
            resource.attributes = ResourceAttributes.parse(from: attrElement)
            print("  Filename: \(resource.attributes?.fileName ?? "none")")
        }

        return resource
    }
}

public extension NoteAttributes {
    static func parse(from element: XMLElement) -> NoteAttributes {
        var attrs = NoteAttributes()

        attrs.subjectDate = element.elements(forName: "subject-date").first?.stringValue.flatMap(DateFormatter.enex.date)
        attrs.latitude = element.elements(forName: "latitude").first?.stringValue.flatMap(Double.init)
        attrs.longitude = element.elements(forName: "longitude").first?.stringValue.flatMap(Double.init)
        attrs.altitude = element.elements(forName: "altitude").first?.stringValue.flatMap(Double.init)
        attrs.author = element.elements(forName: "author").first?.stringValue
        attrs.source = element.elements(forName: "source").first?.stringValue
        attrs.sourceUrl = element.elements(forName: "source-url").first?.stringValue
        attrs.sourceApplication = element.elements(forName: "source-application").first?.stringValue
        attrs.reminderOrder = element.elements(forName: "reminder-order").first?.stringValue.flatMap(Int.init)
        attrs.reminderTime = element.elements(forName: "reminder-time").first?.stringValue.flatMap(DateFormatter.enex.date)
        attrs.reminderDoneTime = element.elements(forName: "reminder-done-time").first?.stringValue.flatMap(DateFormatter.enex.date)
        attrs.placeName = element.elements(forName: "place-name").first?.stringValue
        attrs.contentClass = element.elements(forName: "content-class").first?.stringValue

        element.elements(forName: "application-data").forEach { elem in
            if let key = elem.attribute(forName: "key")?.stringValue,
               let value = elem.stringValue {
                attrs.applicationData[key] = value
            }
        }

        return attrs
    }
}

public extension ResourceAttributes {
    static func parse(from element: XMLElement) -> ResourceAttributes {
        var attrs = ResourceAttributes()

        attrs.sourceUrl = element.elements(forName: "source-url").first?.stringValue
        attrs.timestamp = element.elements(forName: "timestamp").first?.stringValue.flatMap(DateFormatter.enex.date)
        attrs.latitude = element.elements(forName: "latitude").first?.stringValue.flatMap(Double.init)
        attrs.longitude = element.elements(forName: "longitude").first?.stringValue.flatMap(Double.init)
        attrs.altitude = element.elements(forName: "altitude").first?.stringValue.flatMap(Double.init)
        attrs.cameraMake = element.elements(forName: "camera-make").first?.stringValue
        attrs.cameraModel = element.elements(forName: "camera-model").first?.stringValue
        attrs.recoType = element.elements(forName: "reco-type").first?.stringValue
        attrs.fileName = element.elements(forName: "file-name").first?.stringValue
        attrs.attachment = element.elements(forName: "attachment").first?.stringValue.map { $0.lowercased() == "true" }

        element.elements(forName: "application-data").forEach { elem in
            if let key = elem.attribute(forName: "key")?.stringValue,
               let value = elem.stringValue {
                attrs.applicationData[key] = value
            }
        }

        return attrs
    }
}

public extension DateFormatter {
    static let enex: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
}

// MARK: - Export Extensions

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

// MARK: - Parser

public class EvernoteParser {
    public static func parse(xmlData: Data) throws -> [EvernoteNote] {
        // Skip DTD validation
        let options: XMLNode.Options = [.nodePreserveWhitespace]
        let document = try XMLDocument(data: xmlData, options: options)

        guard let root = document.rootElement() else {
            throw NSError(domain: "EvernoteParser", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "No root element found"])
        }

        if let version = root.attribute(forName: "version")?.stringValue {
            print("Parsing ENEX version: \(version)")
        }

        return root.elements(forName: "note").compactMap { try? EvernoteNote.parse(from: $0) }
    }
}

// MARK: - Main

if CommandLine.arguments.count != 2 {
    print("Usage: swift EvernoteXML.swift <path-to-enex-file>")
    exit(1)
}

let rawPath = CommandLine.arguments[1]
let currentPath = FileManager.default.currentDirectoryPath
let inputPath = NSString(string: rawPath).expandingTildeInPath
let absolutePath = NSString(string: inputPath).isAbsolutePath
    ? inputPath
    : NSString(string: currentPath).appendingPathComponent(inputPath)

do {
    print("parsing: \(absolutePath)")

    let xmlData = try Data(contentsOf: URL(fileURLWithPath: absolutePath))
    let notes = try EvernoteParser.parse(xmlData: xmlData)

    print("Found \(notes.count) notes:")

    // Create output directory
    let outputDir = (currentPath as NSString).appendingPathComponent("Evernote")
    try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

    // Export first 10 notes
    for note in notes.prefix(10) {
        try note.exportToDirectory(baseNoteDir: outputDir)
    }

    print("Successfully exported up to 10 notes to \(outputDir)")
} catch {
    print("Error: \(error)")
    exit(1)
}
