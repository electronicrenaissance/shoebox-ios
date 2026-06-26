import SwiftUI
import SwiftData

@main
struct ShoeboxApp: App {
    /// CloudKit-backed SwiftData store. No sign-in: data lives in the user's
    /// private iCloud database, keyed to the device's Apple ID.
    private let modelContainer: ModelContainer

    /// Owns the on-device reader and the capture → read → store loop.
    @State private var processor: ReceiptProcessor

    init() {
        modelContainer = ShoeboxStore.makeContainer()
        processor = ReceiptProcessor(reader: ReceiptReaderFactory.make())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(processor)
        }
        .modelContainer(modelContainer)
        #if targetEnvironment(macCatalyst)
        .commands {
            CommandGroup(after: .saveItem) {
                ExportMenuCommand()
            }
        }
        #endif
    }
}

#if targetEnvironment(macCatalyst)
/// File ▸ Export… (⇧⌘S) — drives the focused window's export (the same Save panel
/// as the toolbar button). Disabled when no window publishes an export action.
private struct ExportMenuCommand: View {
    @FocusedValue(\.exportAction) private var exportAction

    var body: some View {
        Button("Export…") { exportAction?() }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(exportAction == nil)
    }
}
#endif
