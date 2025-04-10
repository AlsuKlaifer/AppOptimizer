////
////  PDGDuplicateCodeManager.swift
////  AppOptimizer
////
////  Created by Alsu Faizova on 21.03.2025.
////
//
//import Foundation
//import SwiftParser
//import SwiftSyntax
//import SwiftGraph
//
//// Типы зависимостей для PDG
//enum PDGDependency {
//    case controlDependency(node: String)
//    case dataDependency(node: String)
//}
//
//// PDG (Program Dependence Graph)
//class PDG: Hashable {
//    var graph: UnweightedGraph<String> = UnweightedGraph<String>()
//    var id: String // Уникальный идентификатор для каждой части кода (например, имя функции или блока)
//
//    init(id: String) {
//        self.id = id
//    }
//
//    // Добавить зависимость
//    func addDependency(from: String, to: String, dependencyType: PDGDependency) {
//        switch dependencyType {
//        case .controlDependency:
//            graph.addEdge(from: from, to: to)
//        case .dataDependency:
//            graph.addEdge(from: from, to: to)
//        }
//    }
//
//    // Метод для вычисления сходства между двумя графами PDG
//    func similarity(to other: PDG) -> Double {
//        // Сначала проверяем, сколько рёбер общих между графами, игнорируя порядок узлов
//        let commonEdges = self.graph.edges.filter { edge in
//            other.graph.edges.contains { (e1, e2) in
//                // Сравниваем рёбра без учёта порядка узлов
//                return (edge.0 == e1 && edge.1 == e2) || (edge.0 == e2 && edge.1 == e1)
//            }
//        }.count
//
//        print("Common edges: \(commonEdges)")
//        print("Total edges in both graphs: \(self.graph.edges.count + other.graph.edges.count)")
//
//        // Если в графах нет рёбер, возвращаем схожесть как 0
//        guard self.graph.edges.count + other.graph.edges.count > 0 else {
//            return 0
//        }
//
//        // Расчёт схожести как отношение числа общих рёбер к общему числу рёбер
//        return Double(commonEdges) / Double(self.graph.edges.count + other.graph.edges.count)
//    }
//
//
//    // Конформность протоколу Hashable
//    static func ==(lhs: PDG, rhs: PDG) -> Bool {
//        return lhs.id == rhs.id
//    }
//
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(id)
//    }
//
//    // Получить исходный код (например, для форматирования дубликатов)
//    func getSourceCode() -> String {
//        return "PDG Representation for \(id)"
//    }
//}
//
//class PDGParser {
//    private var pdg: PDG
//
//    init(pdgId: String) {
//        self.pdg = PDG(id: pdgId)
//    }
//
//    // Метод для извлечения данных и зависимостей из исходного кода
//    func parse(sourceCode: String) -> PDG {
//        let lines = sourceCode.split(separator: "\n")
//        var currentNode: String = ""
//        
//        for line in lines {
//            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
//
//            // Простейшие проверки для условных операторов (if), присваиваний и вызовов функций
//            if trimmedLine.hasPrefix("if") {
//                let conditionNode = "ifCondition_\(currentNode)"
//                let bodyNode = "ifBody_\(currentNode)"
//                pdg.addDependency(from: conditionNode, to: bodyNode, dependencyType: .controlDependency(node: "control"))
//                currentNode = conditionNode
//            } else if trimmedLine.contains("=") {
//                // Простейшая проверка для присваиваний
//                let variableNode = "variableAssignment_\(currentNode)"
//                pdg.addDependency(from: currentNode, to: variableNode, dependencyType: .dataDependency(node: "data"))
//                currentNode = variableNode
//            } else if trimmedLine.contains("(") && trimmedLine.contains(")") {
//                // Простейшая проверка для вызовов функций
//                let functionCallNode = "functionCall_\(currentNode)"
//                pdg.addDependency(from: currentNode, to: functionCallNode, dependencyType: .dataDependency(node: "data"))
//                currentNode = functionCallNode
//            }
//        }
//        
//        return pdg
//    }
//}
//
//class PDGDuplicateCodeManager {
//    let appPath: String
//
//    init(appPath: String) {
//        self.appPath = appPath
//    }
//
//    func analyzeDuplicates(outputFile: inout String) {
//        let fileURLs = getSwiftFileURLs(in: appPath)
//        var pdgs: [PDG] = []
//
//        for fileURL in fileURLs {
//            do {
//                let sourceFile = try String(contentsOf: fileURL)
//                let pdgParser = PDGParser(pdgId: fileURL.lastPathComponent)
//                let pdg = pdgParser.parse(sourceCode: sourceFile)
//                pdgs.append(pdg)
//            } catch {
//                print("Error parsing file: \(fileURL.path), error: \(error)")
//            }
//        }
//
//        let duplicates = findDuplicates(in: pdgs)
//        outputFile = formatDuplicates(duplicates)
//        print("outputFile:\n", outputFile)
//    }
//
//    private func findDuplicates(in pdgs: [PDG]) -> [PDG: [PDG]] {
//        var duplicates: [PDG: [PDG]] = [:]
//        for i in 0..<pdgs.count {
//            for j in i+1..<pdgs.count {
//                let similarity = pdgs[i].similarity(to: pdgs[j])
//                if similarity >= 0.5 {
//                    duplicates[pdgs[i], default: []].append(pdgs[j])
//                }
//            }
//        }
//        return duplicates
//    }
//
//    private func formatDuplicates(_ duplicates: [PDG: [PDG]]) -> String {
//        var output = ""
//        for (original, copies) in duplicates {
//            output += "Original:\n\(original.getSourceCode())\n\nDuplicates:\n"
//            for copy in copies {
//                output += copy.getSourceCode() + "\n"
//            }
//            output += "\n"
//        }
//        return output
//    }
//
//    // Получение списка файлов .swift в указанной директории
//    private func getSwiftFileURLs(in directory: String) -> [URL] {
//        let fileManager = FileManager.default
//        let directoryURL = URL(fileURLWithPath: directory)
//
//        guard let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
//            return []
//        }
//
//        var swiftFileURLs: [URL] = []
//
//        for case let fileURL as URL in enumerator {
//            if fileURL.pathExtension == "swift" {
//                swiftFileURLs.append(fileURL)
//            }
//        }
//
//        return swiftFileURLs
//    }
//}
//
//
//
//
//
//// MARK: Unused
//
//
//class PDGDuplicateCodeManager2 {
//
//    // MARK: Properties
//
//    let appPath: String
//
//    // MARK: Lifecycle
//
//    init(appPath: String) {
//        self.appPath = appPath
//    }
//
//    // MARK: Internal methods
//
//    func analyzeDuplicates(outputFile: inout String) {
//        // Получаем список файлов Swift из директории
//        let fileURLs = getSwiftFileURLs(in: appPath)
//        var pdgGraphs: [PDG2] = []
//        
//        // Проходим по каждому файлу и строим PDG-граф
//        for fileURL in fileURLs {
//            do {
//                let sourceFile = try Parser.parse(source: String(contentsOf: fileURL))
//                let visitor = ASTVisitor(viewMode: .sourceAccurate) // Используем ASTVisitor для построения AST
//                visitor.walk(sourceFile)
//                
//                let pdgGraph = visitor.pdgGraph // Граф зависимостей из ASTVisitor
//                pdgGraphs.append(pdgGraph)
//            } catch {
//                print("Ошибка парсинга файла: \(fileURL.path), ошибка: \(error)")
//            }
//        }
//
//        let duplicates = findDuplicates(in: pdgGraphs)
//
//        outputFile = formatDuplicates(duplicates)
//        print("Результат анализа дубликатов:\n", outputFile)
//    }
//
//    // MARK: Private methods
//
//    private func getSwiftFileURLs(in directory: String) -> [URL] {
//        let fileManager = FileManager.default
//        let directoryURL = URL(fileURLWithPath: directory)
//        
//        guard let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
//            return []
//        }
//        
//        var swiftFileURLs: [URL] = []
//
//        for case let fileURL as URL in enumerator {
//            if fileURL.pathExtension == "swift" {
//                swiftFileURLs.append(fileURL)
//            }
//        }
//        
//        return swiftFileURLs
//    }
//    
//    private func findDuplicates(in pdgGraphs: [PDG2]) -> [(ASTNode, ASTNode)] {
//        var duplicates: [(ASTNode, ASTNode)] = []
//
//        // Ищем похожие функции в каждом графе
//        for graph in pdgGraphs {
//            let similarFunctions = graph.findSimilarFunctions()
//            duplicates.append(contentsOf: similarFunctions)
//        }
//        
//        return duplicates
//    }
//    
//    private func formatDuplicates(_ duplicates: [(ASTNode, ASTNode)]) -> String {
//        var output = ""
//        for (original, copy) in duplicates {
//            output += "Оригинал:\n\(original.getSourceCode())\n\nДубликат:\n\(copy.getSourceCode())\n\n"
//        }
//        return output
//    }
//}
