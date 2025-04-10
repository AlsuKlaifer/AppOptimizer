//
//  HomeView.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 10.12.2024.
//

import SwiftUI
import SwiftParser
import AppKit

struct HomeView: View {
    @State private var appPath: String = ""
    @State private var outputFile: String = ""

    // тоглы для поиска неиспользуемого кода
    @State private var retainPublic: Bool = false // все публичные и открытые объявления помечаем используемыми
    @State private var includeAssets: Bool = false // добавить анализ неиспользуемых ассетов
    @State private var includeLibraries: Bool = false // добавить анализ неиспользуемых библиотек

    // тоглы для поиска дубликатов
    @State private var onlySwift: Bool = false // сканировать только файлы с расширением swift
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Welcome to app optimizer! You can scan app for searching unused code and duplicates")
                .padding()
            VStack {
                HStack {
                    Text("Project path:")
                    TextField("Path", text: $appPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 400)
                        .padding([.top, .bottom])
                    Button("Choose...") {
                        selectProjectPath()
                    }
                }
            }
            HStack {
                VStack {
                    Toggle("Retain Public API", isOn: $retainPublic)
                    Toggle("Include Assets", isOn: $includeAssets)
                    Toggle("Include Libs", isOn: $includeLibraries)
                    Button("Search unused code") {
                        runDeadCodeAnalysis()
                    }
                    .padding()
                }
                .padding()
                VStack {
                    Button("Search duplicates") {
                        runDuplicateCodeAnalysis1()
                    }
                    .padding()
                }
            }
            if !outputFile.isEmpty {
                Text("Script Output:")
                    .font(.headline)
                ScrollView {
                    Text(outputFile)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 400)
                .border(Color.gray, width: 1)
                .padding()
            }
        }
        .padding()
    }

    private func runDeadCodeAnalysis() {
        let deadCodeManager = DeadCodeManager(
            appPath: appPath,
            retainPublic: retainPublic,
            includeAssets: includeAssets,
            includeLibraries: includeLibraries
        )

        deadCodeManager.analyzeDeadCode(outputFile: &outputFile)
    }
    
    /// Открывает NSOpenPanel для выбора пути к проекту
    func selectProjectPath() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Project Directory"
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK {
            if let selectedPath = openPanel.url?.path {
                appPath = selectedPath
            }
        }
    }

    /// Рекурсивный поиск всех .swift файлов в директории проекта
    func collectSwiftFiles(at path: String) -> [String] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: path) else { return [] }
        var swiftFiles: [String] = []

        for case let file as String in enumerator {
            if file.hasSuffix(".swift") {
                swiftFiles.append("\(path)/\(file)")
            }
        }

        return swiftFiles
    }

    /// Поиск дубликатов с использованием PDG
    func runDuplicateCodeAnalysis1() {
        let source = """
        class FirstViewController: UIViewController {

            let round = UIView()
            let square = UIView()

            override func viewDidLoad() {
                super.viewDidLoad()

                view.backgroundColor = .white

                setupSquare()
            }

            private func setupSquare() {
                square.backgroundColor = .blue
                square.translatesAutoresizingMaskIntoConstraints = false

                view.addSubview(square)
                NSLayoutConstraint.activate([
                    square.widthAnchor.constraint(equalToConstant: 200),
                    square.heightAnchor.constraint(equalToConstant: 200),
                    square.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    square.centerYAnchor.constraint(equalTo: view.centerYAnchor)
                ])
            }
        }
        class SecondViewController: UIViewController {

            let round = UIView()
            let square = UIView()

            override func viewDidLoad() {
                super.viewDidLoad()

                view.backgroundColor = .blue

                setupSquare()
                setupRound()
            }

            private func setupSquare() {
                square.backgroundColor = .white
                square.translatesAutoresizingMaskIntoConstraints = false

                view.addSubview(square)
                NSLayoutConstraint.activate([
                    square.widthAnchor.constraint(equalToConstant: 200),
                    square.heightAnchor.constraint(equalToConstant: 200),
                    square.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    square.centerYAnchor.constraint(equalTo: view.centerYAnchor)
                ])
            }

            private func setupRound() {
                round.backgroundColor = .red
                round.layer.cornerRadius = 100
                round.translatesAutoresizingMaskIntoConstraints = false

                view.addSubview(round)
                NSLayoutConstraint.activate([
                    round.widthAnchor.constraint(equalToConstant: 300),
                    round.heightAnchor.constraint(equalToConstant: 300),
                    round.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    round.centerYAnchor.constraint(equalTo: view.centerYAnchor)
                ])
            }
        }
        """
//        let source = """
//        class Test {
//            // Вариант 1
//            func add1(a: Int, b: Int) -> Int { return a + b }
//            
//            // Вариант 2 (клон с другими именами)
//            func add2(x: Int, y: Int) -> Int { return x + y }
//            
//            // Вариант 3 (почти клон с дополнительной переменной)
//            func sum(a: Int, b: Int) -> Int {
//                let res = a + b
//                return res
//            }
//            
//            // Вариант 4 (другая логика)
//            func mult(a: Int, b: Int) -> Int { return a * b }
//        }
//        """

        let visitor = ASTVisitor(viewMode: .sourceAccurate)
        visitor.visit(source: source)

        let builder = PDGBuilder(ast: visitor.ast)
        builder.build()

        let subgraphs = builder.extractNormalizedSubgraphs()

        print("\n=== Similarity Matrix ===")
        for i in 0..<subgraphs.count {
            let nameI = subgraphs[i].nodes.first { $0.astNode.type == .function }?.astNode.value ?? "?"
            for j in (i+1)..<subgraphs.count {
                let nameJ = subgraphs[j].nodes.first { $0.astNode.type == .function }?.astNode.value ?? "?"
                let sim = subgraphs[i].similarity(to: subgraphs[j])
                print("\(nameI) vs \(nameJ): \(String(format: "%.2f", sim))")
            }
        }

        let clones = findClones(subgraphs: subgraphs, threshold: 0.7)
        print("\n=== Detected Clones (threshold: 0.7) ===")
        for (g1, g2, sim) in clones {
            let name1 = g1.nodes.first { $0.astNode.type == .function }?.astNode.value ?? "?"
            let name2 = g2.nodes.first { $0.astNode.type == .function }?.astNode.value ?? "?"
            print("\(name1) ~ \(name2): \(String(format: "%.2f", sim)) similarity")
        }

        func findClones(subgraphs: [PDGSubgraph], threshold: Double = 0.85) -> [(PDGSubgraph, PDGSubgraph, Double)] {
            var results = [(PDGSubgraph, PDGSubgraph, Double)]()
            var processed = Set<Int>()
            
            for i in 0..<subgraphs.count {
                guard !processed.contains(i) else { continue }
                var currentGroup = [subgraphs[i]]
                
                for j in (i+1)..<subgraphs.count {
                    let similarity = subgraphs[i].similarity(to: subgraphs[j])
                    if similarity >= threshold {
                        results.append((subgraphs[i], subgraphs[j], similarity))
                        processed.insert(j)
                    }
                }
            }
            
            return results.sorted { $0.2 > $1.2 }
        }
//        let duplicateManager = PDGDuplicateCodeManager(appPath: appPath)
//        duplicateManager.analyzeDuplicates(outputFile: &outputFile)
    }

    /// Поиск дубликатов с использованием jscpd
    func runDuplicateCodeAnalysis() {
        guard !appPath.isEmpty else {
            outputFile = "Error: Project path is empty. Please select a valid directory."
            return
        }

        // Сбор всех .swift файлов
        let swiftFiles = collectSwiftFiles(at: appPath)
        guard !swiftFiles.isEmpty else {
            outputFile = "Error: No .swift files found in the project."
            return
        }

        let jscpdPath = "/opt/homebrew/bin/jscpd"
        guard FileManager.default.isExecutableFile(atPath: jscpdPath) else {
            outputFile = "Error: jscpd not found or is not executable at \(jscpdPath). Please ensure it is installed globally or specify the correct path."
            return
        }

        let tempDir = "\(appPath)/jscpd_temp"
        do {
            try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        } catch {
            outputFile = "Error: Unable to create temporary directory: \(error.localizedDescription)"
            return
        }

        // Нормализация кода и копирование в временную директорию
        for file in swiftFiles {
            do {
                let code = try String(contentsOfFile: file)
                let normalizedCode = normalizeCode(code)
                let normalizedFilePath = "\(tempDir)/\(URL(fileURLWithPath: file).lastPathComponent)"
                try normalizedCode.write(toFile: normalizedFilePath, atomically: true, encoding: .utf8)
            } catch {
                outputFile = "Error: Unable to normalize file \(file): \(error.localizedDescription)"
                return
            }
        }
        
        let process = Process()
        let pipe = Pipe()

        let arguments = [
            "--reporters", "json",                 // Формат отчета JSON
            "--output", "\(appPath)/jscpd-report", // Путь для сохранения отчета
            "--noSymlinks",                        // Исключить символические ссылки при анализе файлов
            "--ignoreCase",                        // Игнорировать регистр символов в коде
            "--min-tokens", "8",
            "--min-lines", "5",
            tempDir                                // Сканируем временную директорию с нормализованным кодом
        ]

        process.executableURL = URL(fileURLWithPath: jscpdPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                outputFile = output
            } else {
                outputFile = "Error: Unable to read output from jscpd."
            }
        } catch {
            outputFile = "Error running jscpd: \(error.localizedDescription)"
        }

        // Удаление временной директории
        do {
            try FileManager.default.removeItem(atPath: tempDir)
        } catch {
            print("Warning: Failed to delete temporary directory: \(error.localizedDescription)")
        }
    }

    /// Функция нормализации кода
    func normalizeCode(_ code: String) -> String {
        var normalized = code

        // Удаление комментариев
        normalized = normalized.replacingOccurrences(of: "//.*", with: "", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "/\\*.*?\\*/", with: "", options: .regularExpression)

        // Замена имён функций на func_
        normalized = normalized.replacingOccurrences(of: "\\bfunc\\s+[a-zA-Z_][a-zA-Z0-9_]*", with: "func func_", options: .regularExpression)

        // Замена имён переменных на var_
        normalized = normalized.replacingOccurrences(of: "\\blet\\s+[a-zA-Z_][a-zA-Z0-9_]*", with: "let var_", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "\\bvar\\s+[a-zA-Z_][a-zA-Z0-9_]*", with: "var var_", options: .regularExpression)

        return normalized
    }
}

#Preview {
    PreviewContainer()
}

private struct PreviewContainer: View {
    var body: some View {
        HomeView()
    }
}
