//
//  PDGGraph.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 21.03.2025.
//

import SwiftGraph

class PDGGraph {

    // MARK: Properties

    var graph = UnweightedGraph<ASTNode>()

    // MARK: Internal methods

    func addNode(_ node: ASTNode) {
        graph.addVertex(node)
    }

    func addEdge(from: ASTNode, to: ASTNode) {
        graph.addEdge(from: from, to: to, directed: true)
    }

    func findSimilarFunctions() -> [(ASTNode, ASTNode)] {
        var duplicates: [(ASTNode, ASTNode)] = []
        let functions = graph.vertices.filter { $0.type == .function }

        for i in 0..<functions.count {
            for j in (i + 1)..<functions.count {
                let func1 = functions[i]
                let func2 = functions[j]

                if isSemanticallySimilar(func1, func2) {
                    duplicates.append((func1, func2))
                }
            }
        }
        return duplicates
    }

    // MARK: Private methods

    private func isSemanticallySimilar(_ func1: ASTNode, _ func2: ASTNode) -> Bool {
        let neighbors1 = graph.neighborsForVertex(func1) ?? []
        let neighbors2 = graph.neighborsForVertex(func2) ?? []

        let neighborsSet1 = Set(neighbors1)
        let neighborsSet2 = Set(neighbors2)

        let intersection = neighborsSet1.intersection(neighborsSet2)
        let similarity = Double(intersection.count) / Double(max(neighbors1.count, neighbors2.count))

        return similarity > 0.7  // 70% схожести считаем дубликатом
    }
}
