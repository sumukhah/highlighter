import AppKit
import Carbon
import Foundation
import ServiceManagement

struct HotKeyConfiguration: Codable, Equatable {
    struct KeyOption: Equatable {
        let keyCode: UInt32
        let title: String
    }

    static let supportedKeys: [KeyOption] = [
        .init(keyCode: UInt32(kVK_ANSI_A), title: "A"),
        .init(keyCode: UInt32(kVK_ANSI_B), title: "B"),
        .init(keyCode: UInt32(kVK_ANSI_C), title: "C"),
        .init(keyCode: UInt32(kVK_ANSI_D), title: "D"),
        .init(keyCode: UInt32(kVK_ANSI_E), title: "E"),
        .init(keyCode: UInt32(kVK_ANSI_F), title: "F"),
        .init(keyCode: UInt32(kVK_ANSI_G), title: "G"),
        .init(keyCode: UInt32(kVK_ANSI_H), title: "H"),
        .init(keyCode: UInt32(kVK_ANSI_I), title: "I"),
        .init(keyCode: UInt32(kVK_ANSI_J), title: "J"),
        .init(keyCode: UInt32(kVK_ANSI_K), title: "K"),
        .init(keyCode: UInt32(kVK_ANSI_L), title: "L"),
        .init(keyCode: UInt32(kVK_ANSI_M), title: "M"),
        .init(keyCode: UInt32(kVK_ANSI_N), title: "N"),
        .init(keyCode: UInt32(kVK_ANSI_O), title: "O"),
        .init(keyCode: UInt32(kVK_ANSI_P), title: "P"),
        .init(keyCode: UInt32(kVK_ANSI_Q), title: "Q"),
        .init(keyCode: UInt32(kVK_ANSI_R), title: "R"),
        .init(keyCode: UInt32(kVK_ANSI_S), title: "S"),
        .init(keyCode: UInt32(kVK_ANSI_T), title: "T"),
        .init(keyCode: UInt32(kVK_ANSI_U), title: "U"),
        .init(keyCode: UInt32(kVK_ANSI_V), title: "V"),
        .init(keyCode: UInt32(kVK_ANSI_W), title: "W"),
        .init(keyCode: UInt32(kVK_ANSI_X), title: "X"),
        .init(keyCode: UInt32(kVK_ANSI_Y), title: "Y"),
        .init(keyCode: UInt32(kVK_ANSI_Z), title: "Z"),
        .init(keyCode: UInt32(kVK_ANSI_0), title: "0"),
        .init(keyCode: UInt32(kVK_ANSI_1), title: "1"),
        .init(keyCode: UInt32(kVK_ANSI_2), title: "2"),
        .init(keyCode: UInt32(kVK_ANSI_3), title: "3"),
        .init(keyCode: UInt32(kVK_ANSI_4), title: "4"),
        .init(keyCode: UInt32(kVK_ANSI_5), title: "5"),
        .init(keyCode: UInt32(kVK_ANSI_6), title: "6"),
        .init(keyCode: UInt32(kVK_ANSI_7), title: "7"),
        .init(keyCode: UInt32(kVK_ANSI_8), title: "8"),
        .init(keyCode: UInt32(kVK_ANSI_9), title: "9")
    ]

    static let `default` = HotKeyConfiguration(
        keyCode: UInt32(kVK_ANSI_H),
        modifiers: [.command, .shift]
    )

    var keyCode: UInt32
    private var modifiersRawValue: UInt

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiersRawValue = modifiers.intersection(.deviceIndependentFlagsMask).rawValue
    }

    var modifiers: NSEvent.ModifierFlags {
        get { NSEvent.ModifierFlags(rawValue: modifiersRawValue) }
        set { modifiersRawValue = newValue.intersection(.deviceIndependentFlagsMask).rawValue }
    }

    var displayString: String {
        var components: [String] = []
        let modifiers = self.modifiers
        if modifiers.contains(.command) { components.append("⌘") }
        if modifiers.contains(.shift) { components.append("⇧") }
        if modifiers.contains(.option) { components.append("⌥") }
        if modifiers.contains(.control) { components.append("⌃") }
        components.append(keyTitle)
        return components.joined()
    }

    var keyTitle: String {
        Self.supportedKeys.first(where: { $0.keyCode == keyCode })?.title ?? "H"
    }
}

struct AppPreferences: Codable, Equatable {
    static let `default` = AppPreferences(
        hotKey: .default,
        strokeWidth: 8,
        fadeDuration: 4,
        launchAtLogin: false
    )

    var hotKey: HotKeyConfiguration
    var strokeWidth: CGFloat
    var fadeDuration: TimeInterval
    var launchAtLogin: Bool
}

@MainActor
final class AppPreferencesStore {
    static let didChangeNotification = Notification.Name("HighlighterPreferencesDidChange")
    static let shared = AppPreferencesStore()

    private let userDefaults = UserDefaults.standard
    private let storageKey = "highlighter.preferences"

    private(set) var preferences: AppPreferences

    private init() {
        if
            let data = userDefaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data)
        {
            preferences = decoded
        } else {
            preferences = .default
        }

        syncLaunchAtLoginIfNeeded()
    }

    func updateHotKey(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        preferences.hotKey = HotKeyConfiguration(keyCode: keyCode, modifiers: modifiers)
        persist()
    }

    func updateStrokeWidth(_ value: CGFloat) {
        preferences.strokeWidth = value.clamped(to: 2...20)
        persist()
    }

    func updateFadeDuration(_ value: TimeInterval) {
        preferences.fadeDuration = value.clamped(to: 0.75...6)
        persist()
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        preferences.launchAtLogin = enabled
        syncLaunchAtLoginIfNeeded()
        persist()
    }

    private func persist() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            userDefaults.set(encoded, forKey: storageKey)
        }

        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    private func syncLaunchAtLoginIfNeeded() {
        guard #available(macOS 13.0, *) else { return }

        do {
            if preferences.launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Highlighter failed to sync launch at login: \(error.localizedDescription)")
        }
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
