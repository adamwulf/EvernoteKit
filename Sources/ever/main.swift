import ArgumentParser
import EvernoteKit
import Foundation

struct Ever: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ever",
        abstract: "A tool for working with Evernote ENEX files",
        subcommands: [Export.self]
    )
}

extension Ever {
    struct Export: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "export",
            abstract: "Export an ENEX file to markdown and assets"
        )

        @Argument(help: "Path to the ENEX file to export")
        var inputPath: String

        @Option(name: .shortAndLong, help: "Directory to export to")
        var outputDir: String

        @Option(name: .shortAndLong, help: "Maximum number of notes to export (0 for all)")
        var limit: Int = 0

        mutating func run() throws {
            let currentPath = FileManager.default.currentDirectoryPath
            let expandedPath = NSString(string: inputPath).expandingTildeInPath
            let absolutePath = NSString(string: expandedPath).isAbsolutePath
                ? expandedPath
                : NSString(string: currentPath).appendingPathComponent(expandedPath)

            print("Parsing: \(absolutePath)")

            let xmlData = try Data(contentsOf: URL(fileURLWithPath: absolutePath))
            let notes = try EvernoteParser.parse(xmlData: xmlData)

            print("Found \(notes.count) notes")

            // Create output directory
            let outputPath = NSString(string: outputDir).isAbsolutePath
                ? outputDir
                : NSString(string: currentPath).appendingPathComponent(outputDir)
            try FileManager.default.createDirectory(atPath: outputPath, withIntermediateDirectories: true)

            // Export notes
            let notesToExport = limit > 0 ? notes.prefix(limit) : notes[...]
            var exportedCount = 0
            var failedNotes: [(note: EvernoteNote, error: Error)] = []

            for note in notesToExport {
                do {
                    try note.exportToDirectory(baseNoteDir: outputPath)
                    exportedCount += 1
                } catch {
                    failedNotes.append((note: note, error: error))
                    print("Warning: Failed to export note '\(note.id)': \(error)")
                }
            }

            print("Successfully exported \(exportedCount) notes to \(outputPath)")
            if !failedNotes.isEmpty {
                print("\nFailed to export \(failedNotes.count) notes:")
                for (note, error) in failedNotes {
                    print("- '\(note.id)': \(error)")
                }
            }
        }
    }
}

Ever.main()
