//
//  AST2.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 21.03.2025.
//

import Foundation
import SwiftSyntax

struct AST2 {

    // MARK: Properties

    var root = ASTNode(type: .root, value: "root", sourceCode: "")
    var nodes: [ASTNode] = []

    init(root: ASTNode = ASTNode(type: .root, value: "root", sourceCode: ""), nodes: [ASTNode] = []) {
        self.root = root
        self.nodes = nodes
    }

    // MARK: Internal methods

    func similarity(to other: AST, variableMapping: inout [String: String]) -> Double {
        return root.similarity(to: other.root, variableMapping: &variableMapping)
    }

    func getSourceCode() -> String {
        return root.getSourceCode()
    }
}

// MARK: Hashable & Equatable

extension AST2: Hashable {

    // Equatable
    static func == (lhs: AST2, rhs: AST2) -> Bool {
        return lhs.root == rhs.root
    }

    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(root)
    }
}
