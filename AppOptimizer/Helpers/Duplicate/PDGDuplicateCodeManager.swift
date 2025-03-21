//
//  PDGDuplicateCodeManager.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 21.03.2025.
//

import Foundation
import SwiftParser

class PDGDuplicateCodeManager {

    // MARK: Properties

    let appPath: String

    // MARK: Lifecycle

    init(appPath: String) {
        self.appPath = appPath
    }

    // MARK: Internal methods

    func analyzeDuplicates(outputFile: inout String) {
        let fileURLs = getSwiftFileURLs(in: appPath)
        var pdgGraphs: [PDGGraph] = []
        
        for fileURL in fileURLs {
            do {
                let sourceFile = try Parser.parse(source: String(contentsOf: fileURL))
                let visitor = ASTVisitor(viewMode: .sourceAccurate) // Используем ранее описанный ASTVisitor
                visitor.walk(sourceFile)
                
                let pdgGraph = visitor.pdgGraph // Граф зависимостей из ASTVisitor
                pdgGraphs.append(pdgGraph)
            } catch {
                print("Error parsing file: \(fileURL.path), error: \(error)")
            }
        }
        
        let duplicates = findDuplicates(in: pdgGraphs)
        outputFile = formatDuplicates(duplicates)
        print("outputFile:\n", outputFile)
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
    
    private func findDuplicates(in pdgGraphs: [PDGGraph]) -> [(ASTNode, ASTNode)] {
        var duplicates: [(ASTNode, ASTNode)] = []
        
        for graph in pdgGraphs {
            let similarFunctions = graph.findSimilarFunctions() // Используем метод поиска схожих функций в PDG
            duplicates.append(contentsOf: similarFunctions)
        }
        
        return duplicates
    }
    
    private func formatDuplicates(_ duplicates: [(ASTNode, ASTNode)]) -> String {
        var output = ""
        for (original, copy) in duplicates {
            output += "Original:\n\(original.getSourceCode())\n\nDuplicate:\n\(copy.getSourceCode())\n\n"
        }
        return output
    }
}
