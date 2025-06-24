//
//  DeadCodeManager.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 08.01.2025.
//

import Foundation

class DeadCodeManager {

    // MARK: Private properties

    private let appPath: String
    private let retainPublic: Bool
    private let includeAssets: Bool
    private let includeLibraries: Bool

    private let dispatchGroup = DispatchGroup()
    private let queue = DispatchQueue.global()
    private var results = [
        "Dead Code": "",
        "Unused Assets": "",
        "Unused Libraries": ""
    ]

    // MARK: Lifecycle

    init(appPath: String, retainPublic: Bool, includeAssets: Bool, includeLibraries: Bool) {
        self.appPath = appPath
        self.retainPublic = retainPublic
        self.includeAssets = includeAssets
        self.includeLibraries = includeLibraries
    }

    // MARK: Internal methods

    func analyzeDeadCode(outputFile: inout String) {
        runScriptAsync(
            name: "Dead Code",
            scriptName: "analyze_dead_code",
            arguments: retainPublic ? ["retain_public:true"] : []
        )

        if includeAssets {
            analyzeAssetsAsync(name: "Unused Assets")
        }

        if includeLibraries {
            runScriptAsync(name: "Unused Libraries", scriptName: "analyze_libs")
        }

        // Wait for all tasks
        dispatchGroup.wait()

        outputFile = results
            .filter { !$0.value.isEmpty }
            .map { "\($0):\n\($1)" }
            .joined(separator: "\n\n")
    }
    
    // MARK: - Private
    
    private func runScriptAsync(name: String, scriptName: String, arguments: [String] = []) {
        dispatchGroup.enter()
        queue.async {
            let result = self.runScript(named: scriptName, arguments: arguments)
            self.results[name] = result
            self.dispatchGroup.leave()
        }
    }
    
    private func runScript(named scriptName: String, arguments: [String]) -> String {
        guard let scriptPath = Bundle.main.path(forResource: scriptName, ofType: "rb") else {
            return "Error: \(scriptName) script not found."
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
        process.arguments = [scriptPath, appPath] + arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let outputPath = appPath + "/\(scriptName.replacingOccurrences(of: "analyze_", with: "unused_")).txt"
            if FileManager.default.fileExists(atPath: outputPath) {
                return (try? String(contentsOfFile: outputPath, encoding: .utf8)) ?? "Error: Unable to read output file."
            } else {
                return output.isEmpty ? "No output file generated at \(outputPath)." : output
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    private func analyzeAssetsAsync(name: String) {
        dispatchGroup.enter()
        queue.async {
            let result = self.analyzeAssets()
            self.results[name] = result
            self.dispatchGroup.leave()
        }
    }
    
    private func analyzeAssets() -> String {
        var allAssets = Set<String>()
        let fileManager = FileManager.default
        
        guard let enumerator = fileManager.enumerator(atPath: appPath) else {
            return "Error: Failed to enumerate files."
        }
        
        for case let path as String in enumerator {
            if path.hasSuffix(".xcassets") {
                let fullAssetPath = (appPath as NSString).appendingPathComponent(path)
                if let imageEnumerator = fileManager.enumerator(atPath: fullAssetPath) {
                    for case let imagePath as String in imageEnumerator where imagePath.hasSuffix(".imageset") {
                        let assetName = URL(fileURLWithPath: imagePath).deletingPathExtension().lastPathComponent
                        allAssets.insert(assetName)
                    }
                }
            }
        }
        
        if allAssets.isEmpty {
            return "No assets found."
        }
        
        // Search for asset usages in source files
        var usedAssets = Set<String>()
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
        
        let analysisGroup = DispatchGroup()
        let analysisQueue = DispatchQueue(label: "asset.analysis", attributes: .concurrent)
        
        for file in sourceFiles {
            analysisGroup.enter()
            analysisQueue.async {
                if let content = try? String(contentsOfFile: file, encoding: .utf8) {
                    for asset in allAssets {
                        if content.contains(asset) {
                            usedAssets.insert(asset)
                        }
                    }
                }
                analysisGroup.leave()
            }
        }
        
        analysisGroup.wait()
        
        let systemAssets = Set(["AppIcon"])
        let unusedAssets = allAssets.subtracting(usedAssets).subtracting(systemAssets)

        if unusedAssets.isEmpty {
            return "No unused assets found."
        } else {
            return unusedAssets.sorted().joined(separator: "\n")
        }
    }
}
