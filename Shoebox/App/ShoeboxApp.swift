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
    }
}
