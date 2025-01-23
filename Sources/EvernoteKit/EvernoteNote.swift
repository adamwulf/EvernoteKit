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
