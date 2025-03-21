//
//  AST.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 21.03.2025.
//

import Foundation
import SwiftSyntax

struct AST: Hashable {
    var root = ASTNode(type: .root, value: "root")
    
    func similarity(to other: AST, variableMapping: inout [String: String]) -> Double {
        return root.similarity(to: other.root, variableMapping: &variableMapping)
    }

    func getSourceCode() -> String {
        return root.getSourceCode()
    }
}
