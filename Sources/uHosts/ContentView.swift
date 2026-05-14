import SwiftUI

struct ContentView: View {
    @StateObject private var manager = HostsManager()
    @StateObject private var launch = LaunchAtLogin.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 440)
    }

    // MARK: – Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "network").foregroundStyle(.tint)
            Text("uHosts").font(.headline)
            Text("\(manager.entries.count)")
                .font(.caption.monospacedDigit())
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(.gray.opacity(0.2), in: Capsule())
                .help("Total entries")

            Spacer()

            Button {
                manager.reloadFromDisk()
            } label: {
                if manager.isReloading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .buttonStyle(.borderless)
            .help("Reload from /etc/hosts (replaces current edits)")
            .disabled(manager.isReloading)

            Menu {
                Toggle("Launch at login", isOn: Binding(
                    get: { launch.isEnabled },
                    set: { launch.setEnabled($0) }
                ))

                if let err = launch.lastError {
                    Text("Login-item error: \(err)")
                }

                Divider()

                Button("About uHosts") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel(nil)
                }

                Divider()

                Button("Quit uHosts") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: – List

    private var content: some View {
        ScrollView {
            VStack(spacing: 4) {
                if manager.entries.isEmpty {
                    Text("No entries.\nClick + to add one, or ↻ to reload from /etc/hosts.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 28)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach($manager.entries) { $entry in
                        EntryRow(entry: $entry) {
                            manager.remove(entry)
                        }
                        .onChange(of: entry) { _, _ in manager.saveLocal() }
                    }
                }
            }
            .padding(8)
        }
        .frame(minHeight: 140, maxHeight: 380)
    }

    // MARK: – Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                manager.addEmpty()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Add entry")

            if let err = manager.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .truncationMode(.middle)
            } else if let when = manager.lastAppliedAt {
                Text("Applied \(when.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                manager.apply()
            } label: {
                if manager.isApplying {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Apply")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(manager.isApplying)
            .keyboardShortcut(.return, modifiers: [.command])
            .help("Write changes to /etc/hosts (⌘↩)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct EntryRow: View {
    @Binding var entry: HostsEntry
    let onDelete: () -> Void
    @State private var hovering: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $entry.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 1) {
                TextField("hostname.example.com", text: $entry.hostname)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .disableAutocorrection(true)
                TextField("127.0.0.1", text: $entry.ip)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .disableAutocorrection(true)
            }

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(hovering ? .red : .secondary)
            }
            .buttonStyle(.borderless)
            .opacity(hovering ? 1.0 : 0.5)
            .help("Delete")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.gray.opacity(hovering ? 0.14 : 0.08))
        )
        .opacity(entry.enabled ? 1.0 : 0.5)
        .onHover { hovering = $0 }
    }
}
