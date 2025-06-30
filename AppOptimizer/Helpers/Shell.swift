//
//  Shell.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 04.06.2025.
//

import Foundation

enum Shell {
    static func run(command: String) -> String {
        let process = Process()
        let pipe = Pipe()

        process.standardOutput = pipe
        process.standardError = pipe
        process.arguments = ["-c", command]
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")

        do {
            try process.run()
        } catch {
            return "Error: \(error.localizedDescription)"
        }

        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }
}
