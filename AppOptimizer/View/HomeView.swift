//
//  HomeView.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 10.12.2024.
//

import SwiftUI
import AppKit

struct HomeView: View {
    @State private var appPath: String = ""
    @State private var outputFile: String = ""
    @State private var retainPublic: Bool = false // все публичные и открытые объявления помечаем используемыми
    @State private var includeAssets: Bool = false // добавить анализ неиспользуемых ассетов
    @State private var includeLibraries: Bool = false // добавить анализ неиспользуемых библиотек
    
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
            VStack {
                Toggle("Retain Public API", isOn: $retainPublic)
                Toggle("Include Assets", isOn: $includeAssets)
                Toggle("Include Libs", isOn: $includeLibraries)
            }
            HStack {
                Button("Search unused code") {
                    runDeadCodeAnalysis()
                }
                .padding()
                Button("Search duplicates") {
                    runDuplicateCodeAnalysis()
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
                .frame(height: 200)
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
    
    /// Поиск дубликатов с использованием jscpd
    func runDuplicateCodeAnalysis() {
        guard !appPath.isEmpty else {
            outputFile = "Error: Project path is empty. Please select a valid directory."
            return
        }
        
        guard let jscpdPath = URL(string: "/Users/a.i.faizova/Developer/AppOptimizer/jscpd/bin/")?.path(),
              FileManager.default.fileExists(atPath: jscpdPath) else {
            outputFile = "Error: jscpd not found in the current directory. Ensure it is present and executable."
            return
        }
        
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: jscpdPath)
        process.arguments = [
            "--reporters", "json",               // Формат отчета JSON
            "--output", "\(appPath)/jscpd-report", // Путь для сохранения отчета
            "--blame",                           // Получить информацию о авторах дублирования
            "--noSymlinks",                      // Исключить символические ссылки при анализе файлов
            "--ignoreCase"                       // Игнорировать регистр символов в коде
        ]
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
