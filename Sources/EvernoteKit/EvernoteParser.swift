import Foundation
import CryptoKit

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
