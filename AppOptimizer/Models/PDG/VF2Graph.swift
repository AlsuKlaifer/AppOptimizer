//
//  VF2Graph.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 09.06.2025.
//

import Foundation

protocol VF2Graph {
    /// Множество всех вершин: Int идентификатор
    var vertices: [UUID] { get }
    /// Маппинг: vertex -> label (для сравнения типов узлов)
    var vertexLabel: [UUID: String] { get }
    /// Список рёбер: from -> [(to, label)]
    var edgesOut: [UUID: [(to: UUID, label: String)]] { get }
    /// Список входящих рёбер: to -> [(from, label)]
    var edgesIn: [UUID: [(from: UUID, label: String)]] { get }
}

class VF2SimilarityMatcher {
    private let g1: VF2Graph
    private let g2: VF2Graph
    private var core1: [UUID:UUID] = [:]
    private var core2: [UUID:UUID] = [:]
    private var bestMappingSize = 0

    init(_ g1: VF2Graph, _ g2: VF2Graph) {
        self.g1 = g1
        self.g2 = g2
    }

    /// Запускает поиск и возвращает меру сходства:
    /// matched / (|g1| + |g2| − matched)
    func similarity() -> Double {
        bestMappingSize = 0
        core1.removeAll(); core2.removeAll()
        search()
        let n1 = g1.vertices.count
        let n2 = g2.vertices.count
        let m  = bestMappingSize
        let union = n1 + n2 - m
        guard union > 0 else { return n1 == 0 && n2 == 0 ? 1.0 : 0.0 }
        return Double(m) / Double(union)
    }

    private func search() {
        bestMappingSize = max(bestMappingSize, core1.count)

        guard core1.count < g1.vertices.count else { return }

        guard let v1 = g1.vertices.first(where: { core1[$0] == nil }) else { return }
        let label1 = g1.vertexLabel[v1]!

        let candidates = g2.vertices.filter {
            core2[$0] == nil && g2.vertexLabel[$0] == label1
        }

        for v2 in candidates {
            if feasible(v1: v1, v2: v2) {
                core1[v1] = v2
                core2[v2] = v1
                search()
                core1.removeValue(forKey: v1)
                core2.removeValue(forKey: v2)
            }
        }
    }

    private func feasible(v1: UUID, v2: UUID) -> Bool {
        for (u1, u2) in core1 {
            if let out1 = g1.edgesOut[u1]?.first(where: { $0.to == v1 }) {
                guard g2.edgesOut[u2]?.contains(where: { $0.to == v2 && $0.label == out1.label }) == true else {
                    return false
                }
            }
            if let in1 = g1.edgesIn[u1]?.first(where: { $0.from == v1 }) {
                guard g2.edgesIn[u2]?.contains(where: { $0.from == v2 && $0.label == in1.label }) == true else {
                    return false
                }
            }
        }
        return true
    }
}
