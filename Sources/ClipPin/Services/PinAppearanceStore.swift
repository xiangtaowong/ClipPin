import CoreGraphics
import Foundation

struct PinAppearanceSettings {
    var windowShadowEnabled: Bool
    var defaultOpacity: CGFloat

    static let `default` = PinAppearanceSettings(
        windowShadowEnabled: true,
        defaultOpacity: 0.6
    )
}

protocol PinAppearanceConfigurable: AnyObject {
    func applyAppearance(settings: PinAppearanceSettings)
}

final class PinAppearanceStore {
    private enum Keys {
        static let windowShadowEnabled = "pinAppearance.windowShadowEnabled"
        static let defaultOpacity = "pinAppearance.defaultOpacity"
    }

    private let userDefaults: UserDefaults
    private(set) var settings: PinAppearanceSettings

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if userDefaults.object(forKey: Keys.windowShadowEnabled) == nil,
           userDefaults.object(forKey: Keys.defaultOpacity) == nil {
            self.settings = .default
            persist()
            return
        }

        let savedShadow = userDefaults.object(forKey: Keys.windowShadowEnabled) as? Bool
            ?? PinAppearanceSettings.default.windowShadowEnabled
        let savedOpacity = userDefaults.object(forKey: Keys.defaultOpacity) as? Double
            ?? Double(PinAppearanceSettings.default.defaultOpacity)

        self.settings = PinAppearanceSettings(
            windowShadowEnabled: savedShadow,
            defaultOpacity: CGFloat(savedOpacity).clamped(to: 0.2...1.0)
        )
    }

    func setWindowShadowEnabled(_ enabled: Bool) {
        settings.windowShadowEnabled = enabled
        persist()
    }

    func setDefaultOpacity(_ opacity: CGFloat) {
        settings.defaultOpacity = opacity.clamped(to: 0.2...1.0)
        persist()
    }

    private func persist() {
        userDefaults.set(settings.windowShadowEnabled, forKey: Keys.windowShadowEnabled)
        userDefaults.set(Double(settings.defaultOpacity), forKey: Keys.defaultOpacity)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
