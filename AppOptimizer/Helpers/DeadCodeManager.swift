//
//  DeadCodeManager.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 08.01.2025.
//

import Foundation

class DeadCodeManager {

    private let appPath: String
    private let retainPublic: Bool
    private let includeAssets: Bool
    private let includeLibraries: Bool

    init(appPath: String, retainPublic: Bool, includeAssets: Bool, includeLibraries: Bool) {
        self.appPath = appPath
        self.retainPublic = retainPublic
        self.includeAssets = includeAssets
        self.includeLibraries = includeLibraries
    }

    func analyzeDeadCode(outputFile: inout String) {
        guard !appPath.isEmpty else {
            outputFile = "Error: Project path cannot be empty."
            return
        }

        searchDeadCode(outputFile: &outputFile)

        if includeAssets {
            searchUnusedAssets(outputFile: &outputFile)
        }

        if includeLibraries {
            searchUnusedLibraries(outputFile: &outputFile)
        }
    }

    private func searchUnusedLibraries(outputFile: inout String) {
        guard let libScriptPath = Bundle.main.path(forResource: "analyze_libs", ofType: "rb") else {
            outputFile = "Error: Script paths not found."
            return
        }

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
            process.arguments = [libScriptPath, appPath]
            
            try process.run()
            process.waitUntilExit()
            
            let unusedLibOutput: String
            let unusedLibOutputPath = appPath + "/unused_lib.txt"

            if FileManager.default.fileExists(atPath: unusedLibOutputPath) {
                unusedLibOutput = try String(contentsOfFile: unusedLibOutputPath, encoding: .utf8)
            } else {
                unusedLibOutput = "Error: Output file not found at \(unusedLibOutputPath)."
            }

            outputFile = outputFile + "\n" + "Unused Libraries: " + "\n" + unusedLibOutput

        } catch {
            print("Error while searching unused Libraries: \(error.localizedDescription)")
        }
    }

    private func searchUnusedAssets(outputFile: inout String) {
        guard let assetsScriptPath = Bundle.main.path(forResource: "analyze_assets", ofType: "rb") else {
            outputFile = "Error: Script for searching unused Assets not found."
            return
        }

        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
            process.arguments = [assetsScriptPath, appPath]

            try process.run()
            process.waitUntilExit()
            
            let unusedAssetsOutput: String
            let unusedAssetsOutputPath = appPath + "/unused_assets.txt"

            if FileManager.default.fileExists(atPath: unusedAssetsOutputPath) {
                unusedAssetsOutput = try String(contentsOfFile: unusedAssetsOutputPath, encoding: .utf8)
            } else {
                unusedAssetsOutput = "Error: Output file not found at \(unusedAssetsOutputPath)."
            }

            outputFile = outputFile + "\n" + "Unused Assets: " + "\n" + unusedAssetsOutput

        } catch {
            print("Error while searching unused Assets: \(error.localizedDescription)")
        }
    }

    private func searchDeadCode(outputFile: inout String) {
        guard let deadCodeScriptPath = Bundle.main.path(forResource: "analyze_dead_code", ofType: "rb") else {
            outputFile = "Error: Script path not found."
            return
        }

        let retainPublicOption = retainPublic ? "retain_public:true" : ""

        let processDeadCode = Process()
        processDeadCode.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
        processDeadCode.arguments = [deadCodeScriptPath, appPath, retainPublicOption]

        do {
            try processDeadCode.run()
            processDeadCode.waitUntilExit()

            let outputFilePath = appPath + "/periphery_output.txt"
            let deadCodeOutput: String

            if FileManager.default.fileExists(atPath: outputFilePath) {
                deadCodeOutput = try String(contentsOfFile: outputFilePath, encoding: .utf8)
            } else {
                deadCodeOutput = "Error: Output file not found at \(outputFilePath)."
            }

            outputFile = deadCodeOutput
        } catch {
            print("Error while searching dead code: \(error.localizedDescription)")
        }
    }
}
