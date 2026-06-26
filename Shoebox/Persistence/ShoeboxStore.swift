import Foundation
import SwiftData

/// Builds the SwiftData `ModelContainer`. In production it is backed by the
/// user's **private CloudKit database**, so receipts sync across the user's
/// devices and are private to their iCloud account — no app sign-up, no server
/// we operate. Previews and tests use an in-memory store.
enum ShoeboxStore {
    /// CloudKit container id — must match `Shoebox.entitlements`.
    static let cloudKitContainerID = "iCloud.ca.electronicrenaissance.shoebox"

    @MainActor
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        // `.automatic` enables CloudKit sync ONLY when the iCloud entitlement is
        // actually provisioned at runtime. In a signed build with our entitlement
        // (one container — see Shoebox.entitlements) it syncs to the user's
        // private database; in the Simulator / unsigned builds it stays a local
        // store instead of trapping during CloudKit setup. This is also the
        // signed-out-of-iCloud behaviour the PRD requires (FR-ID3).
        let configuration = inMemory
            ? ModelConfiguration(isStoredInMemoryOnly: true)
            : ModelConfiguration(cloudKitDatabase: .automatic)

        do {
            return try ModelContainer(for: Receipt.self, configurations: configuration)
        } catch {
            fatalError("Failed to create the Shoebox ModelContainer: \(error)")
        }
    }

    /// An in-memory container seeded for previews.
    @MainActor
    static func previewContainer() -> ModelContainer {
        let container = makeContainer(inMemory: true)
        SampleData.insert(into: container.mainContext)
        return container
    }
}
