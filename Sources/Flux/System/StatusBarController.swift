import AppKit
import Combine
import SwiftUI

/// AppKit owns the status item so its title can contain multiple SF Symbol
/// attachments. SwiftUI's `MenuBarExtra` label keeps only one image/title pair.
@MainActor
final class StatusBarController: NSObject, ObservableObject {
    private let statusFontSize = NSFont.systemFontSize
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
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
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 258, height: 263)
        popover.contentViewController = NSHostingController(rootView: menu)

        latestCancellable = metrics.$latest.sink { [weak self] snapshot in
            self?.updateStatusItem(with: snapshot)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func openDashboard() {
        popover.performClose(nil)
        guard let window = NSApp.windows.first(where: { $0.title == "Flux Dashboard" }) else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
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
        let configuration = NSImage.SymbolConfiguration(pointSize: statusFontSize, weight: .medium)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)?
            .withSymbolConfiguration(configuration)
        image?.isTemplate = true

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(x: 0, y: -3, width: 15, height: 15)
        return NSAttributedString(attachment: attachment)
    }

    private func value(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: statusFontSize, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }
}
