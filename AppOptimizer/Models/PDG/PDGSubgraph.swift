//
//  PDGSubgraph.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 07.04.2025.
//

import Foundation

struct PDGEdgeCodable: Codable {
    let from: PDGNode
    let to: PDGNode
    let type: PDGEdgeType
}

struct PDGSubgraph: Codable {
    let nodes: [PDGNode]
    let edges: [PDGEdgeCodable]

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
        guard nodes.count == other.nodes.count,
              edges.count == other.edges.count else {
            return false
        }

        let ourNodes = nodes.sorted { $0.semanticSignature() < $1.semanticSignature() }
        let theirNodes = other.nodes.sorted { $0.semanticSignature() < $1.semanticSignature() }

        for (ourNode, theirNode) in zip(ourNodes, theirNodes) {
            guard ourNode.semanticSignature() == theirNode.semanticSignature() else {
                return false
            }
        }

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
}

extension PDGSubgraph {
    func similarity(to other: PDGSubgraph) -> Double {
        let selfNodes = self.normalizedNodes()
        let otherNodes = other.normalizedNodes()

        let selfEdges = self.normalizedEdges()
        let otherEdges = other.normalizedEdges()

        let nodeSimilarity = jaccardSimilarity(selfNodes, otherNodes)
        let edgeSimilarity = jaccardSimilarity(selfEdges, otherEdges)

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
        let intersection = a.intersection(b).count
        let union = a.union(b).count
        return union > 0 ? Double(intersection) / Double(union) : 0
    }
}

extension PDGSubgraph {
    func semanticSimilarity(to other: PDGSubgraph) -> Double {
        let opsA = Set(self.normalizedOperations())
        let opsB = Set(other.normalizedOperations())
        let opSim = jaccardSimilarity(opsA, opsB)

        let structSetA = self.normalizedStructureSignature()
        let structSetB = other.normalizedStructureSignature()
        let structStrA = structSetA.sorted().joined(separator: "\n")
        let structStrB = structSetB.sorted().joined(separator: "\n")
        let structSim = normalizedLevenshteinSimilarity(structStrA, structStrB)

        return 0.4 * opSim + 0.6 * structSim
    }

    private func levenshteinDistance(_ s: String, _ t: String) -> Int {
        let a = Array(s), b = Array(t)
        let n = a.count, m = b.count
        if n == 0 { return m }; if m == 0 { return n }
        var prev = [Int](0...m), curr = [Int](repeating: 0, count: m+1)
        for i in 1...n {
            curr[0] = i
            for j in 1...m {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                curr[j] = min(prev[j] + 1, curr[j-1] + 1, prev[j-1] + cost)
            }
            swap(&prev, &curr)
        }
        return prev[m]
    }

    private func normalizedLevenshteinSimilarity(_ a: String, _ b: String) -> Double {
        let dist = levenshteinDistance(a, b)
        let maxLen = max(a.count, b.count)
        return maxLen > 0 ? (1.0 - Double(dist) / Double(maxLen)) : 1.0
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

    func normalizedStructureSignature() -> Set<String> {
        var signatures = Set<String>()

        let internalNodes = nodes.filter { node in
            guard let parent = node.astNode.parent else { return false }
            return parent.type == .function
        }
        
        for node in internalNodes {
            signatures.insert("NODE:\(node.astNode.type)-\(node.astNode.variableType ?? "")")
        }
        
        for edge in edges {
            // учитываем только ребра между внутренними узлами
            if internalNodes.contains(edge.from) && internalNodes.contains(edge.to) {
                signatures.insert("EDGE:\(edge.from.astNode.type)-\(edge.type)-\(edge.to.astNode.type)")
            }
        }
        
        return signatures
    }
}

extension PDGSubgraph {
    func isSemanticClone(of other: PDGSubgraph) -> Bool {
        let selfOps = self.normalizedOperations()
        let otherOps = other.normalizedOperations()

        let selfCalls = self.functionCallsPattern()
        let otherCalls = other.functionCallsPattern()

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
            .map { _ in "CALL" }
    }
    
    private func variablesPattern() -> [String] {
        return nodes
            .filter { $0.astNode.type == .variable }
            .map { $0.astNode.variableType ?? "VAR" }
    }
}

extension PDGSubgraph: VF2Graph {
    var vertices: [UUID] {
        nodes.map { $0.astNode.id }
    }

    var vertexLabel: [UUID: String] {
        Dictionary(uniqueKeysWithValues:
            nodes.map { ($0.astNode.id, $0.astNode.type.rawValue) }
        )
    }

    var edgesOut: [UUID: [(to: UUID, label: String)]] {
        var dict = [UUID: [(to: UUID, label: String)]]()
        for edge in edges {
            let from = edge.from.astNode.id
            let to   = edge.to.astNode.id
            dict[from, default: []].append((to: to, label: edge.type.rawValue))
        }
        return dict
    }

    var edgesIn: [UUID: [(from: UUID, label: String)]] {
        var dict = [UUID: [(from: UUID, label: String)]]()
        for edge in edges {
            let from = edge.from.astNode.id
            let to   = edge.to.astNode.id
            dict[to, default: []].append((from: from, label: edge.type.rawValue))
        }
        return dict
    }
}
