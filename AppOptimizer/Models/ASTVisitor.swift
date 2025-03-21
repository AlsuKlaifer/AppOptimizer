//
//  ASTVisitor.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 21.03.2025.
//

import Foundation
import SwiftSyntax

class ASTVisitor: SyntaxVisitor {

    // MARK: Properties

    var ast = AST()
    var pdgGraph = PDGGraph()
    private var currentFunction: ASTNode?

    // MARK: SyntaxVisitor

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let classNode = ASTNode(type: .class1, value: "class", sourceCode: node.description, classType: node.name.text)
        ast.root.children.append(classNode)
        return .visitChildren
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let functionNode = ASTNode(type: .function, value: "func", sourceCode: node.description)
        ast.root.children.append(functionNode)
        currentFunction = functionNode
        pdgGraph.addNode(functionNode)
        return .visitChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        for binding in node.bindings {
            if let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
               let typeAnnotation = binding.typeAnnotation?.type.description {
                
                let variableNode = ASTNode(type: .variable, value: identifier, sourceCode: node.description, variableType: typeAnnotation)
                ast.root.children.append(variableNode)

                if let function = currentFunction {
                    pdgGraph.addEdge(from: function, to: variableNode)
                }
            }
        }
        return .skipChildren
    }
}
