//
//  SettingsView.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 09.06.2025.
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @Binding var projectRoot: String
    @ObservedObject var settings: SettingsModel
    
    @State private var showSaveBanner: Bool = false
    
    private var settingsFileURL: URL? {
        let pathURL = URL(fileURLWithPath: projectRoot)
        let dirURL: URL = (pathURL.pathExtension == "xcodeproj" || pathURL.pathExtension == "xcworkspace")
        ? pathURL.deletingLastPathComponent()
        : pathURL
        return dirURL.appendingPathComponent("settings.json")
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 20) {
                
                GroupBox(label: Label("Project Root", systemImage: "folder")) {
                    Text(projectRoot)
                        .foregroundColor(.secondary)
                        .padding(8)
                }
                
                GroupBox(label: Label("Exclude Paths", systemImage: "slash.circle")) {
                    VStack(spacing: 8) {
                        ForEach(Array(settings.excludePaths.enumerated()), id: \.offset) { idx, path in
                            HStack {
                                TextField("Path", text: Binding(
                                    get: { settings.excludePaths[idx] },
                                    set: { settings.excludePaths[idx] = $0 }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                Button(action: { settings.excludePaths.remove(at: idx) }) {
                                    Image(systemName: "minus.circle").foregroundColor(.red)
                                }
                            }
                        }
                        Button(action: { settings.excludePaths.append("") }) {
                            Label("Add Path", systemImage: "plus.circle")
                        }
                    }
                    .padding(5)
                }
                
                GroupBox(label: Label("Analyze Extensions", systemImage: "doc.text")) {
                    VStack(spacing: 8) {
                        ForEach(Array(settings.analyzeExtensions.enumerated()), id: \.offset) { idx, ext in
                            HStack {
                                TextField("Extension", text: Binding(
                                    get: { settings.analyzeExtensions[idx] },
                                    set: { settings.analyzeExtensions[idx] = $0 }
                                ))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                Button(action: { settings.analyzeExtensions.remove(at: idx) }) {
                                    Image(systemName: "minus.circle").foregroundColor(.red)
                                }
                            }
                        }
                        Button(action: { settings.analyzeExtensions.append("") }) {
                            Label("Add Extension", systemImage: "plus.circle")
                        }
                    }
                    .padding(5)
                }
                
                GroupBox(label: Label("Concurrency", systemImage: "cpu")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Use Multithreading", isOn: $settings.useMultithreading)
                        if settings.useMultithreading {
                            Stepper("Max Threads: \(settings.maxThreads)", value: $settings.maxThreads, in: 1...16)
                        }
                    }
                    .padding(5)
                }
                
                GroupBox(label: Label("Cache", systemImage: "folder.fill.badge.gear")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Enable Cache", isOn: $settings.enableCache)
                        if settings.enableCache {
                            TextField("Cache Path", text: $settings.cachePath)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    .padding(5)
                }
                
                GroupBox(label: Label("Similarity Threshold", systemImage: "slider.horizontal.3")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Slider(value: $settings.minSimilarityThreshold, in: 0...1, step: 0.01)
                        Text(String(format: "%.2f", settings.minSimilarityThreshold))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(5)
                }
                
                HStack {
                    Spacer()
                    Button(action: saveSettings) {
                        Label("Save", systemImage: "checkmark.circle")
                            .padding(.vertical, 5)
                            .padding(.horizontal, 10)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 820, minHeight: 640)
            .onAppear(perform: loadSettings)
            
            if showSaveBanner {
                Text("Сохранено")
                    .padding()
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 10)
            }
        }
    }
}

extension SettingsView {

    private func loadSettings() {
        guard let url = settingsFileURL else { return }
        settings.load(from: url)
    }

    private func saveSettings() {
        let url = URL(fileURLWithPath: projectRoot).appendingPathComponent("settings.json")
        settings.save(to: url)

        withAnimation { showSaveBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
                showSaveBanner = false
            }
        }
    }
}
