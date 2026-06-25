# Architecture — Shoebox iOS (on-device, backend-free)

| | |
|---|---|
| **Status** | Scaffolding (MVP in progress) |
| **Author** | Bryan Higgins |
| **Created** | 2026-06-24 |
| **Owner** | Bryan Higgins |
| **Related** | [`docs/prd/001-mvp.md`](../prd/001-mvp.md) (the *what*) |

> **Scope.** The *how* behind the receipt feature on iOS: capture → OCR →
> on-device extraction + CRA validation + line matching → store → review/edit/
> delete — with **no backend**, using **Apple Intelligence** for AI and the user's
> **private iCloud** for storage.

---

## 1. Overview

Shoebox iOS is a single SwiftUI app. The core loop is **capture → read → store →
review**, and every step runs **on the device**:

```
  capture (camera scan / photo / PDF)
        │  VisionKit doc scanner · PhotosPicker · Files importer
        │  normalized to JPEG (PDF → first page rendered)
        ▼
  ReceiptProcessor.ingest(...)
        │  insert Receipt { status: .processing } + thumbnail   ──► appears in list immediately,
        │  SwiftData save → CloudKit private DB                       saved before reading (never lost)
        ▼  (background Task)
  ReceiptReader.read(input)
        │  1. Vision  — RecognizeTextRequest → recognized text
        │  2. Apple Intelligence — LanguageModelSession + @Generable guided generation
        │       → { extraction, CRA verdict, matched line(s) }
        ▼
  Receipt.apply(reading)  → status/extraction/validation/lines, AI baseline kept
        └─ on throw → status: .failed (receipt stays, editable by hand — PRD FR-AI6)
```

There is no API, no auth, no job queue, and no cloud inference. SwiftData + the
private CloudKit database give per-user isolation (the iCloud account) and
cross-device sync for free.

## 2. Platform & frameworks

| Concern | Framework | Notes |
|---|---|---|
| UI | **SwiftUI** | iOS 26+, iPhone + iPad |
| Persistence | **SwiftData** (`@Model`) | local store, CloudKit-backed |
| Sync / storage | **CloudKit** private DB | via `ModelConfiguration(cloudKitDatabase:)` |
| OCR | **Vision** (`RecognizeTextRequest`) | text-only model needs text input |
| On-device AI | **Foundation Models** (Apple Intelligence) | `LanguageModelSession`, `@Generable` guided generation |
| Camera capture | **VisionKit** (`VNDocumentCameraViewController`) | auto-crop/deskew |
| Image/PDF import | **PhotosUI** · **PDFKit** · `fileImporter` | |

**Deployment target: iOS 26.0** (Foundation Models + the modern Vision Swift API).

## 3. Module / source layout

```
Shoebox/
  App/
    ShoeboxApp.swift          @main; builds the ModelContainer + ReceiptProcessor
    ReceiptProcessor.swift    capture → read → store orchestration (@MainActor @Observable)
  Models/
    Receipt.swift             @Model — the synced record (CloudKit-safe)
    ReceiptStatus.swift       lifecycle + CRA verdict enum
    TaxLine.swift             T1 line taxonomy + CRA criteria (extensible)
  Persistence/
    ShoeboxStore.swift        ModelContainer (CloudKit / in-memory)
    SampleData.swift          preview seed data
  Capture/
    DocumentScannerView.swift VisionKit wrapper (UIViewControllerRepresentable)
    Thumbnailer.swift         list-thumbnail generation
  Intelligence/
    ReceiptReader.swift       protocol + input/errors
    ReceiptReading.swift      @Generable structured-output schema + mapping
    ReceiptOCR.swift          Vision OCR (+ PDF rasterization)
    FoundationModelsReceiptReader.swift   production reader
    MockReceiptReader.swift   deterministic reader (previews/tests/fallback)
    ReceiptReaderFactory.swift  picks reader by AI availability
  Features/
    ReceiptList/   list, row, empty state
    AddReceipt/    capture bottom sheet
    ReceiptDetail/ detail + edit
    Components/    badges, thumbnail, formatting
  DesignSystem/
    Theme.swift               colors, fonts, metrics (ported from web)
  Resources/
    Info.plist, Shoebox.entitlements, Assets.xcassets
```

The project file is generated from [`project.yml`](../../project.yml) via
**XcodeGen**, so adding a `.swift` file needs no manual project edit.

## 4. Data model (`Models/Receipt.swift`)

`Receipt` is a SwiftData `@Model` synced to CloudKit. **CloudKit constraints shape
it:** every stored property has a default value or is optional, there are **no
unique constraints**, and large blobs use `@Attribute(.externalStorage)` (stored
outside the SQLite file and synced as CloudKit assets).

- **Identity:** `id: UUID` (generated; not a DB-unique constraint).
- **Capture:** `fileName`, `mimeType`, `imageData` (external), `thumbnailData`
  (external).
- **Status:** stored as a raw `String`, exposed as `ReceiptStatus`
  (`processing` → `acceptable | needs_attention | not_a_tax_receipt | failed`).
- **Extraction:** `vendor?`, `date?`, `total?`, `currency`, `taxAmount?`,
  `details?`, plus identifiers (`charityRegistration?`, `providerName?`).
- **Validation:** `validationReasons: [String]`, `acceptabilityOverride: Bool`.
- **Lines:** `matchedLines: [TaxLineMatch]` — `TaxLineMatch` is a `Codable` value
  type SwiftData stores as a composite attribute.
- **AI baseline:** `aiBaselineJSON?` — the model's original reading, written once
  and preserved through user edits (PRD FR-AI5, to measure correction rate).

The tax-line taxonomy (`TaxLine.swift`) holds, per line, the display metadata and
the **CRA acceptance criteria string** fed to the model's instructions. Adding a
line = adding a `TaxLineCode` case + a `TaxLine` entry.

## 5. On-device AI pipeline (`Intelligence/`)

`ReceiptReader { func read(_:) async throws -> ReceiptReading }` has two
implementations chosen by `ReceiptReaderFactory` based on
`SystemLanguageModel.default.availability`:

### 5.1 `FoundationModelsReceiptReader` (production)

1. **Availability gate.** If Apple Intelligence is `.unavailable(reason)`, throw
   `ReceiptReaderError.modelUnavailable` (the factory instead falls back to the
   mock so manual entry still works — PRD FR-AI9/G8).
2. **OCR.** `ReceiptOCR.recognizeText` runs Vision's `RecognizeTextRequest`
   (accurate, language-corrected) on the capture; PDFs are rasterized (PDFKit,
   first page, 2× scale) first. The on-device language model is **text-only**, so
   this step is required.
3. **Guided generation.** A `LanguageModelSession` is created with instructions
   that encode the §8 CRA criteria, conservative validation, and the
   no-amount-computation rule. `session.respond(to:generating: ReceiptReading.self)`
   uses **`@Generable` + `@Guide`** to force schema-valid structured output — we
   get a typed `ReceiptReading`, not free text to parse.

`ReceiptReading` (`@Generable`) is the on-device analogue of the old backend's
`ReceiptReadResult`: extraction fields + a `Verdict` enum + `reasons` + an array
of `GeneratedMatch { code, confidence }`. Mapping back to the domain
(`status`, `parsedDate`, `matchedLines`) validates line codes (unknown → `.other`)
and de-duplicates.

### 5.2 `MockReceiptReader` (previews / tests / unsupported devices)

Deterministic by filename (`donation*` → needs-attention 34900, `daycare*` →
21400, `blurry*` → throws → failed, else → acceptable medical), mirroring the
original backend mock so every status branch is exercisable with no model.

## 6. Capture (`Capture/`, `Features/AddReceipt/`)

`AddReceiptSheet` offers three paths and produces a `ReceiptInput { data,
mimeType, fileName }`:

- **Camera** → `DocumentScannerView` (VisionKit) → first page as JPEG.
- **Photo** → `PhotosPicker`; HEIC/other normalized to JPEG.
- **PDF** → `fileImporter` (security-scoped read) → raw PDF bytes.

Images are normalized to JPEG for consistent OCR; PDFs are kept as-is and
rasterized only at read time.

## 7. Processing orchestration (`App/ReceiptProcessor.swift`)

`@MainActor @Observable`. `ingest(input, into: context)` inserts a `processing`
`Receipt` (with thumbnail) and saves **immediately** — so it shows in the list and
survives a read failure — then launches a background `Task` that calls
`reader.read`, applies the result, and saves. A throw sets `.failed`.
`reprocess(_:in:)` re-runs the read for an existing receipt (retry / after edit).

SwiftUI reads the data with `@Query` (newest first); CloudKit changes flow in
through SwiftData automatically. Polling/job-queue machinery from the server
version is gone — the model writes back to the same context the UI observes.

## 8. Storage & sync (`Persistence/ShoeboxStore.swift`)

`ModelConfiguration(cloudKitDatabase: .automatic)` binds the SwiftData store to
the user's **private** CloudKit database **when the iCloud entitlement is
provisioned at runtime** (the entitlements file declares exactly one container,
`iCloud.com.vivtechnologies.shoebox`, so `.automatic` resolves to it). On the
Simulator or in unsigned builds the entitlement isn't applied, so `.automatic`
stays a local store rather than trapping during CloudKit setup — which is also the
signed-out-of-iCloud behaviour (FR-ID3). (`.private(id)` is avoided because it
does **not** throw when unentitled; it crashes asynchronously during mirroring.)
Result:

- **No accounts** — isolation is the iCloud account; the app never sees an identity.
- **Sync** — receipts/images propagate across the user's devices automatically.
- **Offline-first** — writes are local first; CloudKit reconciles when online.
- Signed-out of iCloud, the same store works **locally** (no sync) until the user
  enables iCloud.

Entitlements (`Resources/Shoebox.entitlements`): CloudKit service + container id +
`aps-environment` for sync push. `Info.plist` declares `NSCameraUsageDescription`
and the `remote-notification` background mode.

## 9. Design system (`DesignSystem/Theme.swift`)

Ports the original brand tokens so the native app matches the web/mobile look:
paper `#FAF8F4`, ink `#1B1A17`, muted `#6B675E`, line `#E8E4DC`, forest-green
brand `#15573B` (dark `#0F4530`, light `#E6F0EA`), serif display headings. Badges,
the receipt thumbnail, and card chrome are small reusable SwiftUI views under
`Features/Components/`.

## 10. Testing

**Swift Testing** (`ShoeboxTests/`). The pure pipeline pieces — the mock reader's
branches, `ReceiptReading` line-code mapping/dedup, and ISO date parsing — are
unit-tested without a device model. UI and on-device-model behavior are validated
manually on Apple-Intelligence-capable hardware (the model can't run in tests/CI).

## 11. Constraints & trade-offs

- **Apple Intelligence requires capable hardware** (recent A-series/M-series, AI
  enabled, model downloaded). The factory degrades to manual entry elsewhere.
- **The model is text-only** → OCR is a mandatory first stage; OCR quality bounds
  extraction quality.
- **Data residency is Apple-managed** and not pinnable to Canada (PRD §9.1).
- **CloudKit shapes the schema** — no unique constraints, defaulted/optional
  attributes, `.externalStorage` for blobs.
- **No CI for the AI path** — on-device-model output is verified on hardware.

## 12. Out of scope → fast-follows

Multi-receipt-per-file detection; richer Vision document structure
(`RecognizeDocumentsRequest`) for tables/prices; `@Guide(.anyOf(...))` constrained
line codes; in-app PDF page navigation; Share Sheet / Shortcuts ingestion; a
"needs attention" smart filter and widgets; the T2125 module; province credits;
amount computation; export. See [`docs/prd/001-mvp.md`](../prd/001-mvp.md) §13.
