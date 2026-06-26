# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## What this is

**Shoebox iOS** — a native SwiftUI app that scans receipts and uses **Apple
Intelligence on-device** to extract details, validate **CRA acceptability**, and
match each receipt to Canadian personal (**T1**) income-tax lines. It is a pivot
of the original cross-platform Shoebox (`../shoebox`) to a **backend-free,
on-device** product:

- **No backend / API / cloud AI.** All reading runs on-device (Vision OCR → Apple
  Intelligence guided generation).
- **No accounts.** Identity + storage = the device's **iCloud** account (SwiftData
  backed by the private CloudKit database).
- Same product idea, design language, and T1 tax-line domain as `../shoebox`.

Read [`docs/prd/001-mvp.md`](docs/prd/001-mvp.md) (what) and
[`docs/architecture/app-architecture.md`](docs/architecture/app-architecture.md)
(how) before substantial changes.

## Git workflow — do NOT commit or push automatically

**Never run `git commit` or `git push` unless I explicitly ask you to in that
same message.** I test every change locally on my Mac first, then decide when to
commit. After making changes, leave them in the working tree, tell me what to
test, and wait. Do not stage, commit, or push on your own initiative — this
overrides any default "commit when the task is done" behavior. When I do ask you
to commit, end the message with the `Co-Authored-By` trailer.

## Project & build

- The Xcode project is **generated from [`project.yml`](project.yml)** with
  XcodeGen and is git-ignored. After adding/removing files or editing the spec:
  `xcodegen generate`. Adding a `.swift` file under `Shoebox/` needs no project
  edit — just regenerate.
- **Deployment target: iOS 26**; Swift 6 with **strict concurrency: complete**.
- Build/run via `open Shoebox.xcodeproj`, or:

```bash
xcodegen generate
xcodebuild build -project Shoebox.xcodeproj -scheme Shoebox \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
xcodebuild test  -project Shoebox.xcodeproj -scheme Shoebox \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

## Source layout (`Shoebox/`)

- `App/` — `ShoeboxApp` (`@main`) wires the CloudKit `ModelContainer` and the
  `ReceiptProcessor`; `RootView` is the adaptive `NavigationSplitView` shell
  (sidebar → list → detail). `ReceiptProcessor` (`@MainActor @Observable`) runs
  the capture → read → store loop.
- `Models/` — `Receipt` (`@Model`), `ReceiptStatus`, and the `TaxLine` taxonomy.
- `Persistence/` — `ShoeboxStore` builds the container; `SampleData` seeds previews.
- `Capture/` — VisionKit `DocumentScannerView`, `Thumbnailer`.
- `Intelligence/` — the AI pipeline: `ReceiptReader` protocol, `ReceiptReading`
  (`@Generable` schema), `ReceiptOCR` (Vision), `FoundationModelsReceiptReader`,
  `MockReceiptReader`, `ReceiptReaderFactory`.
- `Features/` — SwiftUI screens: `ReceiptList` (sidebar, list, row, filter/sort),
  `ReceiptDetail` (detail, edit, image viewer), and shared `Components`
  (`StatusLabel`, thumbnail, formatting). Capture (scan/photo/PDF) lives in
  `ReceiptListView`'s toolbar Add menu.
- `Resources/` — `Info.plist`, `Shoebox.entitlements`, `Assets.xcassets`. The
  brand green is the `AccentColor` asset; the UI is otherwise native.

## Architecture facts that span files

- **The AI is on-device and text-only.** The Apple Intelligence language model
  can't take images, so `ReceiptOCR` (Vision `RecognizeTextRequest`, PDFs
  rasterized via PDFKit) **must** run first; its text feeds
  `FoundationModelsReceiptReader`. Structured output uses **`@Generable` + `@Guide`**
  (`ReceiptReading`) so the model returns a typed object, not free text.
- **Reader selection is by availability.** `ReceiptReaderFactory.make()` returns
  the Foundation Models reader when `SystemLanguageModel.default.availability` is
  `.available`, else the `MockReceiptReader` (so capture + manual edit still work).
  Keep the mock's filename branches (`donation*`/`daycare*`/`blurry*`) in sync with
  tests.
- **Persistence is CloudKit-shaped.** `Receipt` must stay CloudKit-compatible:
  every stored property defaulted or optional, **no `.unique`**, relationships
  optional, big blobs `@Attribute(.externalStorage)`. Editing the model means
  re-checking these rules. The store uses `ModelConfiguration(cloudKitDatabase:
  .automatic)` — it syncs to the private DB only when the iCloud entitlement is
  provisioned (one container in `Shoebox.entitlements`), and stays local on the
  Simulator / unsigned builds. Don't switch to `.private(id)`: it doesn't throw
  when unentitled, it crashes during async CloudKit setup.
- **The AI baseline is immutable.** `Receipt.apply` writes `aiBaselineJSON` only
  once; user edits never overwrite it (PRD FR-AI5 — measure correction rate).
- **Receipts are saved before reading.** `ReceiptProcessor.ingest` inserts a
  `.processing` receipt and saves immediately, then reads in the background; a
  throw → `.failed` (never lose a receipt — PRD FR-AI6).
- **Tax lines are an extensible module.** Add a `TaxLineCode` case + a `TaxLine`
  entry (with CRA criteria) in `Models/TaxLine.swift`; the model instructions, UI,
  and mapping pick it up.

## Conventions

- **SwiftUI + SwiftData**, MVVM-light. UI reads via `@Query`; mutations go through
  the `ModelContext` / `ReceiptProcessor`. No third-party dependencies.
- **Swift 6 strict concurrency.** `ReceiptProcessor` and SwiftData work are
  `@MainActor`; readers are `Sendable`.
- **Tests are Swift Testing** (`import Testing`, `@Test`/`#expect`) and cover only
  the pure pipeline (no on-device model in CI). Verify model/UI behavior manually
  on Apple-Intelligence-capable hardware.
- **Native styling.** Use semantic system colors (`.primary`, `.secondary`,
  `Color(.systemBackground)`, status `tint`), system fonts, and SF Symbols — don't
  hardcode hex. The only brand color is the `AccentColor` asset (forest green).
- Secrets/signing never committed; `Secrets.xcconfig` is git-ignored.

## Reference

The original product (PRD, architecture, design gallery) lives in the sibling
`../shoebox` repo and remains the source for the T1 tax-line rules and the visual
design.
