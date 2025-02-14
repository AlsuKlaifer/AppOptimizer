import Foundation
import SwiftSyntax
import SwiftParser
import SwiftSyntaxBuilder

class DuplicateCodeManager {
    let appPath: String
    
    init(appPath: String) {
        self.appPath = appPath
    }
    
    func analyzeDuplicates(outputFile: inout String) {
        let fileURLs = getSwiftFileURLs(in: appPath)
        var astTrees: [ASTTree] = []
        
        for fileURL in fileURLs {
            do {
                let sourceFile = try Parser.parse(source: String(contentsOf: fileURL))
                let visitor = ASTTreeVisitor(viewMode: .sourceAccurate)
                visitor.walk(sourceFile)
                astTrees.append(visitor.astTree)
            } catch {
                print("Error parsing file: \(fileURL.path), error: \(error)")
            }
        }
        
        let duplicates = findDuplicates(in: astTrees)
        outputFile = formatDuplicates(duplicates)
        print("outputFile:\n", outputFile)
    }
    
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
    
    private func findDuplicates(in astTrees: [ASTTree]) -> [ASTTree: [ASTTree]] {
        var duplicates: [ASTTree: [ASTTree]] = [:]
        
        for i in 0..<astTrees.count {
            for j in i+1..<astTrees.count {
                var variableMapping: [String: String] = [:]
                let similarity = astTrees[i].similarity(to: astTrees[j], variableMapping: &variableMapping)
                print(similarity)
                if similarity > 0.45 { // Допускаем небольшие различия
                    duplicates[astTrees[i], default: []].append(astTrees[j])
                }
            }
        }
        
        return duplicates
    }
    
    private func formatDuplicates(_ duplicates: [ASTTree: [ASTTree]]) -> String {
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

class ASTTreeVisitor: SyntaxVisitor {
    var astTree = ASTTree()
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let classNode = ASTNode(type: .class1, value: "class", sourceCode: node.description, classType: node.identifier.text)
        astTree.root.children.append(classNode)
        return .visitChildren
    }
    
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let functionNode = ASTNode(type: .function, value: "func", sourceCode: node.description)
        astTree.root.children.append(functionNode)
        return .visitChildren
    }
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        for binding in node.bindings {
            if let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
               let typeAnnotation = binding.typeAnnotation?.type.description {
                
                let variableNode = ASTNode(type: .variable, value: identifier, sourceCode: node.description, variableType: typeAnnotation)
                astTree.root.children.append(variableNode)
            }
        }
        return .skipChildren
    }
}

struct ASTTree: Hashable {
    var root = ASTNode(type: .root, value: "root")
    
    func similarity(to other: ASTTree, variableMapping: inout [String: String]) -> Double {
        return root.similarity(to: other.root, variableMapping: &variableMapping)
    }

    func getSourceCode() -> String {
        return root.getSourceCode()
    }
}

struct ASTNode: Hashable {
    enum NodeType: Hashable {
        case root, class1, variable, function, functionCall, value
    }
    
    let type: NodeType
    let value: String
    var children: [ASTNode] = []
    var sourceCode: String? = nil
    var classType: String? = nil
    var variableType: String? = nil
    
    func similarity(to other: ASTNode, variableMapping: inout [String: String]) -> Double {
        if self.type != other.type {
            return 0.0
        }
        
        if self.type == .variable, let selfVarType = self.variableType, let otherVarType = other.variableType, selfVarType != otherVarType {
            return 0.0
        }
        
        if self.type == .class1, let selfClass = self.classType, let otherClass = other.classType, selfClass != otherClass {
            return 0.0
        }
        
        return compareSubtreesIgnoringNames(self, other, &variableMapping)
    }
    
    private func compareSubtreesIgnoringNames(_ node1: ASTNode, _ node2: ASTNode, _ variableMapping: inout [String: String]) -> Double {
        let sequence1 = node1.children.map { $0.getSignature() }
        let sequence2 = node2.children.map { $0.getSignature() }
        
        let lcsLength = longestCommonSubsequence(sequence1, sequence2)
        return Double(lcsLength) / Double(max(sequence1.count, sequence2.count))
    }

    func longestCommonSubsequence(_ list1: [String], _ list2: [String]) -> Int {
        let m = list1.count
        let n = list2.count
        if m == 0 || n == 0 {
            return 0
        }
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 1...m {
            for j in 1...n {
                if list1[i - 1] == list2[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        return dp[m][n]
    }

    func getSignature() -> String {
        switch self.type {
        case .function:
            return "func(…) -> { \(children.map { $0.getSignature() }.joined(separator: "; ")) }"
        case .class1:
            return "class \(classType ?? "") { \(children.map { $0.getSignature() }.joined(separator: "; ")) }"
        case .variable:
            return "var(\(variableType ?? ""))"
        default:
            return value
        }
    }

    func getSourceCode() -> String {
        var result = sourceCode ?? ""
        for child in children {
            result += child.getSourceCode()
        }
        return result
    }
}
