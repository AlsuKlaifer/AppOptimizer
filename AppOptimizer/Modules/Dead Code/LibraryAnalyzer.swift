//
//  LibraryAnalyzer.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 24.06.2025.
//

import Foundation

final class LibraryAnalyzer {

    // MARK: Private properties

    private let appPath: String
    private let scriptName = "analyze_libs"

    // MARK: Lifecycle

    init(appPath: String) {
        self.appPath = appPath
    }

    // MARK: Internal methods

    func analyze() -> String {
        guard let scriptPath = Bundle.main.path(forResource: scriptName, ofType: "rb") else {
            return "Error: \(scriptName) script not found."
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
        process.arguments = [scriptPath, appPath]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            let outputPath = appPath + "/\(scriptName.replacingOccurrences(of: "analyze_", with: "unused_")).txt"
            if FileManager.default.fileExists(atPath: outputPath) {
                return (try? String(contentsOfFile: outputPath, encoding: .utf8)) ?? "Error: Unable to read output file."
            } else {
                return output.isEmpty ? "No output file generated at \(outputPath)." : output
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}
