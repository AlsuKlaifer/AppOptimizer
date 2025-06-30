//
//  ASTNode.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 21.03.2025.
//

import Foundation

enum NodeType: String, Hashable, Codable {
    case root
    case class1
    case variable
    case function
    case functionCall
    case value
}

class ASTNode {

    private enum CodingKeys: String, CodingKey {
        case id, type, value, children, sourceCode, classType, variableType
    }

    // MARK: Properties

    let id: UUID
    let type: NodeType
    let value: String
    var children: [ASTNode] = []

    var sourceCode: String? = nil
    var classType: String? = nil
    var variableType: String? = nil
    var sourceRange: Range<String.Index>?

    weak var parent: ASTNode?

    // MARK: Lifecycle

    init(
        type: NodeType,
        value: String,
        sourceCode: String,
        classType: String? = nil,
        variableType: String? = nil,
        parent: ASTNode? = nil,
        sourceRange: Range<String.Index>? = nil
    ) {
        self.id = UUID()
        self.type = type
        self.value = value
        self.sourceCode = sourceCode
        self.classType = classType
        self.variableType = variableType
        self.parent = parent
        self.sourceRange = sourceRange
    }

    // MARK: Internal methods

    func addChild(_ node: ASTNode) {
        node.parent = self
        children.append(node)
    }

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

    // MARK: Private methods

    private func compareSubtreesIgnoringNames(_ node1: ASTNode, _ node2: ASTNode, _ variableMapping: inout [String: String]) -> Double {
        let sequence1 = node1.children.map { $0.getSignature() }
        let sequence2 = node2.children.map { $0.getSignature() }
        
        let lcsLength = longestCommonSubsequence(sequence1, sequence2)
        return Double(lcsLength) / Double(max(sequence1.count, sequence2.count))
    }

    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id           = try container.decode(UUID.self,      forKey: .id)
        let type         = try container.decode(NodeType.self,  forKey: .type)
        let value        = try container.decode(String.self,    forKey: .value)
        let children     = try container.decode([ASTNode].self, forKey: .children)
        let sourceCode   = try container.decodeIfPresent(String.self, forKey: .sourceCode)
        let classType    = try container.decodeIfPresent(String.self, forKey: .classType)
        let variableType = try container.decodeIfPresent(String.self, forKey: .variableType)

        // Создаем через основной инициализатор, он установит parent для детей
        self.init(
            type: type,
            value: value,
            sourceCode: sourceCode ?? "",
            classType: classType,
            variableType: variableType
        )
    }
}

extension ASTNode: Hashable {
    static func == (lhs: ASTNode, rhs: ASTNode) -> Bool {
        return lhs.type == rhs.type && lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(value)
    }
}

extension ASTNode: Codable {

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id,           forKey: .id)
        try container.encode(type,         forKey: .type)
        try container.encode(value,        forKey: .value)
        try container.encode(children,     forKey: .children)
        try container.encodeIfPresent(sourceCode,   forKey: .sourceCode)
        try container.encodeIfPresent(classType,    forKey: .classType)
        try container.encodeIfPresent(variableType, forKey: .variableType)
    }
}
