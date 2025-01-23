import Foundation

public extension EvernoteNote {
    var markdown: String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone.gmt
        dateFormatter.formatOptions = [.withInternetDateTime]

        var frontMatter = [String]()
        frontMatter.append("---")
        frontMatter.append("title: \"\(title)\"")
        if let created = created {
            frontMatter.append("created: \(dateFormatter.string(from: created))")
        }
        if let updated = updated {
            frontMatter.append("lastEdited: \(dateFormatter.string(from: updated))")
        }
        frontMatter.append("id: \(id)")
        if !tags.isEmpty {
            frontMatter.append("tags: \(tags.joined(separator: ", "))")
        }
        if let source = attributes?.source {
            frontMatter.append("source: \(source)")
        }
        if let sourceUrl = attributes?.sourceUrl {
            frontMatter.append("source_url: \(sourceUrl)")
        }
        frontMatter.append("---")
        frontMatter.append("")
        frontMatter.append("")

        return frontMatter.joined(separator: "\n") + content
    }
}
