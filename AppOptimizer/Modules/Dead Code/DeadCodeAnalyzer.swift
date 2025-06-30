//
//  DeadCodeAnalyzer.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 09.06.2025.
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

        let outputFile = "\(appPath)/unused_code.txt"
        let cache = FileCache(path: appPath)

        let allFilesToTrack = projectFile.workspaceFiles + collectSourceFiles()
        guard cache.shouldAnalyze(files: allFilesToTrack) else {
            return (try? String(contentsOfFile: outputFile, encoding: .utf8)) ?? ""
        }

        let changedFiles = cache.changedFiles

        let command = buildPeripheryCommand(
            periphery: peripheryPath,
            project: projectFile,
            changedFiles: changedFiles
        )

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

    private func collectSourceFiles() -> [String] {
        let fileManager = FileManager.default
        var sourceFiles: [String] = []

        let allowedExtensions = ["swift", "xib", "storyboard"]

        guard let enumerator = fileManager.enumerator(atPath: appPath) else {
            return []
        }

        for case let path as String in enumerator {
            let ext = (path as NSString).pathExtension.lowercased()
            if allowedExtensions.contains(ext) {
                let fullPath = (appPath as NSString).appendingPathComponent(path)
                sourceFiles.append(fullPath)
            }
        }

        return sourceFiles
    }

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

    private func buildPeripheryCommand(
        periphery: String,
        project: ProjectFile,
        changedFiles: [String]
    ) -> String {
        var command = [periphery, "scan"]

        command += ["--index-exclude", "\"\(appPath)/Pods/**\""]

        if project.isWorkspace {
            command += ["--workspace", "\"\(project.path)\""]
        } else {
            command += ["--project", "\"\(project.path)\""]
        }

        command += ["--schemes", "\"\(project.defaultScheme)\""]

        if retainPublic {
            command.append("--retain-public")
        }

//        if !changedFiles.isEmpty {
//            let includes = changedFiles
//                .map { "\"\($0)\"" }
//                .joined(separator: ",")
//            command += ["--report-exclude", includes]
//        } временно

        command += ["--disable-update-check"]

        return command.joined(separator: " ")
    }
}
