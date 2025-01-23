//
//  Helpers.swift
//  EvernoteKit
//
//  Created by Adam Wulf on 1/22/25.
//
import Foundation

extension DateFormatter {
    static let enex: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
}
