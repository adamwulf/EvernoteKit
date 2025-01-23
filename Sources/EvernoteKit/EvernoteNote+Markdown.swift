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

    private func hasAncestor(element: XMLNode, named: String) -> Bool {
        var current = element.parent
        while let parent = current {
            if let element = parent as? XMLElement, element.name?.lowercased() == named.lowercased() {
                return true
            }
            current = parent.parent
        }
        return false
    }

    private func convertElementToMarkdown(_ element: XMLNode) -> String {
        guard let element = element as? XMLElement else {
            return element.stringValue ?? ""
        }

        switch element.name?.lowercased() {
        case "en-note":
            return element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        case "div":
            // Process children and track if we need paragraph-style spacing
            var result = ""
            var inlineContent = ""

            for child in element.children ?? [] {
                let childContent = convertElementToMarkdown(child)
                let isBlockElement = childContent.contains("\n\n")

                if isBlockElement {
                    // Flush any pending inline content with paragraph spacing
                    if !inlineContent.isEmpty {
                        result += inlineContent.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
                        inlineContent = ""
                    }
                    result += childContent
                } else {
                    inlineContent += childContent
                }
            }

            // Flush any remaining inline content
            if !inlineContent.isEmpty {
                result += inlineContent.trimmingCharacters(in: .whitespacesAndNewlines) + "\n\n"
            }

            // background images, and treat as an img tag if there is no content otherwise
            if result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let style = element.attribute(forName: "style")?.stringValue,
               let imageUrl = extractBackgroundImageUrl(from: style) {
                return "![background image](\(imageUrl))\n\n"
            }

            return result
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
            return "[\(content.isEmpty ? href : content)](\(href))"
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
        case "code":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let parentName = element.parent?.name?.lowercased()
            if parentName == "p" {
                return "`\(content)`"
            }
            if content.contains("\n") {
                return "```\n\(content)\n```\n\n"
            } else {
                return "`\(content)`"
            }
        case "pre":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined() ?? ""
            let hasCodeParent = hasAncestor(element: element, named: "code")
            let hasCodeChild = element.children?.contains(where: { ($0 as? XMLElement)?.name?.lowercased() == "code" }) ?? false
            if hasCodeParent || hasCodeChild {
                return content
            } else {
                let inlineContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                return "`\(inlineContent)`"
            }
        case "en-todo":
            let checked = element.attribute(forName: "checked")?.stringValue == "true"
            return checked ? "[x] " : "[ ] "
        case "blockquote":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let lines = content.components(separatedBy: "\n")
            let parentName = element.parent?.name?.lowercased()
            let extraNewline = parentName != "p" && parentName != "blockquote" ? "\n\n" : "\n"
            return lines.map { "> \($0)" }.joined(separator: "\n") + extraNewline
        case "h1":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "# \(content)\n\n"
        case "h2":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "## \(content)\n\n"
        case "h3":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "### \(content)\n\n"
        case "h4":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "#### \(content)\n\n"
        case "h5":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "##### \(content)\n\n"
        case "h6":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "###### \(content)\n\n"
        case "hr":
            return "\n---\n\n"
        case "table":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined() ?? ""
            return "\n<table>\n" + content + "</table>\n\n"
        case "tr":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined() ?? ""
            return "<tr>" + content + "</tr>\n"
        case "th":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "<th>" + content + "</th>"
        case "td":
            let content = element.children?.map { convertElementToMarkdown($0) }.joined().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return "<td>" + content + "</td>"
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
