//
//  PDGNode.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 07.04.2025.
//

import Foundation

struct PDGNode: Hashable, Codable {
    let id: UUID
    let astNode: ASTNode
    let type: PDGNodeType?
    
    init(astNode: ASTNode, type: PDGNodeType? = nil) {
        self.id = UUID()
        self.astNode = astNode
        self.type = type
    }

    func signature() -> String {
        return astNode.getSignature()
    }
}

extension PDGNode {
    func subgraphSignature(depth: Int = 2) -> String {
        // возвращаем сигнатуру этого узла и его детей до depth слоёв
        var result = [signature()]
        var frontier: [(PDGNode, Int)] = [(self, 0)]

        while let (current, level) = frontier.first {
            frontier.removeFirst()

            guard level < depth else { continue }

            // ищем соседей по управляющим и данным зависимостям
            let connectedNodes = getConnectedNodes(from: current)
            for neighbor in connectedNodes {
                result.append(neighbor.signature())
                frontier.append((neighbor, level + 1))
            }
        }

        return result.sorted().joined(separator: ";")
    }

    private func getConnectedNodes(from node: PDGNode) -> [PDGNode] {
        return PDGGraph.shared.edges
            .filter { $0.from == node }
            .map { $0.to }
    }
}

extension PDGNode {
    func semanticTypeSignature() -> String {
        return astNode.type.rawValue
    }
}

extension PDGNode {
    func semanticSignature() -> String {
        var components: [String] = []

        components.append(astNode.type.rawValue) // тип узла

        if let val = astNode.value.nonEmpty {
            components.append(val)
        }

        if let classType = astNode.classType {
            components.append("class:\(classType)")
        }

        if let varType = astNode.variableType {
            components.append("var:\(varType)")
        }

        return components.joined(separator: "-")
    }
}

extension String {
    var nonEmpty: String? {
        self.isEmpty ? nil : self
    }
}
