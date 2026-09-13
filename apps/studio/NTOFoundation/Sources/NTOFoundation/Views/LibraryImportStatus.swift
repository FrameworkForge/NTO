import AppKit
import SwiftUI
import UniformTypeIdentifiers

public struct LibraryImportStatus: View {
  @Bindable var library: LibraryController
  @State private var showReport = false
  public init(library: LibraryController) { self.library = library }
  public var body: some View {
    if library.isImporting || library.hasImportReport {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          if library.isImporting {
            ProgressView().controlSize(.small).accessibilityLabel("Importing photographs")
            Text(library.isCancelling ? "Cancelling import…" : library.progress).lineLimit(1)
            Spacer()
            Text("\(library.completed) / \(library.total)").monospacedDigit()
            Button("Cancel import") { library.cancelImport() }.disabled(library.isCancelling)
          } else {
            Text(library.progress)
            Spacer()
            Button("Details") { showReport = true }
            Button { library.dismissReport() } label: { Image(systemName: "xmark") }
              .accessibilityLabel("Dismiss import report")
          }
        }
        Text("\(library.imported) added · \(library.duplicates) already in project · \(library.issues.count) issues")
          .font(.caption).foregroundStyle(.secondary)
        if library.isImporting, library.total > 0 {
          ProgressView(value: Double(library.completed), total: Double(library.total)).tint(.white)
        }
      }.padding(12).background(NTOTokens.Color.canvas)
        .sheet(isPresented: $showReport) {
          VStack(alignment: .leading, spacing: 16) {
            Text("Import report").font(.title2)
            Text("\(library.imported) added. \(library.duplicates) duplicates skipped.")
            if library.issues.isEmpty { Text("No file errors.").foregroundStyle(.secondary) }
            else {
              ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                  ForEach(Array(library.issues.enumerated()), id: \.offset) { _, issue in
                    Text(issue).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                  }
                }
              }
            }
            HStack { Spacer(); Button("Done") { showReport = false }.keyboardShortcut(.defaultAction) }
          }.padding(24).frame(width: 520, height: 360)
        }
    }
  }
}
