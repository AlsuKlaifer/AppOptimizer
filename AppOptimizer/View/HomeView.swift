//
//  HomeView.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 10.12.2024.
//

import SwiftUI

struct HomeView: View {
    @State private var appPath: String = ""
    @State private var outputFile: String = ""

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Welcome to app optimizer! You can scan app for searching unused code and duplicates")
                .padding()
            VStack {
                HStack {
                    Text("Enter the project path")
                    TextField("Path", text: $appPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 400)
                        .padding([.top, .bottom])
                }
            }
            HStack {
                Button("Search unused code") {
                    runDeadCodeAnalysis()
                }
                .padding()
                Button("Search duplicates") {
                    
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
        guard !appPath.isEmpty else {
            outputFile = "Error: Project path cannot be empty."
            return
        }

        guard let scriptPath = Bundle.main.path(forResource: "analyze_dead_code", ofType: "rb") else {
            outputFile = "Error: Script path not found."
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ruby")
        process.arguments = [scriptPath, appPath]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: outputData, encoding: .utf8) {
                outputFile = output
            } else {
                outputFile = "Error: Unable to read script output."
            }
        } catch {
            outputFile = "Error: \(error.localizedDescription)"
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
