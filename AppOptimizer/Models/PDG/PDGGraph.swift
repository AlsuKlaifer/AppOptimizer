//
//  PDGGraph.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 07.04.2025.
//

struct PDGGraph {
    static var shared = PDGGraph()
    var edges: [(from: PDGNode, to: PDGNode, type: PDGEdgeType)] = []
}
