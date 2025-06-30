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
    @Binding var appPath: String
    @ObservedObject var settings: SettingsModel
    @State private var outputFile: String = ""
    @State private var results: String = ""

    @State private var showClearBanner: Bool = false
    @State private var showDeleteConfirmation = false
    @State private var showDeleteResultsSheet = false

    @State private var isAnalyzingDeadCode = false
    @State private var isAnalyzingDuplicates = false

    // все публичные и открытые объявления помечаем используемыми
    @State private var retainPublic: Bool = false
    @State private var includeAssets: Bool = false

    private let thresholdFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimum = 0
        formatter.maximum = 1
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        formatter.decimalSeparator = "."
        return formatter
    }()

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("App Optimizer")
                        .font(.largeTitle.bold())
                        .padding(.top, 5)
                }
                
                HStack {
                    Text("Оптимизируйте ваш iOS-проект: найдите неиспользуемый код, медиаресурсы и дублирования.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: clearCache) {
                        Label("Очистить кэш", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                GroupBox(label: Label("Путь к проекту", systemImage: "folder")) {
                    HStack(spacing: 12) {
                        TextField("Укажите путь к папке с проектом", text: $appPath)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Выбрать...") {
                            selectProjectPath()
                        }
                    }
                    .padding(.top, 5)
                }
                
                HStack(alignment: .top, spacing: 40) {
                    GroupBox(
                        label: Label("Настройки анализа кода", systemImage: "trash")
                            .padding(5)
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Публичные API пометить используемыми", isOn: $retainPublic)
                            Toggle("Анализировать медиаресурсы", isOn: $includeAssets)
                        }
                        .padding(5)
                    }
                    
                    GroupBox(
                        label: Label("Настройки поиска дубликатов", systemImage: "doc.on.doc")
                            .padding(5)
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
//                            Toggle("Анализировать только Swift-файлы", isOn: $onlySwift)
                            HStack(spacing: 10) {
                                Text("Минимальный порог сходства:")
                                TextField("0.8", value: $settings.minSimilarityThreshold, formatter: thresholdFormatter)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 50)
                            }
                        }
                        .padding(5)
                    }
                }
                
                HStack(spacing: 40) {
                    Button(action: {
                        isAnalyzingDeadCode = true
                        runDeadCodeAnalysis()
                    }) {
                        Label("Поиск неиспользуемого кода", systemImage: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .opacity(isAnalyzingDeadCode ? 0 : 1)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .opacity(isAnalyzingDeadCode ? 1 : 0)
                            )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAnalyzingDeadCode)
                    
                    Button(action: {
                        isAnalyzingDuplicates = true
                        runDuplicateCodeAnalysis()
                    }) {
                        Label("Поиск дубликатов", systemImage: "doc.on.doc")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .opacity(isAnalyzingDuplicates ? 0 : 1)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .opacity(isAnalyzingDuplicates ? 1 : 0)
                            )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAnalyzingDuplicates)
                }
                .padding(.top, 8)
                
                Divider()
                Text("Результаты анализа")
                    .font(.headline)
                
                ScrollView {
                    TextEditor(text: $outputFile)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(minHeight: 300)
                        .background(Color(.systemGray))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                }
                .frame(minHeight: 320)
                
                HStack {
                    Spacer()
                    Button(action: { showDeleteConfirmation = true }) {
                        Label("Удалить неиспользуемое", systemImage: "trash")
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .alert("Удалить все неиспользуемые элементы?", isPresented: $showDeleteConfirmation) {
                        Button("Удалить", role: .destructive) {
                            deleteUnused()
                        }
                        Button("Отмена", role: .cancel) { }
                    } message: {
                        Text("Это действие нельзя будет отменить")
                    }
                }
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 820, minHeight: 640)
            
            if showClearBanner {
                Text("Кэш успешно очищен")
                    .padding()
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 10)
            }
        }
        .padding()
        .frame(minWidth: 820, minHeight: 640)
        // модальный скрин с результатами
        .sheet(isPresented: $showDeleteResultsSheet) {
            DeleteResultsSheet(output: results) {
                showDeleteResultsSheet = false
            }
        }
    }

    private func clearCache() {
        guard !appPath.isEmpty else {
            outputFile = "Укажите путь к проекту"
            return
        }
        let projectURL = URL(fileURLWithPath: appPath)
        let cacheURL = projectURL.appendingPathComponent(".file_hashes_cache")
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            try? FileManager.default.removeItem(at: cacheURL)
        }

        withAnimation { showClearBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
                showClearBanner = false
            }
        }
    }

    private func deleteUnused() {
        let removeManager = RemoveManager(appPath: appPath)
        results = removeManager.removeUnused(outputFile: outputFile)
        showDeleteResultsSheet = true
    }

    private func runDeadCodeAnalysis() {
        DispatchQueue.global(qos: .userInitiated).async {
            let deadCodeManager = DeadCodeManager(
                appPath: appPath,
                retainPublic: retainPublic,
                includeAssets: includeAssets
            )
            deadCodeManager.analyze(outputFile: &outputFile)

            DispatchQueue.main.async {
                isAnalyzingDeadCode = false
            }
        }
    }
    
    /// NSOpenPanel для выбора пути к проекту
    func selectProjectPath() {
        let openPanel = NSOpenPanel()
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
    func runDuplicateCodeAnalysis() {
        let duplicateManager = PDGDuplicateCodeManager(appPath: appPath, similarityThreshold: settings.minSimilarityThreshold)
        duplicateManager.analyzeDuplicates(output: &outputFile)

        DispatchQueue.main.async {
            isAnalyzingDuplicates = false
        }
    }

    /// с использованием jscpd
    func runDuplicateCodeAnalysisWithJscpd() {
        guard !appPath.isEmpty else {
            outputFile = "Укажите путь к проекту"
            return
        }

        let swiftFiles = collectSwiftFiles(at: appPath)
        guard !swiftFiles.isEmpty else { return }

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

        do {
            try FileManager.default.removeItem(atPath: tempDir)
        } catch {
            print("Warning: Failed to delete temporary directory: \(error.localizedDescription)")
        }
    }

    func normalizeCode(_ code: String) -> String {
        var normalized = code

        // Удаление комментариев
        normalized = normalized.replacingOccurrences(of: "//.*", with: "", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "/\\*.*?\\*/", with: "", options: .regularExpression)

        normalized = normalized.replacingOccurrences(of: "\\bfunc\\s+[a-zA-Z_][a-zA-Z0-9_]*", with: "func func_", options: .regularExpression)

        normalized = normalized.replacingOccurrences(of: "\\blet\\s+[a-zA-Z_][a-zA-Z0-9_]*", with: "let var_", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "\\bvar\\s+[a-zA-Z_][a-zA-Z0-9_]*", with: "var var_", options: .regularExpression)

        return normalized
    }
}
