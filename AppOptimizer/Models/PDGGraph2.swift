//
//  PDG2.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 21.03.2025.
//

import SwiftGraph

//class PDG2 {
//
//    // MARK: Properties
//
//    var graph = UnweightedGraph<ASTNode>()
//
//    // Добавление вершины
//    func addNode(_ node: ASTNode) {
//        graph.addVertex(node)
//    }
//
//    // Добавление ребра
//    func addEdge(from: ASTNode, to: ASTNode) {
//        if !graph.vertices.contains(from) {
//            graph.addVertex(from)
//        }
//        if !graph.vertices.contains(to) {
//            graph.addVertex(to)
//        }
//        graph.addEdge(from: from, to: to, directed: true)
//        print("Добавлено ребро: \(from.value) → \(to.value)")
//    }
//
//    // Поиск схожих функций
//    func findSimilarFunctions() -> [(ASTNode, ASTNode)] {
//        var duplicates: [(ASTNode, ASTNode)] = []
//        let functions = graph.vertices.filter { $0.type == .function }
//
//        for i in 0..<functions.count {
//            for j in (i + 1)..<functions.count {
//                let func1 = functions[i]
//                let func2 = functions[j]
//
//                if isSemanticallySimilar(func1, func2) {
//                    duplicates.append((func1, func2))
//                }
//            }
//        }
//        return duplicates
//    }
//
//    // Проверка на схожесть функций (по соседям)
//    private func isSemanticallySimilar(_ func1: ASTNode, _ func2: ASTNode) -> Bool {
//        let neighbors1 = graph.neighborsForVertex(func1) ?? []
//        let neighbors2 = graph.neighborsForVertex(func2) ?? []
//
//        let neighborsSet1 = Set(neighbors1)
//        let neighborsSet2 = Set(neighbors2)
//
//        let intersection = neighborsSet1.intersection(neighborsSet2)
//        let similarity = Double(intersection.count) / Double(max(neighbors1.count, neighbors2.count))
//
//        return similarity > 0.8  // 70% схожести считаем дубликатом
//    }
//}
