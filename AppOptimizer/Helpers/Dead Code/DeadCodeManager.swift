//
//  DeadCodeManager.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 08.01.2025.
//

import Foundation

class DeadCodeManager {

    private let appPath: String?
    private let retainPublic: Bool
    private let includeAssets: Bool
    private let includeLibraries: Bool

    init(appPath: String, retainPublic: Bool, includeAssets: Bool, includeLibraries: Bool) {
        self.appPath = appPath
        self.retainPublic = retainPublic
        self.includeAssets = includeAssets
        self.includeLibraries = includeLibraries
    }

    private let dispatchGroup = DispatchGroup()
    private let queue = DispatchQueue.global()
    private var results = [
        "Dead Code": "",
        "Unused Assets": "",
        "Unused Libraries": ""
    ]

    func analyzeDeadCode(outputFile: inout String) {

        let includePublic = self.retainPublic ? "retain_public:true" : ""
        runScriptAsync(name: "Dead Code", scriptName: "analyze_dead_code", arguments: [includePublic])

        if includeAssets {
            runScriptAsync(name: "Unused Assets", scriptName: "analyze_assets")
        }

        if includeLibraries {
            runScriptAsync(name: "Unused Libraries", scriptName: "analyze_libs")
        }

        dispatchGroup.wait()
        outputFile = results.map { "\($0):\n\($1)" }.joined(separator: "\n\n")
    }

    private func runScriptAsync(
        name: String,
        scriptName: String,
        arguments: [String] = []
    ) {
        dispatchGroup.enter()
        queue.async {
            guard let appPath = self.appPath, !appPath.isEmpty else { return }

            var args = arguments
            args.insert(appPath, at: 0)

            self.results[name] = self.runScript(named: scriptName, arguments: args)
            self.dispatchGroup.leave()
        }
    }

    private func runScript(named scriptName: String, arguments: [String]) -> String {
        guard let appPath = self.appPath,
              let scriptPath = Bundle.main.path(forResource: scriptName, ofType: "rb")
        else {
            return "Error: \(scriptName) script not found."
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
        process.arguments = [scriptPath] + arguments

        do {
            try process.run()
            process.waitUntilExit()

            let outputPath = appPath + "/\(scriptName.replacingOccurrences(of: "analyze_", with: "unused_")).txt"

            if FileManager.default.fileExists(atPath: outputPath) {
                return (try? String(contentsOfFile: outputPath, encoding: .utf8)) ?? "Error: Unable to read output file at \(outputPath)."
            } else {
                return "Error: Output file not found at \(outputPath)."
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}
