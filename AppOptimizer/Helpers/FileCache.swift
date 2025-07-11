//
//  FileCache.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 04.06.2025.
//

import Foundation
import CryptoKit

final class FileCache {

    private(set) var changedFiles: [String] = []

    // MARK: Private properties

    private let cachePath: String
    private var currentHashes: [String: String] = [:]
    private var storedHashes: [String: String] = [:]

    // MARK: Lifecycle

    init(path: String) {
        cachePath = "\(path)/.file_hashes_cache"
        storedHashes = (try? load()) ?? [:]
    }

    // MARK: Internal methods

    func shouldAnalyze(files: [String]) -> Bool {
        changedFiles = []

        for file in files {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: file)) else { continue }
            let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            currentHashes[file] = hash
            if storedHashes[file] != hash {
                changedFiles.append(file)
                storedHashes[file] = hash
            }
        }

        return !changedFiles.isEmpty
    }

    func save() {
        try? JSONEncoder().encode(currentHashes).write(to: URL(fileURLWithPath: cachePath))
    }

    // MARK: Private methods

    private func load() throws -> [String: String] {
        let data = try Data(contentsOf: URL(fileURLWithPath: cachePath))
        return try JSONDecoder().decode([String: String].self, from: data)
    }
}
