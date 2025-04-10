//
//  ASTVisitor2.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 21.03.2025.
//

import Foundation
import SwiftSyntax

//class ASTVisitor2: SyntaxVisitor {
//
//    // MARK: Properties
//
//    var ast = AST()
//    var pdgGraph = PDGGraph()
//    private var functionStack: [ASTNode] = []
//
//    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
//        // Создаем узел для функции
//        let functionNode = ASTNode(type: .function, value: node.name.text, sourceCode: node.description)
//        ast.root.children.append(functionNode)
//        pdgGraph.addNode(functionNode)
//
//        // Добавляем функцию в стек
//        functionStack.append(functionNode)
//
//        print("Обнаружена функция: \(functionNode.value), functionStack: \(functionStack.map { $0.value })")
//
//        // Обрабатываем параметры функции
//        let parameterClause = node.signature.parameterClause
//        for parameter in parameterClause.parameters {
//            _ = visit(parameter)
//        }
//
//        // Обрабатываем тело функции (переменные)
//        if let body = node.body {
//            _ = visit(body)
//        }
//
//        // После обработки всех переменных внутри функции, привязываем их к функции
//        if let functionNode = functionStack.last {
//            for child in ast.root.children where child.type == .variable {
//                pdgGraph.addEdge(from: functionNode, to: child)
//            }
//        }
//
//        // Удаляем функцию из стека, после завершения ее обработки
//        if !functionStack.isEmpty {
//            print("Удаляем из functionStack: \(functionStack.last?.value ?? "nil")")
//            functionStack.removeLast()
//        }
//
//        return .skipChildren
//    }
//
//    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
//        for binding in node.bindings {
//            if let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
//               let typeAnnotation = binding.typeAnnotation?.type.description {
//                
//                // Создаем узел для переменной
//                let variableNode = ASTNode(type: .variable, value: identifier, sourceCode: node.description, variableType: typeAnnotation)
//                ast.root.children.append(variableNode)
//
//                // Привязываем переменную к текущей функции
//                if let functionNode = functionStack.last {
//                    pdgGraph.addEdge(from: functionNode, to: variableNode)
//                }
//            }
//        }
//
//        return .skipChildren
//    }
//}
