//
//  AssetUsageAnalyzer.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 24.06.2025.
//

import Foundation

final class AssetUsageAnalyzer {

    // MARK: Private properties

    private let appPath: String
    private let fileManager = FileManager.default

    private let assetExtensions = [
        "png", "jpg", "jpeg", "gif", "pdf",
        "mov", "mp4",
        "ttf", "otf", "woff", "woff2"
    ]

    // MARK: Lifecycle

    init(appPath: String) {
        self.appPath = appPath
    }

    // MARK: Internal methods

    func analyze() -> String {
        let allAssets = findAllAssets()
        if allAssets.isEmpty {
            return "No assets found."
        }

        let usedAssets = findUsedAssets(from: allAssets)
        let systemAssets = Set(["AppIcon"])

        let unusedAssets = allAssets.subtracting(usedAssets).subtracting(systemAssets)
        if unusedAssets.isEmpty {
            return "No unused assets found."
        }

        return unusedAssets.sorted().joined(separator: "\n")
    }

    // MARK: Private methods

    private func findAllAssets() -> Set<String> {
        var assets = Set<String>()

        guard let enumerator = fileManager.enumerator(atPath: appPath) else { return assets }

        for case let path as String in enumerator {
            let fullPath = (appPath as NSString).appendingPathComponent(path)
            let ext = (path as NSString).pathExtension.lowercased()

            if path.hasSuffix(".xcassets") {
                // все .imageset из каталога .xcassets
                if let imageEnumerator = fileManager.enumerator(atPath: fullPath) {
                    for case let imagePath as String in imageEnumerator where imagePath.hasSuffix(".imageset") {
                        let name = URL(fileURLWithPath: imagePath).deletingPathExtension().lastPathComponent
                        assets.insert(name)
                    }
                }
            } else if assetExtensions.contains(ext) {
                // имя файла без расширения, чтобы находить по имени в коде
                let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                assets.insert(name)
            }
        }

        return assets
    }

    private func findUsedAssets(from assets: Set<String>) -> Set<String> {
        let sourceExtensions = ["swift", "xib", "storyboard"]
        var sourceFiles: [String] = []

        if let enumerator = fileManager.enumerator(atPath: appPath) {
            for case let path as String in enumerator {
                if sourceExtensions.contains(where: { path.hasSuffix(".\($0)") }) {
                    let fullPath = (appPath as NSString).appendingPathComponent(path)
                    sourceFiles.append(fullPath)
                }
            }
        }

        let group = DispatchGroup()
        let queue = DispatchQueue(label: "asset.analysis", attributes: .concurrent)
        var usedAssets = Set<String>()
        let lock = NSLock()

        for file in sourceFiles {
            group.enter()
            queue.async {
                if let content = try? String(contentsOfFile: file, encoding: .utf8) {
                    for asset in assets where content.contains(asset) {
                        lock.lock()
                        usedAssets.insert(asset)
                        lock.unlock()
                    }
                }
                group.leave()
            }
        }

        group.wait()
        return usedAssets
    }
}
