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

class PDGDuplicateCodeManager {

    // MARK: Properties

    private let appPath: String
    private let minCloneSize: Int
    private let similarityThreshold: Double

    // MARK: Lifecycle

    init(appPath: String, minCloneSize: Int = 3, similarityThreshold: Double = 0.7) {
        self.appPath = appPath
        self.minCloneSize = minCloneSize
        self.similarityThreshold = similarityThreshold
    }

    // MARK: Internal methods

    func analyzeDuplicates(outputFile: inout String) {
        let fileURLs = getSwiftFileURLs(in: appPath)
        var pdgBuilders: [URL: PDGBuilder] = [:]

        // Построение PDG для каждого файла
        for fileURL in fileURLs {
           do {
               let source = try String(contentsOf: fileURL)
               let sourceFile = Parser.parse(source: source)
               let visitor = ASTVisitor(viewMode: .sourceAccurate)
               visitor.walk(sourceFile)
               
               let pdgBuilder = PDGBuilder(ast: visitor.ast)
               pdgBuilder.build()
               pdgBuilders[fileURL] = pdgBuilder
           } catch {
               print("Error processing file \(fileURL.lastPathComponent): \(error)")
           }
        }

        // Поиск клонов
        let clones = findClones(pdgBuilders)
        print(clones.count)
        for clone in clones {
            outputFile += clone.description
        }
        print(outputFile)
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
                if similarity >= 0.85 {
                    let name1 = g1.nodes.first { $0.astNode.type == .function }?.astNode.value ?? "?"
                    let name2 = g2.nodes.first { $0.astNode.type == .function }?.astNode.value ?? "?"
                    results.append((name1, name2, similarity))
                }
            }
        }
        
        return results.sorted { $0.2 > $1.2 }
    }

    private func compareFiles(_ file1: URL, _ file2: URL, builders: [URL: PDGBuilder]) -> CodeClone? {
        guard let builder1 = builders[file1], let builder2 = builders[file2] else { return nil }
        
        let subgraphs1 = builder1.extractNormalizedSubgraphs()
        let subgraphs2 = builder2.extractNormalizedSubgraphs()
        
        var maxSimilarity = 0.0
        var matchedSubgraphs: [(PDGSubgraph, PDGSubgraph)] = []
        
        for sg1 in subgraphs1 {
            for sg2 in subgraphs2 {
                if sg1.isIsomorphic(to: sg2) {
                    let similarity = calculateSimilarity(sg1, sg2)
                    if similarity > maxSimilarity {
                        maxSimilarity = similarity
                    }
                    matchedSubgraphs.append((sg1, sg2))
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
}

struct CodeClone {
    let file1: URL
    let file2: URL
    let similarity: Double
    let matchedSubgraphs: [(PDGSubgraph, PDGSubgraph)]
    
    var description: String {
        """
        Found clone with similarity \(String(format: "%.2f", similarity * 100))%
        File 1: \(file1.path)
        File 2: \(file2.path)
        Matched subgraphs: \(matchedSubgraphs.count)
        """
    }
}
