import Foundation
import Combine
import Darwin

struct HostsEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var enabled: Bool = true
    var ip: String = ""
    var hostname: String = ""
}

@MainActor
final class HostsManager: ObservableObject {
    @Published var entries: [HostsEntry] = []
    @Published var isApplying: Bool = false
    @Published var isReloading: Bool = false
    @Published var lastError: String? = nil
    @Published var lastAppliedAt: Date? = nil

    nonisolated private static let appSupportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("uHosts", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    nonisolated private static var storeURL: URL { appSupportDir.appendingPathComponent("entries.json") }
    nonisolated private static var originalBackupURL: URL { appSupportDir.appendingPathComponent("hosts.backup-original") }

    init() {
        if FileManager.default.fileExists(atPath: Self.storeURL.path) {
            load()
        } else {
            // First launch: import whatever's in /etc/hosts so the user keeps their existing config.
            let raw = (try? String(contentsOfFile: "/etc/hosts", encoding: .utf8)) ?? ""
            entries = Self.parseHostsFile(raw)
            saveLocal()
        }
    }

    // MARK: – Local store

    func load() {
        guard let data = try? Data(contentsOf: Self.storeURL),
              let list = try? JSONDecoder().decode([HostsEntry].self, from: data) else { return }
        entries = list
    }

    func saveLocal() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: Self.storeURL, options: .atomic)
    }

    func addEmpty() {
        entries.append(HostsEntry())
        saveLocal()
    }

    func remove(_ entry: HostsEntry) {
        entries.removeAll { $0.id == entry.id }
        saveLocal()
    }

    // MARK: – Reload from /etc/hosts

    func reloadFromDisk() {
        isReloading = true
        lastError = nil
        let raw = (try? String(contentsOfFile: "/etc/hosts", encoding: .utf8)) ?? ""
        let parsed = Self.parseHostsFile(raw)
        entries = parsed
        saveLocal()
        isReloading = false
    }

    // MARK: – Apply (write /etc/hosts)

    func apply() {
        isApplying = true
        lastError = nil
        let snapshot = entries
        Task.detached(priority: .userInitiated) {
            do {
                try Self.writeHosts(entries: snapshot)
                await MainActor.run {
                    self.isApplying = false
                    self.lastAppliedAt = Date()
                }
            } catch {
                let msg = (error as NSError).localizedDescription
                await MainActor.run {
                    self.isApplying = false
                    self.lastError = msg
                }
            }
        }
    }

    nonisolated private static func writeHosts(entries: [HostsEntry]) throws {
        let currentRaw = (try? String(contentsOfFile: "/etc/hosts", encoding: .utf8)) ?? ""

        // One-time backup of the user's original /etc/hosts.
        if !FileManager.default.fileExists(atPath: originalBackupURL.path) {
            try? currentRaw.write(to: originalBackupURL, atomically: true, encoding: .utf8)
        }

        let newContent = renderFullHosts(entries: entries)

        // Skip the privileged write entirely if nothing changed — avoids a needless password prompt.
        if newContent == currentRaw {
            return
        }

        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("uhosts_\(UUID().uuidString).txt")
        try newContent.write(to: tmp, atomically: true, encoding: .utf8)

        let tmpPath = tmp.path
        let shell = "/bin/cp '\(tmpPath)' /etc/hosts && /bin/chmod 644 /etc/hosts && /bin/rm -f '\(tmpPath)' && /usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder"
        let escaped = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escaped)\" with administrator privileges"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", appleScript]
        let errPipe = Pipe()
        proc.standardError = errPipe
        proc.standardOutput = Pipe()
        try proc.run()
        proc.waitUntilExit()

        if proc.terminationStatus != 0 {
            let data = try? errPipe.fileHandleForReading.readToEnd()
            let raw = data.flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let msg = raw.isEmpty ? "Authorization cancelled or failed." : raw
            throw NSError(domain: "uHosts", code: Int(proc.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    // MARK: – Hosts-file format

    nonisolated static func renderFullHosts(entries: [HostsEntry]) -> String {
        var out = """
        ##
        # Host Database
        #
        # localhost is used to configure the loopback interface
        # when the system is booting.  Do not change this entry.
        ##
        127.0.0.1\tlocalhost
        255.255.255.255\tbroadcasthost
        ::1             localhost

        # Managed by uHosts

        """
        for e in entries {
            let ip = e.ip.trimmingCharacters(in: .whitespaces)
            let host = e.hostname.trimmingCharacters(in: .whitespaces)
            guard !ip.isEmpty, !host.isEmpty else { continue }
            let prefix = e.enabled ? "" : "# "
            out += "\(prefix)\(ip)\t\(host)\n"
        }
        return out
    }

    /// Parses a hosts-file string into entries. Accepts standard `IP HOST [HOST…]` lines,
    /// disabled entries (`# IP HOST`), and inline comments. Skips macOS default entries.
    nonisolated static func parseHostsFile(_ contents: String) -> [HostsEntry] {
        let defaults: Set<String> = ["localhost", "broadcasthost", "localhost.localdomain"]
        var entries: [HostsEntry] = []
        var seen = Set<String>()

        for rawLine in contents.components(separatedBy: .newlines) {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            var isEnabled = true
            if line.hasPrefix("#") {
                var stripped = line
                while stripped.hasPrefix("#") { stripped = String(stripped.dropFirst()) }
                stripped = stripped.trimmingCharacters(in: .whitespaces)
                guard looksLikeEntry(stripped) else { continue }
                isEnabled = false
                line = stripped
            }

            // Strip inline comment.
            if let hash = line.firstIndex(of: "#") {
                line = String(line[..<hash]).trimmingCharacters(in: .whitespaces)
            }

            let parts = line.split(whereSeparator: { $0.isWhitespace })
            guard parts.count >= 2 else { continue }
            let ip = String(parts[0])
            guard isValidIP(ip) else { continue }

            for hostPart in parts.dropFirst() {
                let host = String(hostPart)
                if defaults.contains(host.lowercased()) { continue }
                let key = "\(ip)|\(host)|\(isEnabled)"
                if seen.contains(key) { continue }
                seen.insert(key)
                entries.append(HostsEntry(enabled: isEnabled, ip: ip, hostname: host))
            }
        }
        return entries
    }

    nonisolated private static func looksLikeEntry(_ s: String) -> Bool {
        let parts = s.split(whereSeparator: { $0.isWhitespace })
        guard parts.count >= 2 else { return false }
        return isValidIP(String(parts[0]))
    }

    nonisolated private static func isValidIP(_ s: String) -> Bool {
        var v4 = in_addr()
        if s.withCString({ inet_pton(AF_INET, $0, &v4) }) == 1 { return true }
        var v6 = in6_addr()
        if s.withCString({ inet_pton(AF_INET6, $0, &v6) }) == 1 { return true }
        return false
    }
}
