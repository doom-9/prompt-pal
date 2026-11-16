import Carbon.HIToolbox
import Foundation
import XCTest
@testable import PromptPalCore

final class HotKeyConfigTests: XCTestCase {
    func testDefaultHotKeyIsOptionSpace() {
        let config = HotKeyConfig.defaultHotKey
        XCTAssertEqual(config.keyCode, UInt32(kVK_Space))
        XCTAssertEqual(config.carbonModifiers, UInt32(optionKey))
        XCTAssertEqual(config.displayString, "⌥ Space")
    }

    func testSaveAndLoadRoundTrip() {
        let suiteName = "PromptPalTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let custom = HotKeyConfig(keyCode: UInt32(kVK_ANSI_P), carbonModifiers: UInt32(cmdKey | shiftKey))
        custom.save(to: defaults)

        let loaded = HotKeyConfig.load(from: defaults)
        XCTAssertEqual(loaded, custom)
    }

    func testDisplayStringFormatsModifiersAndKey() {
        let config = HotKeyConfig(
            keyCode: UInt32(kVK_ANSI_P),
            carbonModifiers: UInt32(cmdKey | shiftKey)
        )
        XCTAssertEqual(config.displayString, "⇧⌘ P")
    }
}
