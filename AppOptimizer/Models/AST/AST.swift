//
//  AST.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 21.03.2025.
//

import Foundation
import SwiftSyntax

struct AST {

    // MARK: Properties

    var root = ASTNode(type: .root, value: "root", sourceCode: "")

    // MARK: Internal methods

    func similarity(to other: AST, variableMapping: inout [String: String]) -> Double {
        return root.similarity(to: other.root, variableMapping: &variableMapping)
    }

    func getSourceCode() -> String {
        return root.getSourceCode()
    }
}

// MARK: Hashable & Equatable

extension AST: Hashable {

    // Equatable
    static func == (lhs: AST, rhs: AST) -> Bool {
        return lhs.root == rhs.root
    }

    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(root)
    }
}
