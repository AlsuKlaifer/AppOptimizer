//
//  RemoveManager.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 09.06.2025.
//

import Foundation

final class RemoveManager {
    
    // MARK: Private properties
    
    private let appPath: String
    
    // MARK: Lifecycle
    
    init(appPath: String) {
        self.appPath = appPath
    }
    
    // MARK: Internal methods
    
    func removeUnused(outputFile: String) -> String {
        guard !appPath.isEmpty else {
            return "Укажите путь к проекту"
        }
        
        let pathURL = URL(fileURLWithPath: appPath)
        let rootURL: URL = {
            let ext = pathURL.pathExtension.lowercased()
            return (ext == "xcodeproj" || ext == "xcworkspace")
            ? pathURL.deletingLastPathComponent()
            : pathURL
        }()
        
        let fm = FileManager.default
        var results = [String]()
        
        // Регулярка для разбора строк warning
        let pattern = #"^(.+?)\s+warning:\s+(\w+)\s+'([^']+)'\s+is unused"#
        let declRegex = try? NSRegularExpression(pattern: pattern)
        
        for rawLine in outputFile.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.lowercased() == "unused code:" || line == "unused assets:" {
                continue
            }
            guard !line.isEmpty else { continue }
            
            if let match = declRegex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                let ns = line as NSString
                let rawPath  = ns.substring(with: match.range(at: 1))
                let declType = ns.substring(with: match.range(at: 2))
                let declName = ns.substring(with: match.range(at: 3))
                
                let relPath = cleanRelativePath(rawPath, in: rootURL)
                let fileURL = rootURL.appendingPathComponent(relPath)
                
                switch declType.lowercased() {
                case "class", "struct", "enum", "protocol", "typealias":
                    if canDeleteEntireFile(named: declName, in: fileURL) {
                        do {
                            try fm.removeItem(at: fileURL)
                            results.append("Deleted file: \(relPath)")
                        } catch {
                            results.append("Failed to delete file \(relPath): \(error)")
                        }
                    } else if removeDeclaration(named: declName, type: declType, in: fileURL) {
                        results.append("Removed \(declType.lowercased()) \(declName) in \(relPath)")
                    } else {
                        results.append("Failed to remove \(declType.lowercased()) \(declName) in \(relPath)")
                    }
                    
                case "function":
                    if removeFunction(named: declName, in: fileURL) {
                        results.append("Removed function \(declName) in \(relPath)")
                    } else {
                        results.append("Failed to remove function \(declName) in \(relPath)")
                    }
                    
                case "property":
                    if removeProperty(named: declName, in: fileURL) {
                        results.append("Removed property \(declName) in \(relPath)")
                    } else {
                        results.append("Failed to remove property \(declName) in \(relPath)")
                    }
                    
                default:
                    results.append("Unknown declaration type '\(declType)' for \(relPath)")
                }
                
            } else {
                // ассет
                let assetName = line
                var deletedAny = false
                if let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: nil) {
                    for case let url as URL in enumerator {
                        if url.deletingPathExtension().lastPathComponent == assetName {
                            do {
                                try fm.removeItem(at: url)
                                let rel = url.path.replacingOccurrences(of: rootURL.path + "/", with: "")
                                results.append("Deleted asset: \(rel)")
                                deletedAny = true
                            } catch {
                                results.append("Failed to delete asset \(assetName): \(error)")
                            }
                        }
                    }
                }
                if !deletedAny {
                    results.append("Asset not found: \(assetName)")
                }
            }
        }
        
        let outputFile = results.joined(separator: "\n")
        return outputFile
    }
    
    
    /// MARK: — Достаем путь
    private func cleanRelativePath(_ rawPath: String, in rootURL: URL) -> String {
        var path = rawPath
        if let url = URL(string: rawPath), url.isFileURL {
            path = url.path
        }
        path = path.replacingOccurrences(
            of: #":[0-9]+(:[0-9]+)?:$"#,
            with: "",
            options: .regularExpression
        )
        if path.hasPrefix(rootURL.path + "/") {
            path = String(path.dropFirst(rootURL.path.count + 1))
        }
        return path
    }

    private func removeFunction(named signature: String, in url: URL) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        let lines = content.components(separatedBy: .newlines)
        var newLines = [String]()
        var removed = false
        var skipNextBlank = false

        let funcName = signature.components(separatedBy: "(")[0]
        let pattern = #"^\s*(?:public|internal|fileprivate|private|open)?\s*func\s+\#(funcName)\b"#
        let regex = try? NSRegularExpression(pattern: pattern)
        
        var skip = false
        var depth = 0
        
        for line in lines {
            if !skip,
               let rx = regex,
               rx.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) != nil
            {
                skip = true
                removed = true
                skipNextBlank = true

                for ch in line where ch == "{" { depth += 1 }
                for ch in line where ch == "}" { depth -= 1 }
                continue
            }
            
            if skip {
                for ch in line where ch == "{" { depth += 1 }
                for ch in line where ch == "}" { depth -= 1 }
                if depth <= 0 {
                    skip = false
                }
                continue
            }
            
            // если предыдущая декларация удалена — разово пропускаем одну пустую строку
            if skipNextBlank, line.trimmingCharacters(in: .whitespaces).isEmpty {
                skipNextBlank = false
                continue
            }
            
            newLines.append(line)
        }
        
        guard removed else { return false }
        do {
            try newLines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    private func removeProperty(named name: String, in url: URL) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        let lines = content.components(separatedBy: .newlines)
        var newLines = [String]()
        var removed = false
        var skipNextBlank = false
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("var \(name)") || trimmed.hasPrefix("let \(name)") {
                removed = true
                skipNextBlank = true
                continue
            }
            
            if skipNextBlank, trimmed.isEmpty {
                skipNextBlank = false
                continue
            }
            
            newLines.append(line)
        }
        
        guard removed else { return false }
        do {
            try newLines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
    
    
    /// MARK: — Удаляем declaration (class/struct/enum/protocol/typealias), и одну пустую строку после
    private func removeDeclaration(named name: String, type: String, in url: URL) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        let lines = content.components(separatedBy: .newlines)
        var newLines = [String]()
        let keyword = type.lowercased()
        var removed = false
        var skipNextBlank = false
        
        if keyword == "typealias" {
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("typealias \(name)") {
                    removed = true
                    skipNextBlank = true
                } else if skipNextBlank, trimmed.isEmpty {
                    skipNextBlank = false
                    continue
                } else {
                    newLines.append(line)
                }
            }
        } else {
            let pattern = #"^\s*(?:public|internal|fileprivate|private|open)?\s*\#(keyword)\s+\#(name)\b"#
            let regex = try? NSRegularExpression(pattern: pattern)
            
            var skip = false
            var depth = 0
            
            for line in lines {
                if !skip,
                   let rx = regex,
                   rx.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) != nil
                {
                    removed = true
                    skip = true
                    skipNextBlank = true
                    for ch in line where ch == "{" { depth += 1 }
                    for ch in line where ch == "}" { depth -= 1 }
                    continue
                }
                
                if skip {
                    for ch in line where ch == "{" { depth += 1 }
                    for ch in line where ch == "}" { depth -= 1 }
                    if depth <= 0 {
                        skip = false
                    }
                    continue
                }
                
                if skipNextBlank, line.trimmingCharacters(in: .whitespaces).isEmpty {
                    skipNextBlank = false
                    continue
                }
                
                newLines.append(line)
            }
        }
        
        guard removed else { return false }
        do {
            try newLines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    private func canDeleteEntireFile(named name: String, in url: URL) -> Bool {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        var stripped = removeBlockDeclarations(keyword: "class", name: name, from: content)
        stripped = removeBlockDeclarations(keyword: "struct", name: name, from: stripped)
        stripped = removeBlockDeclarations(keyword: "enum",  name: name, from: stripped)
        stripped = removeBlockDeclarations(keyword: "protocol", name: name, from: stripped)
        stripped = stripped.replacingOccurrences(
            of: #"\s*typealias\s+\#(name)\b.*\n"#,
            with: "",
            options: .regularExpression
        )
        
        for line in stripped.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix("//") { continue }
            if trimmed.range(of: #"^import\s+\w+"#, options: .regularExpression) != nil {
                continue
            }
            return false
        }
        return true
    }

    private func removeBlockDeclarations(keyword: String, name: String, from content: String) -> String {
        var result = ""
        var idx = content.startIndex
        let pattern = #"^\s*(?:public|internal|fileprivate|private|open)?\s*\#(keyword)\s+\#(name)\b"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
        
        while idx < content.endIndex {
            if let match = regex?.firstMatch(in: content, options: [], range: NSRange(idx..<content.endIndex, in: content)) {
                let start = content.index(content.startIndex, offsetBy: match.range.location)
                result += String(content[idx..<start])
                guard let openBrace = content.range(of: "{", range: start..<content.endIndex) else {
                    idx = content.endIndex
                    break
                }
                var depth = 1
                var cursor = openBrace.upperBound
                while depth > 0, cursor < content.endIndex {
                    let ch = content[cursor]
                    if ch == "{" { depth += 1 }
                    else if ch == "}" { depth -= 1 }
                    cursor = content.index(after: cursor)
                }
                idx = cursor
            } else {
                result += String(content[idx..<content.endIndex])
                break
            }
        }
        return result
    }
}
