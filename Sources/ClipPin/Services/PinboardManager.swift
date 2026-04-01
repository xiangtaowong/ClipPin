import AppKit
import Foundation

final class PinboardManager {
    private let historyStore: HistoryStore
    private let appearanceStore: PinAppearanceStore
    private var pinnedControllers: [UUID: NSWindowController] = [:]

    init(historyStore: HistoryStore, appearanceStore: PinAppearanceStore) {
        self.historyStore = historyStore
        self.appearanceStore = appearanceStore
    }

    func pin(item: ClipItem) {
        switch item.kind {
        case .text:
            guard let text = item.text else { return }
            let controller = PinnedTextPanelController(text: text)
            addPinnedController(controller)
        case .image:
            guard let image = historyStore.image(for: item)?.copy() as? NSImage else { return }
            let controller = PinnedImagePanelController(image: image)
            addPinnedController(controller)
        }
    }

    private func addPinnedController(_ controller: NSWindowController) {
        let id = UUID()
        pinnedControllers[id] = controller

        if let textController = controller as? PinnedTextPanelController {
            textController.onClose = { [weak self] in
                self?.pinnedControllers.removeValue(forKey: id)
            }
        }

        if let imageController = controller as? PinnedImagePanelController {
            imageController.onClose = { [weak self] in
                self?.pinnedControllers.removeValue(forKey: id)
            }
        }

        if let appearanceConfigurable = controller as? PinAppearanceConfigurable {
            appearanceConfigurable.applyAppearance(settings: appearanceStore.settings)
        }

        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.center()
        controller.window?.orderFrontRegardless()
        controller.window?.makeKeyAndOrderFront(nil)
    }
}
