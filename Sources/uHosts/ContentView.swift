import SwiftUI

struct EditView: View {
    @EnvironmentObject private var manager: HostsManager

    var body: some View {
        VStack(spacing: 0) {
            content
            Divider()
            footer
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 6) {
                if manager.entries.isEmpty {
                    Text("No entries.\nClick + to add one, or Reload to import from /etc/hosts.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 40)
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
            .padding(12)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                manager.addEmpty()
            } label: {
                Image(systemName: "plus")
            }
            .help("Add entry")

            Button {
                manager.reloadFromDisk()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Reload from /etc/hosts")
            .disabled(manager.isReloading)

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
        }
        .padding(12)
    }
}

struct EntryRow: View {
    @Binding var entry: HostsEntry
    let onDelete: () -> Void
    @State private var hovering = false

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
