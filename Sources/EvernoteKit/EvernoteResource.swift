import Foundation

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

public extension EvernoteResource {
    static func parse(from element: XMLElement) throws -> EvernoteResource {
        var resource = EvernoteResource()

        if let dataElement = element.elements(forName: "data").first {
            let dataStr = dataElement.stringValue ?? ""

            // Try different base64 decoding options
            let options: [Data.Base64DecodingOptions] = [
                [],
                .ignoreUnknownCharacters
            ]

            for option in options {
                if let data = Data(base64Encoded: dataStr, options: option) {
                    resource.data = data
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
                }
            }
        }

        resource.mime = element.elements(forName: "mime").first?.stringValue ?? ""

        resource.width = element.elements(forName: "width").first?.stringValue.flatMap(Int.init)
        resource.height = element.elements(forName: "height").first?.stringValue.flatMap(Int.init)
        resource.duration = element.elements(forName: "duration").first?.stringValue.flatMap(Int.init)
        resource.recognition = element.elements(forName: "recognition").first?.stringValue

        if let altDataStr = element.elements(forName: "alternate-data").first?.stringValue {
            resource.alternateData = Data(base64Encoded: altDataStr, options: .ignoreUnknownCharacters)
        }

        if let attrElement = element.elements(forName: "resource-attributes").first {
            resource.attributes = ResourceAttributes.parse(from: attrElement)
        }

        return resource
    }
}
