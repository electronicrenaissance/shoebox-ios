# Shoebox iOS

A **native iOS** AI receipt organizer for the Canadian **personal (T1)** income-tax
market — rebuilt to run **entirely on the device**. Scan a receipt and Shoebox
reads it, checks whether it would be **acceptable to the CRA**, and sorts it by tax
line — using **Apple Intelligence** on-device, storing everything in your **private
iCloud**.

> **The pivot.** This is a ground-up rewrite of the original cross-platform Shoebox
> (Next.js web + Expo mobile + Node/MongoDB API + Claude). It keeps the same
> product idea and design language, but:
>
> | | Original (`../shoebox`) | This app |
> |---|---|---|
> | Platform | Web + React Native + API | **Native iOS (SwiftUI)** |
> | AI | Claude (cloud) | **Apple Intelligence (on-device)** |
> | Storage | MongoDB + S3 | **iCloud (CloudKit private DB)** |
> | Accounts | Email/Google + 2FA | **None** — uses the device's iCloud |
> | Backend | Express on AWS | **None** |
>
> Why: no per-scan AI cost, no servers to run or secure, no sign-up friction, and
> receipt data that never leaves the user's device/iCloud.

See [`docs/prd/001-mvp.md`](docs/prd/001-mvp.md) for the MVP product spec and
[`docs/architecture/app-architecture.md`](docs/architecture/app-architecture.md)
for the architecture.

## What it does (MVP)

**Capture → extract → validate → match to line(s) → store → review.**

- **Capture** — scan with the camera (VisionKit), pick an image, or import a PDF.
- **Read on-device** — Vision OCR feeds Apple Intelligence, which extracts the
  vendor/date/amount/tax, validates **CRA acceptability**, and matches the receipt
  to one or more **T1 tax lines** (medical, donations, child care, …).
- **Review** — a list of receipts with status + matched line; tap to see the
  validation findings, edit any field, override the verdict, or delete.
- **Sync** — receipts live in your **private iCloud** and appear on your other
  devices. No account, no server.

## Requirements

- **macOS** with **Xcode 26** or later.
- **iOS 26** deployment target.
- A device with **Apple Intelligence** for on-device reading (recent A-series /
  M-series, AI enabled). On other devices the app still runs — capture and manual
  entry work; automatic reading is skipped with an explanation.
- An **Apple Developer account** for CloudKit (set your team in Xcode). CloudKit
  container: `iCloud.ca.electronicrenaissance.shoebox`.

## Getting started

The Xcode project is generated from [`project.yml`](project.yml) with
[XcodeGen](https://github.com/yonsm/XcodeGen), so it isn't checked in.

```bash
# 1. Install XcodeGen (one-time)
brew install xcodegen

# 2. Generate the Xcode project
xcodegen generate

# 3. Open and run
open Shoebox.xcodeproj
```

In Xcode, set your **Development Team** (Signing & Capabilities) so CloudKit and
the camera entitlement provision. Then build & run on a device (the document
scanner and Apple Intelligence need real hardware; the Simulator falls back to the
mock reader and manual entry).

### Run the tests

```bash
xcodebuild test \
  -project Shoebox.xcodeproj \
  -scheme Shoebox \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

The unit tests (Swift Testing) cover the pure pipeline logic — the mock reader and
the structured-output mapping. The on-device model itself is verified manually on
capable hardware (it can't run in CI/Simulator).

## Project layout

```
Shoebox/
  App/           ShoeboxApp (@main) + ReceiptProcessor (capture→read→store)
  Models/        Receipt (@Model), ReceiptStatus, TaxLine taxonomy
  Persistence/   ShoeboxStore (CloudKit), SampleData
  Capture/       VisionKit scanner, thumbnailer
  Intelligence/  Vision OCR + Apple Intelligence reader (+ mock + factory)
  Features/      ReceiptList, AddReceipt, ReceiptDetail, Components
  DesignSystem/  Theme (brand tokens ported from the web app)
  Resources/     Info.plist, entitlements, asset catalog
ShoeboxTests/    Swift Testing unit tests
docs/            PRD (prd/) and architecture (architecture/)
project.yml      XcodeGen spec — source of truth for the Xcode project
```

## Tech stack

SwiftUI · SwiftData + CloudKit · Foundation Models (Apple Intelligence) · Vision ·
VisionKit · PDFKit · PhotosUI. No backend, no third-party dependencies.

## Disclaimer

Shoebox gives **guidance, not tax advice**. Its CRA-acceptability checks are
conservative suggestions, not a guarantee that a receipt will be accepted. It does
not compute claim amounts.
