import Foundation
import CoreText

/// Registers the bundled DM Sans font with Core Text so SwiftUI can reference
/// the "DM Sans" family by name. Called once at launch.
///
/// The font ships as a package resource (see `Package.swift`), so it's resolved
/// via `Bundle.module` — which works both for `swift build` and for the packaged
/// `.app` (see `scripts/run.sh`, which copies the resource bundle in).
enum FontLoader {
    static func registerBundledFonts() {
        guard let urls = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) else {
            return
        }
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
