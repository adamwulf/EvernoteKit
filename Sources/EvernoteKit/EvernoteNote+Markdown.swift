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
        let xmlString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let options: XMLNode.Options = [.nodePreserveWhitespace, .documentTidyXML]
        do {
            return try XMLDocument(data: xmlString.data(using: .utf8)!, options: options)
        } catch {
            throw error
        }
    }

    private func convertElementToMarkdown(_ element: XMLNode) -> String {
        guard let element = element as? XMLElement else {
            return element.stringValue ?? ""
        }

        switch element.name?.lowercased() {
        case "en-note":
            return element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        case "div":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined() ?? ""

            // Handle background images
            if content.isEmpty,
               let style = element.attribute(forName: "style")?.stringValue,
               let imageUrl = extractBackgroundImageUrl(from: style) {
                return "\n![background image](\(imageUrl))\n"
            }

            return content
        case "p":
            let content = element.children?.map { convertElementToMarkdown($0).replacingOccurrences(of: "\n", with: " ") }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            return "\(content)\n\n"
        case "img":
            let src = element.attribute(forName: "src")?.stringValue ?? ""
            let alt = element.attribute(forName: "alt")?.stringValue ?? ""
            return "![" + alt + "](" + src + ")"
        case "br":
            return "\n"
        case "b", "strong":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "**\(content)**"
        case "i", "em":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "*\(content)*"
        case "a":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let href = element.attribute(forName: "href")?.stringValue ?? ""
            return "[\(content)](\(href))"
        case "ul":
            let items = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "\n\(items)"
        case "ol":
            let items = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "\n\(items)"
        case "li":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if element.parent?.name?.lowercased() == "ol" {
                return "1. \(content)\n"
            } else {
                return "* \(content)\n"
            }
        case "code", "pre":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "`\(content)`"
        case "en-todo":
            let checked = element.attribute(forName: "checked")?.stringValue == "true"
            return checked ? "[x] " : "[ ] "
        default:
            return element.children?.map { convertElementToMarkdown($0) }.joined() ?? element.stringValue ?? ""
        }
    }

    private func extractBackgroundImageUrl(from style: String) -> String? {
        let pattern = #"background(?:-image)?\s*:\s*url\(['"]?(.*?)['"]?\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: style, range: NSRange(style.startIndex..., in: style)) else {
            return nil
        }

        if let range = Range(match.range(at: 1), in: style) {
            return String(style[range])
        }
        return nil
    }
}
