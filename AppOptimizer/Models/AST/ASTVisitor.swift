//
//  ASTVisitor.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 21.03.2025.
//

import Foundation
import SwiftSyntax
import SwiftParser

class ASTVisitor: SyntaxVisitor {
    
    // MARK: - Properties
    
    let ast = AST()

    private var currentParent: ASTNode?
    private var currentSource: String = ""
    private var sourceLocationConverter: SourceLocationConverter?
    private var variableNormalizationMap = [String: String]()
    private var currentVariableIndex = 0
    private var currentFunction: ASTNode?
    private var functionCount = 0
    private var nodeStack = [ASTNode]()

    // MARK: SyntaxVisitor Overrides

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let functionNode = ASTNode(
            type: .function,
            value: node.identifier.text,
            sourceCode: node.description.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        // Добавляем функцию в текущий контекст
        if let parent = nodeStack.last {
            parent.addChild(functionNode)
        } else {
            ast.root.addChild(functionNode)
        }
        
        // Сохраняем текущую функцию и добавляем в стек
        currentFunction = functionNode
        nodeStack.append(functionNode)
        
        return .visitChildren
    }
    
    override func visitPost(_ node: FunctionDeclSyntax) {
        nodeStack.removeLast()
        currentFunction = nodeStack.last
    }
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let currentFunction = currentFunction else { return .skipChildren }
        
        for binding in node.bindings {
            if let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text {
                let variableNode = ASTNode(
                    type: .variable,
                    value: identifier,
                    sourceCode: node.description.trimmingCharacters(in: .whitespacesAndNewlines),
                    variableType: binding.typeAnnotation?.type.description
                )
                currentFunction.addChild(variableNode)
            }
        }
        return .skipChildren
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let currentFunction = currentFunction else { return .skipChildren }
        
        let callNode = ASTNode(
            type: .functionCall,
            value: node.calledExpression.description.trimmingCharacters(in: .whitespacesAndNewlines),
            sourceCode: node.description.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        currentFunction.addChild(callNode)
        
        return .skipChildren
    }

    // MARK: - Public Interface
    
    func visit(source: String) {
        self.currentSource = source
        let sourceFile = Parser.parse(source: source)
        self.walk(sourceFile)
        print("Found \(functionCount) functions during visitation")
    }

    // MARK: Private methods

    private func pushNode(_ node: ASTNode) {
        addNodeToCurrentParent(node)
        nodeStack.append(currentParent ?? ast.root)
        currentParent = node
    }
    
    private func popNode() {
        currentParent = nodeStack.popLast()
    }
    
    private func addNodeToCurrentParent(_ node: ASTNode) {
        if let parent = currentParent {
            parent.addChild(node)
        } else {
            ast.root.addChild(node)
        }
    }

    private func safeSourceRange(for syntaxNode: SyntaxProtocol) -> Range<String.Index>? {
        guard let converter = sourceLocationConverter else { return nil }
        
        let startPosition = syntaxNode.positionAfterSkippingLeadingTrivia
        let endPosition = syntaxNode.endPositionBeforeTrailingTrivia
        
        let startOffset = converter.location(for: startPosition).offset
        let endOffset = converter.location(for: endPosition).offset
        
        guard startOffset >= 0,
              endOffset <= currentSource.count,
              startOffset <= endOffset else {
            return nil
        }
        
        let startIndex = currentSource.index(currentSource.startIndex, offsetBy: startOffset)
        let endIndex = currentSource.index(currentSource.startIndex, offsetBy: endOffset)
        print("Range: \(startOffset)...\(endOffset) for \(type(of: syntaxNode))")
        return startIndex..<endIndex
    }
    
    private func normalizeVariableName(_ original: String) -> String {
        if let normalized = variableNormalizationMap[original] {
            return normalized
        }
        let normalized = "var\(currentVariableIndex)"
        variableNormalizationMap[original] = normalized
        currentVariableIndex += 1
        return normalized
    }
}
