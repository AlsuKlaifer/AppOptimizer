//
//  PDGDuplicateCodeManager.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 21.03.2025.
//

import Foundation
import SwiftParser
import SwiftSyntax
import SwiftGraph
import CryptoKit

struct FilePair: Hashable {
    let first: URL
    let second: URL
}

class PDGDuplicateCodeManager {

    // MARK: Properties

    private let appPath: String
    private let cacheDir: URL
    private let minCloneSize: Int
    private let similarityThreshold: Double

    // MARK: Lifecycle

    init(appPath: String, minCloneSize: Int = 3, similarityThreshold: Double = 0.3) {
        self.appPath = appPath
        self.minCloneSize = minCloneSize
        self.similarityThreshold = similarityThreshold

        let root = URL(fileURLWithPath: appPath).deletingLastPathComponent()
        self.cacheDir = root.appendingPathComponent(".analysis_cache", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: cacheDir,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    // MARK: Internal methods

    func analyzeDuplicates(output: inout String) {
        output = ""
        let fileURLs = getSwiftFileURLs(in: appPath)
        guard !fileURLs.isEmpty else {
            output = "No Swift files found in \(appPath)"
            return
        }

        // для каждого файла либо загружаем кэш, либо строим заново
        var allSubgraphs: [(PDGSubgraph, URL)] = []
        for fileURL in fileURLs {
            let data = (try? Data(contentsOf: fileURL)) ?? Data()
            let hash = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            let cacheFile = cacheDir.appendingPathComponent("\(hash).json")

            let subgraphs: [PDGSubgraph]
            if FileManager.default.fileExists(atPath: cacheFile.path) {
                if let cached = try? Data(contentsOf: cacheFile),
                   let decoded = try? JSONDecoder().decode([PDGSubgraph].self, from: cached) {
                    subgraphs = decoded
                } else {
                    subgraphs = buildAndCachePDG(for: fileURL, at: cacheFile)
                }
            } else {
                subgraphs = buildAndCachePDG(for: fileURL, at: cacheFile)
            }

            for sg in subgraphs {
                if sg.nodes.count >= minCloneSize {
                    allSubgraphs.append((sg, fileURL))
                }
            }
        }

        var relevantSubgraphs: [(pdg: PDGSubgraph, file: URL, nodeType: NodeType, name: String)] = []
        for fileURL in fileURLs {
            guard let src = try? String(contentsOf: fileURL) else { continue }
            let tree    = Parser.parse(source: src)
            let visitor = ASTVisitor(viewMode: .sourceAccurate)
            visitor.walk(tree)
            let builder = PDGBuilder(ast: visitor.ast)
            builder.build()

            let subs = builder.extractNormalizedSubgraphs()
            for sg in subs {
                if let fnNode = sg.nodes.first(where: { $0.astNode.type == .function }) {
                    let name = fnNode.astNode.value
                    if sg.nodes.count >= minCloneSize {
                        relevantSubgraphs.append((sg, fileURL, .function, name))
                    }
                }
                else if let clsNode = sg.nodes.first(where: { $0.astNode.type == .class1 }) {
                    let name = clsNode.astNode.value
                    if sg.nodes.count >= minCloneSize {
                        relevantSubgraphs.append((sg, fileURL, .class1, name))
                    }
                }
            }
        }

        var clones: [(URL, NodeType, String, URL, NodeType, String, Double)] = []
        for i in 0..<relevantSubgraphs.count {
            let (sg1, f1, type1, name1) = relevantSubgraphs[i]
            for j in (i+1)..<relevantSubgraphs.count {
                let (sg2, f2, type2, name2) = relevantSubgraphs[j]
                guard f1 != f2 else { continue }

                let sim = VF2SimilarityMatcher(sg1, sg2).similarity()
                if sim >= similarityThreshold {
                    clones.append((f1, type1, name1, f2, type2, name2, sim))
                }
            }
        }

        if clones.isEmpty {
            output = "No clones found (threshold = \(String(format: "%.2f", similarityThreshold)))."
        } else {
            clones.sort { $0.6 > $1.6 }
            var lines = ["Clones (≥ \(String(format: "%.2f", similarityThreshold))):"]
            for (f1, t1, n1, f2, t2, n2, sim) in clones {
                let file1 = f1.lastPathComponent
                let file2 = f2.lastPathComponent
                let header1 = "\(t1.rawValue) \(n1)"
                let header2 = "\(t2.rawValue) \(n2)"
                lines.append("🔗 \(file1) [\(header1)] ↔︎ \(file2) [\(header2)]: \(String(format: "%.2f", sim))")
            }
            output = lines.joined(separator: "\n")
        }
    }

    // MARK: Private methods

    private func getSwiftFileURLs(in directory: String) -> [URL] {
        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: directory)
        
        guard let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }
        
        var swiftFileURLs: [URL] = []
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "swift" {
                swiftFileURLs.append(fileURL)
            }
        }
        
        return swiftFileURLs
    }

    private func findClones(_ builders: [URL: PDGBuilder]) -> [CodeClone] {
        var clones: [CodeClone] = []
        let files = Array(builders.keys)
        
        for i in 0..<files.count {
            for j in (i+1)..<files.count {
                let file1 = files[i]
                let file2 = files[j]
                
                if let clone = compareFiles(file1, file2, builders: builders) {
                    clones.append(clone)
                }
            }
        }
        
        return clones.sorted { $0.similarity > $1.similarity }
    }

    func findClones(subgraphs: [PDGSubgraph], threshold: Double = 0.85) -> [(PDGSubgraph, PDGSubgraph, Double)] {
        var results = [(PDGSubgraph, PDGSubgraph, Double)]()
        var processed = Set<Int>()
        
        for i in 0..<subgraphs.count {
            guard !processed.contains(i) else { continue }
            var currentGroup = [subgraphs[i]]
            
            for j in (i+1)..<subgraphs.count {
                let similarity = subgraphs[i].similarity(to: subgraphs[j])
                if similarity >= threshold {
                    results.append((subgraphs[i], subgraphs[j], similarity))
                    processed.insert(j)
                }
            }
        }
        
        return results.sorted { $0.2 > $1.2 }
    }

    func findSemanticClones(subgraphs: [PDGSubgraph]) -> [(String, String, Double)] {
        var results = [(String, String, Double)]()
        let functionSubgraphs = subgraphs.filter { sg in
            sg.nodes.contains { $0.astNode.type == .function }
        }

        for i in 0..<functionSubgraphs.count {
            for j in (i+1)..<functionSubgraphs.count {
                let g1 = functionSubgraphs[i]
                let g2 = functionSubgraphs[j]

                let similarity = g1.semanticSimilarity(to: g2)
                print(similarity)
                if similarity >= 0.8 {
                    let name1 = g1.nodes.first { $0.astNode.type == .function }?.astNode.value ?? "?"
                    let name2 = g2.nodes.first { $0.astNode.type == .function }?.astNode.value ?? "?"
                    results.append((name1, name2, similarity))
                }
            }
        }

        return results.sorted { $0.2 > $1.2 }
    }

    private func findSemanticClones(
        subgraphs: [PDGSubgraph],
        threshold: Double
    ) -> [(String, String, Double)] {
        var results: [(String, String, Double)] = []
        for i in 0..<subgraphs.count {
            for j in (i+1)..<subgraphs.count {
                let g1 = subgraphs[i]
                let g2 = subgraphs[j]
                let sim = g1.semanticSimilarity(to: g2)
                if sim >= threshold {
                    let name1 = g1.nodes.first(where: { $0.astNode.type == .function })?.astNode.value ?? "?"
                    let name2 = g2.nodes.first(where: { $0.astNode.type == .function })?.astNode.value ?? "?"
                    results.append((name1, name2, sim))
                }
            }
        }
        return results.sorted { $0.2 > $1.2 }
    }

    private func compareFiles(_ file1: URL, _ file2: URL, builders: [URL: PDGBuilder]) -> CodeClone? {
        guard let builder1 = builders[file1], let builder2 = builders[file2] else { return nil }
        
        let subs1 = builder1.extractNormalizedSubgraphs()
        let subs2 = builder2.extractNormalizedSubgraphs()
        
        var maxSimilarity = 0.0
        var matchedSubgraphs: [(PDGSubgraph, PDGSubgraph)] = []

        for sg1 in subs1 {
            for sg2 in subs2 {
                let sim = sg1.semanticSimilarity(to: sg2)
                let sizeOk = sg1.nodes.count >= minCloneSize && sg2.nodes.count >= minCloneSize
                if sim >= similarityThreshold && sizeOk {
                    matchedSubgraphs.append((sg1, sg2))
                    maxSimilarity = max(maxSimilarity, sim)
                }
            }
        }
        
        guard maxSimilarity >= similarityThreshold else { return nil }
        
        return CodeClone(
            file1: file1,
            file2: file2,
            similarity: maxSimilarity,
            matchedSubgraphs: matchedSubgraphs
        )
    }
    
    private func calculateSimilarity(_ sg1: PDGSubgraph, _ sg2: PDGSubgraph) -> Double {
        let commonNodes = Set(sg1.nodes.map { $0.id }).intersection(sg2.nodes.map { $0.id }).count
        let totalNodes = max(sg1.nodes.count, sg2.nodes.count)
        return Double(commonNodes) / Double(totalNodes)
    }

    private func findDuplicates(in pdgs: [(pdg: PDGBuilder, file: URL)]) -> [(original: URL, duplicates: [URL])] {
        var results: [(URL, [URL])] = []

        for i in 0..<pdgs.count {
            var similarFiles: [URL] = []

            for j in i+1..<pdgs.count {
                let similarity = comparePDGs(pdgs[i].pdg, pdgs[j].pdg)
                print("similarity ", similarity)
                if similarity >= 0.3 {
                    similarFiles.append(pdgs[j].file)
                }
            }

            if !similarFiles.isEmpty {
                results.append((original: pdgs[i].file, duplicates: similarFiles))
            }
        }

        return results
    }

    private func formatDuplicates(_ duplicates: [(original: URL, duplicates: [URL])]) -> String {
        var output = ""

        for entry in duplicates {
            output += "Original File:\n\(entry.original.path)\n\nDuplicates:\n"
            for dup in entry.duplicates {
                output += "\(dup.path)\n"
            }
            output += "\n"
        }

        return output
    }

    func comparePDGs(_ pdg1: PDGBuilder, _ pdg2: PDGBuilder) -> Double {
        let subgraphs1 = pdg1.extractNormalizedSubgraphs()
        let subgraphs2 = pdg2.extractNormalizedSubgraphs()

        guard !subgraphs1.isEmpty && !subgraphs2.isEmpty else {
            return 0.0
        }

        var matchedCount = 0
        var used = Set<Int>()

        for sg1 in subgraphs1 {
            for (j, sg2) in subgraphs2.enumerated() {
                if used.contains(j) { continue }
                if sg1.structureSignature() == sg2.structureSignature() {
                    matchedCount += 1
                    used.insert(j)
                    break
                }
            }
        }

        let total = max(subgraphs1.count, subgraphs2.count)
        print(Double(matchedCount) / Double(total))
        return total > 0 ? Double(matchedCount) / Double(total) : 0.0
    }

        private func buildAndCachePDG(for fileURL: URL, at cacheFile: URL) -> [PDGSubgraph] {
                do {
                    let src      = try String(contentsOf: fileURL)
                    let syntax   = Parser.parse(source: src)
                    let visitor  = ASTVisitor(viewMode: .sourceAccurate)
                    visitor.walk(syntax)
                    let builder  = PDGBuilder(ast: visitor.ast)
                    builder.build()
                    let subs = builder.extractNormalizedSubgraphs()
                    // сериализуем
                    if let enc = try? JSONEncoder().encode(subs) {
                        try? enc.write(to: cacheFile, options: .atomic)
                    }
                    return subs
                } catch {
                    print("PDG build error for \(fileURL.lastPathComponent): \(error)")
                    return []
                }
            }
}

struct CodeClone {
    let file1: URL
    let file2: URL
    let similarity: Double
    let matchedSubgraphs: [(PDGSubgraph, PDGSubgraph)]
    
    var description: String {
        let header = String(
            format: "Clone between\n  %@\n  %@\nSimilarity: %.2f\nMatched subgraphs: %d",
            file1.lastPathComponent,
            file2.lastPathComponent,
            similarity,
            matchedSubgraphs.count
        )
        return header
    }
}
