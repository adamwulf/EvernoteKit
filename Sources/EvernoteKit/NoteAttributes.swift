//
//  NoteAttributes.swift
//  EvernoteKit
//
//  Created by Adam Wulf on 1/22/25.
//
import Foundation

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
