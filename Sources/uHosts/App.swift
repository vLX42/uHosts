import AppKit
import SwiftUI

@main
struct UHostsApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        _ = delegate // retain
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let manager = HostsManager()
    private let launch = LaunchAtLogin.shared
    private var editWindowController: NSWindowController?

    // MARK: – Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "network", accessibilityDescription: "uHosts")
            image?.isTemplate = true
            button.image = image
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: – Menu construction

    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            rebuild(menu: menu)
        }
    }

    private func rebuild(menu: NSMenu) {
        menu.removeAllItems()

        // Header
        let header = NSMenuItem()
        header.title = manager.entries.isEmpty
            ? "uHosts"
            : "uHosts — \(manager.entries.count) entr\(manager.entries.count == 1 ? "y" : "ies")"
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        // Entries
        if manager.entries.isEmpty {
            let empty = NSMenuItem(title: "No entries", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for (index, entry) in manager.entries.enumerated() {
                let hostname = entry.hostname.isEmpty ? "(empty hostname)" : entry.hostname
                let item = NSMenuItem(
                    title: hostname,
                    action: #selector(toggleEntry(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.tag = index
                item.state = entry.enabled ? .on : .off
                item.toolTip = "\(entry.ip)  →  \(entry.hostname)"
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())

        // Actions
        let apply = NSMenuItem(title: "Apply Changes", action: #selector(applyChanges), keyEquivalent: "s")
        apply.target = self
        apply.keyEquivalentModifierMask = [.command]
        if manager.isApplying { apply.title = "Applying…"; apply.isEnabled = false }
        menu.addItem(apply)

        let reload = NSMenuItem(title: "Reload from /etc/hosts", action: #selector(reloadFromDisk), keyEquivalent: "r")
        reload.target = self
        reload.keyEquivalentModifierMask = [.command]
        menu.addItem(reload)

        menu.addItem(.separator())

        let edit = NSMenuItem(title: "Edit Hosts…", action: #selector(openEditWindow), keyEquivalent: ",")
        edit.target = self
        edit.keyEquivalentModifierMask = [.command]
        menu.addItem(edit)

        let addItem = NSMenuItem(title: "Add Entry…", action: #selector(addAndEdit), keyEquivalent: "n")
        addItem.target = self
        addItem.keyEquivalentModifierMask = [.command]
        menu.addItem(addItem)

        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = launch.isEnabled ? .on : .off
        menu.addItem(loginItem)

        let about = NSMenuItem(title: "About uHosts", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit uHosts", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    // MARK: – Actions

    @objc private func toggleEntry(_ sender: NSMenuItem) {
        let index = sender.tag
        guard manager.entries.indices.contains(index) else { return }
        manager.entries[index].enabled.toggle()
        manager.saveLocal()
    }

    @objc private func applyChanges() {
        let onErrorBefore = manager.lastError
        manager.apply()
        // The actual apply is async; if it fails the manager.lastError will populate.
        // Surface failures via an alert after the work completes.
        Task { @MainActor in
            // Poll briefly until isApplying is false (or timeout).
            for _ in 0..<60 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                if !manager.isApplying { break }
            }
            if let err = manager.lastError, err != onErrorBefore {
                let alert = NSAlert()
                alert.messageText = "Couldn't write /etc/hosts"
                alert.informativeText = err
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        }
    }

    @objc private func reloadFromDisk() {
        manager.reloadFromDisk()
    }

    @objc private func toggleLaunchAtLogin() {
        launch.setEnabled(!launch.isEnabled)
        if let err = launch.lastError {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Login Item"
            alert.informativeText = err
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let info: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "uHosts",
            .credits: NSAttributedString(
                string: "A minimal /etc/hosts editor for Apple Silicon.\n\nhttps://github.com/vLX42/uHosts",
                attributes: [.foregroundColor: NSColor.labelColor]
            )
        ]
        NSApp.orderFrontStandardAboutPanel(options: info)
    }

    @objc private func openEditWindow() {
        showEditWindow()
    }

    @objc private func addAndEdit() {
        manager.addEmpty()
        showEditWindow()
    }

    private func showEditWindow() {
        if editWindowController == nil {
            let root = EditView()
                .environmentObject(manager)
                .environmentObject(launch)
            let hosting = NSHostingController(rootView: root)
            let window = NSWindow(contentViewController: hosting)
            window.title = "uHosts"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 480, height: 380))
            window.minSize = NSSize(width: 380, height: 240)
            window.isReleasedWhenClosed = false
            window.center()
            editWindowController = NSWindowController(window: window)
        }
        NSApp.activate(ignoringOtherApps: true)
        editWindowController?.showWindow(nil)
        editWindowController?.window?.makeKeyAndOrderFront(nil)
    }
}
