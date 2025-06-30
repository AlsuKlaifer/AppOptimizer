//
//  DeadCodeManager.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 08.01.2025.
//

import Foundation

final class DeadCodeManager {

    // MARK: Private properties

    private let appPath: String
    private let retainPublic: Bool
    private let includeAssets: Bool

    private let dispatchGroup = DispatchGroup()
    private let queue = DispatchQueue.global()
    private var results = [String: String]()

    // MARK: Lifecycle

    init(appPath: String, retainPublic: Bool, includeAssets: Bool) {
        self.appPath = appPath
        self.retainPublic = retainPublic
        self.includeAssets = includeAssets
    }

    // MARK: Internal methods

    func analyze(outputFile: inout String) {
        runAsync(name: "Unused Code") {
            DeadCodeAnalyzer(appPath: self.appPath, retainPublic: self.retainPublic).analyze()
        }

        if includeAssets {
            runAsync(name: "Unused Assets") {
                AssetUsageAnalyzer(appPath: self.appPath).analyze()
            }
        }

        dispatchGroup.wait()

        outputFile = results
            .filter { !$0.value.isEmpty }
            .map { "\($0):\n\($1)" }
            .joined(separator: "\n\n")
    }

    // MARK: Private methods

    private func runAsync(name: String, block: @escaping () -> String) {
        dispatchGroup.enter()
        queue.async {
            let result = block()
            self.results[name] = result
            self.dispatchGroup.leave()
        }
    }
}
