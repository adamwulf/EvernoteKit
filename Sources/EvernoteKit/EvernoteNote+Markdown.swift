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

        do {
            let doc = try parseContent()
            guard let root = doc.rootElement() else {
                return frontMatter.joined(separator: "\n") + content
            }
            let markdownContent = convertElementToMarkdown(root)
            return frontMatter.joined(separator: "\n") + markdownContent
        } catch {
            print("Error parsing XHTML content: \(error)")
            return frontMatter.joined(separator: "\n") + content
        }
    }

    private func parseContent() throws -> XMLDocument {
        // Wrap the content in an en-note element if not already wrapped
        let xmlString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let wrappedContent = xmlString.starts(with: "<en-note") ? xmlString : "<en-note>\(xmlString)</en-note>"

        let options: XMLNode.Options = [.nodePreserveWhitespace]
        return try XMLDocument(data: wrappedContent.data(using: .utf8)!, options: options)
    }

    private func convertElementToMarkdown(_ element: XMLNode) -> String {
        guard let element = element as? XMLElement else {
            return element.stringValue ?? ""
        }

        switch element.name?.lowercased() {
        case "en-note":
            return element.children?.map { convertElementToMarkdown($0) }.joined() ?? ""
        case "div", "p":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined() ?? ""
            return "\n\(content)\n"
        case "br":
            return "\n"
        case "b", "strong":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined() ?? ""
            return "**\(content)**"
        case "i", "em":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined() ?? ""
            return "*\(content)*"
        case "a":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined() ?? ""
            let href = element.attribute(forName: "href")?.stringValue ?? ""
            return "[\(content)](\(href))"
        case "ul":
            let items = element.children?.map { convertElementToMarkdown($0) }.joined() ?? ""
            return "\n\(items)"
        case "ol":
            let items = element.children?.map { convertElementToMarkdown($0) }.joined() ?? ""
            return "\n\(items)"
        case "li":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined() ?? ""
            if element.parent?.name?.lowercased() == "ol" {
                return "1. \(content)\n"
            } else {
                return "* \(content)\n"
            }
        case "code", "pre":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined() ?? ""
            return "`\(content)`"
        case "en-todo":
            let checked = element.attribute(forName: "checked")?.stringValue == "true"
            return checked ? "[x] " : "[ ] "
        default:
            return element.children?.map { convertElementToMarkdown($0) }.joined() ?? element.stringValue ?? ""
        }
    }
}
