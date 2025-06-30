//
//  DeleteResultsSheet.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 09.06.2025.
//

import SwiftUI

struct DeleteResultsSheet: View {
    let output: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Результаты удаления")
                .font(.headline)
            Divider()
            ScrollView {
                Text(output)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .frame(minWidth: 600, minHeight: 200)
            Divider()
            Button("OK", action: onDismiss)
                .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
}
