//
//  PDGSubgraph.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 07.04.2025.
//

struct PDGSubgraph {
    let nodes: [PDGNode]
    let edges: [(from: PDGNode, to: PDGNode, type: PDGEdgeType)]

    func structureSignature() -> String {
        let nodeDescriptors = nodes.map { $0.semanticSignature() }.sorted()
        let edgeDescriptors = edges.map { edge in
            let fromSig = edge.from.semanticSignature()
            let toSig = edge.to.semanticSignature()
            return "\(fromSig)->\(edge.type)->\(toSig)"
        }.sorted()

        return (nodeDescriptors + edgeDescriptors).joined(separator: "|")
    }
}

extension PDGSubgraph {
    func isIsomorphic(to other: PDGSubgraph) -> Bool {
        // Проверка количества узлов и рёбер
        guard nodes.count == other.nodes.count,
              edges.count == other.edges.count else {
            return false
        }

        // Проверка семантической эквивалентности узлов
        let ourNodes = nodes.sorted { $0.semanticSignature() < $1.semanticSignature() }
        let theirNodes = other.nodes.sorted { $0.semanticSignature() < $1.semanticSignature() }

        for (ourNode, theirNode) in zip(ourNodes, theirNodes) {
            guard ourNode.semanticSignature() == theirNode.semanticSignature() else {
                return false
            }
        }

        // Исправленная сортировка рёбер
        let ourEdges = edges.sorted { edge1, edge2 in
            let type1 = edge1.type == .control ? 0 : 1
            let type2 = edge2.type == .control ? 0 : 1
            if type1 != type2 {
                return type1 < type2
            }
            return edge1.from.semanticSignature() < edge2.from.semanticSignature()
        }

        let theirEdges = other.edges.sorted { edge1, edge2 in
            let type1 = edge1.type == .control ? 0 : 1
            let type2 = edge2.type == .control ? 0 : 1
            if type1 != type2 {
                return type1 < type2
            }
            return edge1.from.semanticSignature() < edge2.from.semanticSignature()
        }

        for (ourEdge, theirEdge) in zip(ourEdges, theirEdges) {
            guard ourEdge.type == theirEdge.type,
                  ourEdge.from.semanticSignature() == theirEdge.from.semanticSignature(),
                  ourEdge.to.semanticSignature() == theirEdge.to.semanticSignature() else {
                return false
            }
        }

        return true
    }
}

extension PDGSubgraph {
    func normalizedStructure() -> String {
        let normalizedNodes = nodes.map {
            "\($0.astNode.type)-\($0.astNode.variableType ?? "")"
        }.sorted().joined(separator: "|")
        
        let normalizedEdges = edges.map {
            "\($0.type)-\($0.from.astNode.type)-\($0.to.astNode.type)"
        }.sorted().joined(separator: "|")
        
        return normalizedNodes + "||" + normalizedEdges
    }
    
    func isClone(of other: PDGSubgraph) -> Bool {
        return self.normalizedStructure() == other.normalizedStructure()
    }
}

// 4. Метод сравнения подграфов
extension PDGSubgraph {
    func normalizedSignature() -> String {
        let nodeTypes = nodes.map { $0.astNode.type.rawValue }.sorted().joined(separator: "|")
        let edgeTypes = edges.map { $0.type.rawValue }.sorted().joined(separator: "|")
        return "NODES: \(nodeTypes) || EDGES: \(edgeTypes)"
    }
}

extension PDGSubgraph {
    func enhancedNormalizedSignature() -> String {
        let nodeSignatures = nodes.map {
            "\($0.astNode.type)-\($0.astNode.variableType ?? $0.astNode.classType ?? "")"
        }.sorted().joined(separator: "|")
        
        let edgeSignatures = edges.map {
            "\($0.type)-\($0.from.astNode.type)-\($0.to.astNode.type)"
        }.sorted().joined(separator: "|")
        
        return nodeSignatures + "||" + edgeSignatures
    }

    func visualizeSubgraph(_ sg: PDGSubgraph) {
        print("GraphViz representation:")
        print("digraph {")
        for node in sg.nodes {
            print("  \"\(node.astNode.value)\" [label=\"\(node.astNode.type)\\n\(node.astNode.value)\"]")
        }
        for edge in sg.edges {
            print("  \"\(edge.from.astNode.value)\" -> \"\(edge.to.astNode.value)\" [label=\"\(edge.type)\"]")
        }
        print("}")
    }

    func similarityBetween(_ sg1: PDGSubgraph, _ sg2: PDGSubgraph) -> Double {
        // Реализация более сложного сравнения
        // с возвратом значения от 0.0 до 1.0
        return 0.0
    }
}

extension PDGSubgraph {
    func similarity(to other: PDGSubgraph) -> Double {
        // Нормализация узлов
        let selfNodes = self.normalizedNodes()
        let otherNodes = other.normalizedNodes()
        
        // Нормализация рёбер
        let selfEdges = self.normalizedEdges()
        let otherEdges = other.normalizedEdges()
        
        // Вычисляем схожесть узлов
        let nodeSimilarity = jaccardSimilarity(selfNodes, otherNodes)
        
        // Вычисляем схожесть рёбер
        let edgeSimilarity = jaccardSimilarity(selfEdges, otherEdges)
        
        // Общая схожесть (можно настроить веса)
        return (nodeSimilarity + edgeSimilarity) / 2
    }
    
    private func normalizedNodes() -> Set<String> {
        return Set(self.nodes.map {
            switch $0.astNode.type {
            case .variable:
                return "var[\($0.astNode.variableType ?? "?")]"
            case .function:
                return "func[\($0.astNode.value)]"
            default:
                return $0.astNode.type.rawValue
            }
        })
    }
    
    private func normalizedEdges() -> Set<String> {
        return Set(self.edges.map {
            "\($0.from.astNode.type)->\($0.type)->\($0.to.astNode.type)"
        })
    }

    private func jaccardSimilarity<T: Hashable>(_ a: Set<T>, _ b: Set<T>) -> Double {
        // поправить для операции внутри функций (досттаь соурс код и найти меру жаккарда)
        // мб использовать расстояние левенштейна или https://habr.com/ru/companies/skillfactory/articles/566414/
        let intersection = a.intersection(b).count
        let union = a.union(b).count
        return union > 0 ? Double(intersection) / Double(union) : 0
    }
}

extension PDGSubgraph {
    private func normalizedNodeSignature(_ node: PDGNode) -> String {
        switch node.astNode.type {
        case .variable:
            return "VAR[\(node.astNode.variableType ?? "?")]"
        case .functionCall:
            return "CALL[\(node.astNode.value)]"
        case .function:
            return "FUNC[params:\(node.astNode.children.filter { $0.type == .variable }.count)]"
        default:
            return node.astNode.type.rawValue
        }
    }
    
    private func normalizedEdgeSignature(_ edge: (from: PDGNode, to: PDGNode, type: PDGEdgeType)) -> String {
        return "\(normalizedNodeSignature(edge.from))-\(edge.type)->\(normalizedNodeSignature(edge.to))"
    }
}

extension PDGSubgraph {
    func semanticSimilarity(to other: PDGSubgraph) -> Double {
        // 1. Фильтруем только узлы функций
        let selfFuncNodes = self.nodes.filter { $0.astNode.type == .function }
        let otherFuncNodes = other.nodes.filter { $0.astNode.type == .function }
        
        guard !selfFuncNodes.isEmpty && !otherFuncNodes.isEmpty else {
            return 0.0
        }
        
        // 2. Сравниваем только внутреннюю структуру функций
        let selfStructure = self.normalizedStructureSignature()
        let otherStructure = other.normalizedStructureSignature()
        let structureScore = jaccardSimilarity(selfStructure, otherStructure)
        
        // 3. Сравниваем операции внутри функций
        let selfOps = self.normalizedOperations()
        let otherOps = other.normalizedOperations()
        let opsScore = jaccardSimilarity(selfOps, otherOps) // ИСПРАВИТь
        
        // 4. Комбинируем оценки с приоритетом операций
        return (opsScore * 0.5 + structureScore * 0.5)
    }
    
    func normalizedStructureSignature() -> Set<String> {
        var signatures = Set<String>()
        
        // Анализируем только узлы внутри функции (игнорируем внешние)
        let internalNodes = nodes.filter { node in
            guard let parent = node.astNode.parent else { return false }
            return parent.type == .function
        }
        
        for node in internalNodes {
            signatures.insert("NODE:\(node.astNode.type)-\(node.astNode.variableType ?? "")")
        }
        
        for edge in edges {
            // Учитываем только ребра между внутренними узлами
            if internalNodes.contains(edge.from) && internalNodes.contains(edge.to) {
                signatures.insert("EDGE:\(edge.from.astNode.type)-\(edge.type)-\(edge.to.astNode.type)")
            }
        }
        
        return signatures
    }
}

extension PDGSubgraph {
    func isSemanticClone(of other: PDGSubgraph) -> Bool {
        // 1. Нормализация операций
        let selfOps = self.normalizedOperations()
        let otherOps = other.normalizedOperations()
        
        // 2. Сравнение структуры вызовов
        let selfCalls = self.functionCallsPattern()
        let otherCalls = other.functionCallsPattern()
        
        // 3. Сравнение структуры переменных
        let selfVars = self.variablesPattern()
        let otherVars = other.variablesPattern()

        return selfOps == otherOps &&
               selfCalls == otherCalls &&
               selfVars == otherVars
    }
    
    func normalizedOperations() -> Set<String> {
        let array = nodes
            .filter { $0.astNode.type != .variable && $0.astNode.type != .functionCall }
            .map {
                $0.astNode.sourceCode ?? ""
                    .replacingOccurrences(of: "\\b[a-zA-Z_]\\w*\\b", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\d+", with: "0")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        return Set(array)
    }
    
    private func functionCallsPattern() -> [String] {
        return nodes
            .filter { $0.astNode.type == .functionCall }
            .map { _ in "CALL" } // Нормализуем все вызовы
    }
    
    private func variablesPattern() -> [String] {
        return nodes
            .filter { $0.astNode.type == .variable }
            .map { $0.astNode.variableType ?? "VAR" }
    }
}
