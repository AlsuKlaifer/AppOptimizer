//
//  PDGBuilder.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 07.04.2025.
//

import Foundation

class PDGBuilder {
    let ast: AST
    var nodes: [PDGNode] = []
    var edges: [(from: PDGNode, to: PDGNode, type: PDGEdgeType)] = []
    private var nodeMap = [ASTNode: PDGNode]()
    
    init(ast: AST) {
        self.ast = ast
    }
    
    func build() {
        buildNodes()
        buildControlDependencies()
        buildDataDependencies()
    }

    private func buildNodes() {
        func traverse(astNode: ASTNode) {
            let pdgNode = PDGNode(astNode: astNode)
            nodes.append(pdgNode)
            
            for child in astNode.children {
                traverse(astNode: child)
            }
        }
        
        traverse(astNode: ast.root)
    }
    
    private func buildControlDependencies() {
        let functionNodes = nodes.filter { $0.astNode.type == .function }
        
        for functionNode in functionNodes {
            // все дочерние узлы функции зависят от нее
            let bodyNodes = nodes.filter { $0.astNode.parent == functionNode.astNode }
            
            for bodyNode in bodyNodes {
                edges.append((functionNode, bodyNode, .control))
            }
            
            // Последовательные зависимости между операциями
            let orderedBodyNodes = bodyNodes.sorted {
                $0.astNode.sourceCode! < $1.astNode.sourceCode!
            }

            if orderedBodyNodes.count > 0 {
                for i in 0..<orderedBodyNodes.count-1 {
                    edges.append((orderedBodyNodes[i], orderedBodyNodes[i+1], .sequential))
                }
            }
        }
    }
    
    private func buildDataDependencies() {
        let variableNodes = nodes.filter { $0.astNode.type == .variable }
        
        for variableNode in variableNodes {
            // ищем узлы, которые используют эту переменную
            let usingNodes = nodes.filter { node in
                node != variableNode &&
                node.astNode.sourceCode!.contains(variableNode.astNode.value)
            }
            
            for userNode in usingNodes {
                edges.append((variableNode, userNode, .data))
            }
        }
    }

    private func buildAllNodes() {
        func traverse(astNode: ASTNode) {
            let pdgNode = PDGNode(astNode: astNode)
            nodes.append(pdgNode)
            nodeMap[astNode] = pdgNode
            
            for child in astNode.children {
                traverse(astNode: child)
            }
        }
        
        traverse(astNode: ast.root)
    }
    
    private func buildAllDependencies() {
        // Control dependencies (по родительской иерархии)
        for node in nodes {
            if let parent = node.astNode.parent,
               let parentPDGNode = nodeMap[parent] {
                edges.append((parentPDGNode, node, .control))
            }
        }
        
        // Data dependencies (использование переменных)
        buildDataDependencies()
        
        // Sequential dependencies (порядок выполнения)
        buildSequentialDependencies()
    }

    private func buildSequentialDependencies() {
        let functionNodes = nodes.filter { $0.astNode.type == .function }
        
        for functionNode in functionNodes {
            // находим все узлы, принадлежащие этой функции (включая вложенные)
            var functionBody = nodes.filter { node in
                var current: ASTNode? = node.astNode
                while let parent = current?.parent {
                    if parent == functionNode.astNode {
                        return true
                    }
                    current = parent
                }
                return false
            }
            
            // добавляем саму функцию в начало
            functionBody.insert(functionNode, at: 0)
            
            // сортируем узлы по позиции в исходном коде
            functionBody.sort { a, b in
                guard let rangeA = a.astNode.sourceRange,
                      let rangeB = b.astNode.sourceRange else {
                    return false
                }
                return rangeA.lowerBound < rangeB.lowerBound
            }
            
            // строим последовательные зависимости
            for i in 0..<functionBody.count-1 {
                edges.append((functionBody[i], functionBody[i+1], .sequential))
            }
        }
    }
}

extension PDGBuilder {
    func extractNormalizedSubgraphs(minSize: Int = 2) -> [PDGSubgraph] {
        var subgraphs: [PDGSubgraph] = []
        let functionNodes = nodes.filter { $0.astNode.type == .function }
        
        for functionNode in functionNodes {
            // находим все узлы, связанные с функцией
            var relatedNodes = nodes.filter { node in
                if node == functionNode { return true }

                var isRelated = false
                
                // проверяем parent-child связь
                var current: ASTNode? = node.astNode
                while let parent = current?.parent {
                    if parent == functionNode.astNode {
                        isRelated = true
                        break
                    }
                    current = parent
                }
                
                // проверяем зависимости
                if !isRelated {
                    isRelated = edges.contains { $0.from == functionNode && $0.to == node } ||
                               edges.contains { $0.from == node && $0.to == functionNode }
                }
                
                return isRelated
            }
            
            // находим все рёбра между этими узлами
            let relatedEdges = edges.filter { edge in
                relatedNodes.contains(edge.from) && relatedNodes.contains(edge.to)
            }

            let subgraph = PDGSubgraph(
                nodes: relatedNodes,
                edges: relatedEdges.map({ PDGEdgeCodable(from: $0.from, to: $0.to, type: $0.type)})
            )
            
            subgraphs.append(subgraph)
        }
        
        return subgraphs
    }

    // MARK: - Вспомогательные методы

    private func buildAdjacencyList() -> [PDGNode: [(PDGNode, PDGEdgeType)]] {
        var adjacencyList = [PDGNode: [(PDGNode, PDGEdgeType)]]()
        
        for edge in edges {
            adjacencyList[edge.from, default: []].append((edge.to, edge.type))
        }
        
        return adjacencyList
    }

    private func extractSubgraph(for rootNode: PDGNode,
                               depth: Int,
                               adjacencyList: [PDGNode: [(PDGNode, PDGEdgeType)]])
    -> (nodes: Set<PDGNode>, edges: [(from: PDGNode, to: PDGNode, type: PDGEdgeType)]) {
        var visited = Set<UUID>()
        var queue: [(PDGNode, Int)] = [(rootNode, 0)]
        var sgNodes: Set<PDGNode> = []
        var sgEdges: [(from: PDGNode, to: PDGNode, type: PDGEdgeType)] = []
        
        while !queue.isEmpty {
            let (current, level) = queue.removeFirst()
            
            // проверяем глубину и посещенные узлы
            guard level <= depth, !visited.contains(current.id) else { continue }
            
            visited.insert(current.id)
            sgNodes.insert(current)
            
            // добавляем соседей в очередь
            for (neighbor, edgeType) in adjacencyList[current, default: []] {
                sgEdges.append((from: current, to: neighbor, type: edgeType))
                
                // не добавляем в очередь, если достигли максимальной глубины
                if level < depth {
                    queue.append((neighbor, level + 1))
                }
            }
        }
        
        return (sgNodes, sgEdges)
    }

    private func normalizeSubgraph(nodes: Set<PDGNode>,
                                 edges: [(from: PDGNode, to: PDGNode, type: PDGEdgeType)])
    -> PDGSubgraph {
        let normalizedNodes = nodes.map { node in
            if node.astNode.type == .variable {
                let normalizedValue = "var_" + String(node.astNode.value.hashValue)
                let normalizedNode = PDGNode(
                    astNode: ASTNode(
                        type: node.astNode.type,
                        value: normalizedValue,
                        sourceCode: node.astNode.sourceCode ?? "",
                        classType: node.astNode.classType,
                        variableType: node.astNode.variableType
                    )
                )
                return normalizedNode
            }
            return node
        }

        let normalizedEdges = edges.map { edge in
            let fromNode = normalizedNodes.first { $0.astNode.value == edge.from.astNode.value } ?? edge.from
            let toNode = normalizedNodes.first { $0.astNode.value == edge.to.astNode.value } ?? edge.to
            return (from: fromNode, to: toNode, type: edge.type)
        }
        
        return PDGSubgraph(
            nodes: normalizedNodes,
            edges: normalizedEdges.map({ PDGEdgeCodable(from: $0.from, to: $0.to, type: $0.type)})
        )
    }

    func extractFunctionNodes() -> [PDGNode] {
        let functions = nodes.filter { node in
            let isFunction = node.astNode.type == .function
            print("Node \(node.astNode.value) is function: \(isFunction)")
            return isFunction
        }
        
        print("Total function nodes found: \(functions.count)")
        print("All node types:", nodes.map { $0.astNode.type })
        return functions
    }
}
