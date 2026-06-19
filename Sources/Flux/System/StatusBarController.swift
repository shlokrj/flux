import AppKit
import Combine
import SwiftUI

/// AppKit owns the status item so its title can contain multiple SF Symbol
/// attachments. SwiftUI's `MenuBarExtra` label keeps only one image/title pair.
@MainActor
final class StatusBarController: NSObject, ObservableObject, NSWindowDelegate {
    private let statusFontSize = NSFont.systemFontSize
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var menuPanel: NSPanel?
    private var dashboardWindow: NSWindow?
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var latestCancellable: AnyCancellable?
    private var isConfigured = false

    func configure(
        metrics: MetricsCollector,
        processes: ProcessCollector,
        history: HistoryStore,
        usage: AppUsageTracker,
        timeline: TimelineEngine
    ) {
        guard !isConfigured else { return }
        isConfigured = true

        timeline.attach(history)
        usage.start(recording: history)
        processes.start()
        metrics.attachSources(processes: processes, usage: usage)
        metrics.start(recording: history, timeline: timeline)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp])
        }

        let menu = MenuBarView(
            metrics: metrics,
            processes: processes,
            usage: usage,
            openDashboard: { [weak self] in self?.openDashboard() }
        )
        configureMenuPanel(with: menu)

        // The dashboard task configures this controller, so its NSWindow is in
        // the application window list on the next run-loop turn.
        DispatchQueue.main.async { [weak self] in
            self?.captureDashboardWindow()
        }

        latestCancellable = metrics.$latest.sink { [weak self] snapshot in
            self?.updateStatusItem(with: snapshot)
        }
    }

    @objc private func togglePopover() {
        guard let panel = menuPanel else { return }
        if panel.isVisible {
            closeMenuPanel()
        } else {
            showMenuPanel(panel)
        }
    }

    private func openDashboard() {
        closeMenuPanel()
        if dashboardWindow == nil {
            captureDashboardWindow()
        }
        guard let window = dashboardWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender === dashboardWindow else { return true }
        sender.orderOut(nil)
        return false
    }

    @objc private func hideDashboard(_ sender: Any?) {
        dashboardWindow?.orderOut(nil)
    }

    private func captureDashboardWindow() {
        let dashboards = NSApp.windows.filter { $0.title == "Flux Dashboard" }
        guard let primary = dashboards.first(where: { $0.isKeyWindow }) ?? dashboards.first else { return }

        dashboardWindow = primary
        primary.delegate = self
        primary.isReleasedWhenClosed = false
        if let closeButton = primary.standardWindowButton(.closeButton) {
            closeButton.target = self
            closeButton.action = #selector(hideDashboard(_:))
        }

        // Clean up any duplicates created before the singleton behavior was
        // installed. Future duplicates are prevented by the app command set.
        for duplicate in dashboards where duplicate !== primary {
            duplicate.orderOut(nil)
            duplicate.close()
        }
    }

    private func configureMenuPanel(with menu: MenuBarView) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 258, height: 263),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = NSHostingController(rootView: menu)
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        menuPanel = panel
    }

    private func showMenuPanel(_ panel: NSPanel) {
        guard let button = statusItem.button, let statusWindow = button.window else { return }

        let buttonRect = statusWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let panelSize = panel.frame.size
        let visibleFrame = statusWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let unclampedX = buttonRect.midX - panelSize.width / 2
        let x = min(max(unclampedX, visibleFrame.minX + 8), visibleFrame.maxX - panelSize.width - 8)
        let y = buttonRect.minY - panelSize.height - 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.closeMenuPanel() }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            let statusWindow = self.statusItem.button?.window
            if event.window !== self.menuPanel, event.window !== statusWindow {
                self.closeMenuPanel()
            }
            return event
        }
    }

    private func closeMenuPanel() {
        menuPanel?.orderOut(nil)
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }
    }

    private func updateStatusItem(with snapshot: SystemSnapshot?) {
        guard let button = statusItem.button else { return }

        let title = NSMutableAttributedString()
        title.append(symbol("cpu", description: "CPU"))
        title.append(value(" \(snapshot?.cpuPercentText ?? "—")   "))
        title.append(symbol("memorychip", description: "Memory"))
        title.append(value(" \(snapshot?.memoryPercentText ?? "—")"))

        button.attributedTitle = title
        button.toolTip = "CPU \(snapshot?.cpuPercentText ?? "unavailable"), memory \(snapshot?.memoryPercentText ?? "unavailable")"
        button.setAccessibilityLabel(button.toolTip)
    }

    private func symbol(_ name: String, description: String) -> NSAttributedString {
        let configuration = NSImage.SymbolConfiguration(pointSize: statusFontSize, weight: .regular)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(x: 0, y: -2, width: 14, height: 14)
        return NSAttributedString(attachment: attachment)
    }

    private func value(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.menuBarFont(ofSize: 0),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }
}
