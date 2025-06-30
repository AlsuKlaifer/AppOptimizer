//
//  PDGDuplicateCodeManager.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 21.03.2025.
//

import Foundation
import SwiftSyntax
import SwiftParser
import SwiftSyntaxBuilder

class ASTDuplicateCodeManager {

    // MARK: Properties

    let appPath: String

    // MARK: Lifecycle

    init(appPath: String) {
        self.appPath = appPath
    }

    // MARK: Internal methods

    func analyzeDuplicates(outputFile: inout String) {
        let fileURLs = getSwiftFileURLs(in: appPath)
        var asts: [AST] = []
        
        for fileURL in fileURLs {
            do {
                let sourceFile = try Parser.parse(source: String(contentsOf: fileURL))
                let visitor = ASTVisitor(viewMode: .sourceAccurate)
                visitor.walk(sourceFile)
                asts.append(visitor.ast)
            } catch {
                print("Error parsing file: \(fileURL.path), error: \(error)")
            }
        }
        
        let duplicates = findDuplicates(in: asts)
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
    
    private func findDuplicates(in asts: [AST]) -> [AST: [AST]] {
        var duplicates: [AST: [AST]] = [:]
        
        for i in 0..<asts.count {
            for j in i+1..<asts.count {
                var variableMapping: [String: String] = [:]
                let similarity = asts[i].similarity(to: asts[j], variableMapping: &variableMapping)
                print(similarity)
                if similarity >= 0.5 {
                    duplicates[asts[i], default: []].append(asts[j])
                }
            }
        }
        
        return duplicates
    }
    
    private func formatDuplicates(_ duplicates: [AST: [AST]]) -> String {
        var output = ""
        for (original, copies) in duplicates {
            output += "Original:\n\(original.getSourceCode())\n\nDuplicates:\n"
            for copy in copies {
                output += copy.getSourceCode() + "\n"
            }
            output += "\n"
        }
        return output
    }
}
