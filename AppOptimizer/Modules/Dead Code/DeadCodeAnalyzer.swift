//
//  DeadCodeAnalyzer.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 24.06.2025.
//

import Foundation

final class DeadCodeAnalyzer {

    // MARK: Private methods

    private let appPath: String
    private let retainPublic: Bool

    // MARK: Lifecycle

    init(appPath: String, retainPublic: Bool) {
        self.appPath = appPath
        self.retainPublic = retainPublic
    }

    // MARK: Internal methods

    func analyze() -> String {
        guard let projectFile = findProjectFile() else {
            return "Error: .xcodeproj or .xcworkspace not found"
        }

        guard let peripheryPath = peripheryBinaryPath() else {
            return "Error: Periphery not found"
        }

        let outputFile = "\(appPath)/unused_dead_code.txt"

        let cache = FileCache(path: appPath)
        guard cache.shouldAnalyze(files: projectFile.allFiles) else {
            return (try? String(contentsOfFile: outputFile, encoding: .utf8)) ?? ""
        }

        let command = buildPeripheryCommand(periphery: peripheryPath, project: projectFile)

        let output = Shell.run(command: command)

        let filtered = output
            .components(separatedBy: .newlines)
            .filter { $0.contains("warning:") && $0.contains(appPath) }
            .map { $0.replacingOccurrences(of: appPath + "/", with: "") } // относительные пути
            .sorted()
            .joined(separator: "\n")

        try? filtered.write(toFile: outputFile, atomically: true, encoding: .utf8)
        cache.save()

        return filtered
    }

    // MARK: Private methods

    private func findProjectFile() -> ProjectFile? {
        let fm = FileManager.default
        let workspace = try? fm.contentsOfDirectory(atPath: appPath).first(where: { $0.hasSuffix(".xcworkspace") })
        let project = try? fm.contentsOfDirectory(atPath: appPath).first(where: { $0.hasSuffix(".xcodeproj") })

        if let workspace = workspace {
            return ProjectFile(path: "\(appPath)/\(workspace)", isWorkspace: true)
        } else if let project = project {
            return ProjectFile(path: "\(appPath)/\(project)", isWorkspace: false)
        } else {
            return nil
        }
    }

    private func peripheryBinaryPath() -> String? {
        let path = "/opt/homebrew/bin/periphery"
        return FileManager.default.fileExists(atPath: path) ? path : nil
    }

    private func buildPeripheryCommand(periphery: String, project: ProjectFile) -> String {
        var command = "\(periphery) scan"
        command += project.isWorkspace ? " --workspace \"\(project.path)\"" : " --project \"\(project.path)\""
        command += " --schemes \"\(project.defaultScheme)\""
        command += " --targets \"\(project.defaultTarget)\""
        if retainPublic {
            command += " --retain-public"
        }
        return command
    }
}
