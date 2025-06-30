//
//  ProjectFile.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 04.06.2025.
//

import Foundation

struct ProjectFile {
    let path: String
    let isWorkspace: Bool

    var workspaceFiles: [String] {
        if isWorkspace {
            return [path]
        } else {
            return [path, "\(path)/project.pbxproj"]
        }
    }

    var projectName: String {
        URL(fileURLWithPath: path)
            .deletingPathExtension()
            .lastPathComponent
    }

    var defaultTarget: String { projectName }
    var defaultScheme: String { projectName }

    private func fetchXcodeList(label: String) -> [String] {
        let listCommand: String
        if isWorkspace {
            listCommand = "xcodebuild -list -workspace \"\(path)\""
        } else {
            listCommand = "xcodebuild -list -project \"\(path)\""
        }

        let output = Shell.run(command: listCommand)
        let section = output.components(separatedBy: "\(label):").dropFirst().first ?? ""
        return section
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
