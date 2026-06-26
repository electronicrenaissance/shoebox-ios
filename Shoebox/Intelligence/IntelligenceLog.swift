import Foundation
import os

/// Logging for the on-device intelligence pipeline (Vision OCR + Apple
/// Intelligence). Decisions and metadata are logged at `.info`; the actual
/// receipt *content* (recognized text, the model prompt) is logged at `.debug`
/// so it stays out of the persisted log store by default but is available when
/// you explicitly stream debug logs.
///
/// View the logs live while using the app:
///
///   log stream --predicate 'subsystem == "ca.electronicrenaissance.shoebox"' --level debug
///
/// …or after the fact:
///
///   log show --last 10m --info --debug \
///     --predicate 'subsystem == "ca.electronicrenaissance.shoebox"'
enum IntelligenceLog {
    static let subsystem = "ca.electronicrenaissance.shoebox"
    static let logger = Logger(subsystem: subsystem, category: "intelligence")
}
