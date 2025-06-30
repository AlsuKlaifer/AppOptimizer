//
//  Settings.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 08.06.2025.
//

import SwiftUI

struct SettingsData: Codable {
    var exclude_paths: [String]
    var analyze_extensions: [String]
    var use_multithreading: Bool
    var max_threads: Int
    var enable_cache: Bool
    var cache_path: String
    var min_similarity_threshold: Double

    func orderedData() -> Data? {
        let keys = [
            "exclude_paths",
            "analyze_extensions",
            "use_multithreading",
            "max_threads",
            "enable_cache",
            "cache_path",
            "min_similarity_threshold"
        ]
        let dict: [String: Any] = [
            "exclude_paths": exclude_paths,
            "analyze_extensions": analyze_extensions,
            "use_multithreading": use_multithreading,
            "max_threads": max_threads,
            "enable_cache": enable_cache,
            "cache_path": cache_path,
            "min_similarity_threshold": min_similarity_threshold
        ]
        var lines: [String] = ["{"]
        for key in keys {
            let value = dict[key]!
            let jsonValue: String
            switch value {
            case let arr as [String]:
                let items = arr.map { "\"\($0)\"" }.joined(separator: ", ")
                jsonValue = "[\(items)]"
            case let str as String:
                jsonValue = "\"\(str)\""
            case let num as Double:
                jsonValue = String(format: "%.2f", num)
            case let num as Int:
                jsonValue = "\(num)"
            case let bool as Bool:
                jsonValue = bool ? "true" : "false"
            default:
                jsonValue = "null"
            }
            let comma = key == keys.last ? "" : ","
            lines.append("  \"\(key)\": \(jsonValue)\(comma)")
        }
        lines.append("}\n")
        let jsonString = lines.joined(separator: "\n")
        return jsonString.data(using: .utf8)
    }
}

final class SettingsModel: ObservableObject {
    @Published var excludePaths: [String] = ["Pods", "Tests", "Generated"]
    @Published var analyzeExtensions: [String] = [".swift", ".xib", ".storyboard"]
    @Published var useMultithreading: Bool = true
    @Published var maxThreads: Int = 4
    @Published var enableCache: Bool = true
    @Published var cachePath: String = "./.analysis_cache"
    @Published var minSimilarityThreshold: Double = 0.8

    func load(from url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        if let settings = try? JSONDecoder().decode(SettingsData.self, from: data) {
            DispatchQueue.main.async {
                self.excludePaths = settings.exclude_paths
                self.analyzeExtensions = settings.analyze_extensions
                self.useMultithreading = settings.use_multithreading
                self.maxThreads = settings.max_threads
                self.enableCache = settings.enable_cache
                self.cachePath = settings.cache_path
                self.minSimilarityThreshold = settings.min_similarity_threshold
            }
        }
    }

    func save(to url: URL) {
        let settings = SettingsData(
            exclude_paths: excludePaths,
            analyze_extensions: analyzeExtensions,
            use_multithreading: useMultithreading,
            max_threads: maxThreads,
            enable_cache: enableCache,
            cache_path: cachePath,
            min_similarity_threshold: minSimilarityThreshold
        )
        if let data = settings.orderedData() {
            try? data.write(to: url, options: [.atomic])
        }
    }
}
