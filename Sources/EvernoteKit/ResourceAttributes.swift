//
//  ResourceAttributes.swift
//  EvernoteKit
//
//  Created by Adam Wulf on 1/22/25.
//
import Foundation


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
