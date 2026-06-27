import SwiftUI

/// The import methods, shared by every "Add" affordance so they stay in sync.
struct ImportOptions: View {
    @Environment(ImportCoordinator.self) private var importer

    var body: some View {
        if importer.canScan {
            Button("Scan Document", systemImage: "doc.viewfinder") { importer.scanDocument() }
        }
        Button("Choose Photos", systemImage: "photo.on.rectangle") { importer.choosePhotos() }
        Button("Import PDFs", systemImage: "doc.badge.plus") { importer.importPDFs() }
    }
}

/// The standard nav-bar "+" create affordance (Apple's recommended primary-action
/// placement). Opens the import methods.
struct AddReceiptMenu: View {
    var body: some View {
        Menu {
            ImportOptions()
        } label: {
            Label("Add Receipt", systemImage: "plus")
        }
    }
}

/// A prominent "Add Receipt" button for empty states — same options, bordered.
struct AddReceiptButton: View {
    var body: some View {
        Menu {
            ImportOptions()
        } label: {
            Label("Add Receipt", systemImage: "plus")
        }
        .menuStyle(.button)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}
