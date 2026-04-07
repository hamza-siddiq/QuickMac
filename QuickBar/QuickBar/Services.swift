import Foundation
import SwiftUI
import AppKit

class QuickBarServices {
    static let shared = QuickBarServices()

    func runCommand(_ command: String, arguments: [String], adminPassword: String? = nil) -> Result<String, Error> {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: command)
        task.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        if let password = adminPassword {
            task.arguments = ["-S"] + (task.arguments ?? [])
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            
            let script = """
            do shell script "\(command) \(arguments.joined(separator: " "))" with administrator privileges password "\(password.replacingOccurrences(of: "\"", with: "\\\""))"
            """
            task.arguments = ["-e", script]
        }

        do {
            try task.run()
            task.waitUntilExit()

            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

            if task.terminationStatus == 0 {
                let output = String(data: outData, encoding: .utf8) ?? ""
                return .success(output)
            } else {
                let error = String(data: errData, encoding: .utf8) ?? "Unknown error"
                return .failure(NSError(domain: "QuickBar", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: error]))
            }
        } catch {
            return .failure(error)
        }
    }

    func runSudoCommand(_ command: String, adminPassword: String) -> Result<String, Error> {
        let script = """
        do shell script "\(command)" with administrator privileges password "\(adminPassword.replacingOccurrences(of: "\"", with: "\\\""))"
        """
        return runAppleScript(script)
    }

    func runAppleScript(_ script: String) -> Result<String, Error> {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        do {
            try task.run()
            task.waitUntilExit()

            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

            if task.terminationStatus == 0 {
                let output = String(data: outData, encoding: .utf8) ?? ""
                return .success(output)
            } else {
                let error = String(data: errData, encoding: .utf8) ?? "Unknown error"
                return .failure(NSError(domain: "QuickBar", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: error]))
            }
        } catch {
            return .failure(error)
        }
    }

    func quitAllApps() {
        let apps = NSWorkspace.shared.runningApplications.filter { app in
            guard let bundleID = app.bundleIdentifier else { return false }
            guard app.activationPolicy == .regular else { return false }
            let excluded = ["com.apple.finder", "com.apple.dock", Bundle.main.bundleIdentifier]
            return !excluded.contains(bundleID)
        }

        for app in apps {
            if !app.terminate() {
                app.forceTerminate()
            }
        }
    }

    func quitAllOtherApps(excludeBundleID: String? = nil) {
        var excludedIDs = ["com.apple.finder", "com.apple.dock", Bundle.main.bundleIdentifier]
        
        if let excludeID = excludeBundleID {
            excludedIDs.append(excludeID)
        }

        let apps = NSWorkspace.shared.runningApplications.filter { app in
            guard let bundleID = app.bundleIdentifier else { return false }
            guard app.activationPolicy == .regular else { return false }
            return !excludedIDs.contains(bundleID)
        }

        for app in apps {
            if !app.terminate() {
                app.forceTerminate()
            }
        }
    }

    func getRunningApps() -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular && app.localizedName != nil
        }
    }

    func forceQuitApp(_ app: NSRunningApplication) {
        if !app.terminate() {
            app.forceTerminate()
        }
    }

    func purgeMemory(adminPassword: String) -> Result<String, Error> {
        runSudoCommand("/usr/sbin/purge", adminPassword: adminPassword)
    }

    func toggleNoSleep(enabled: Bool, adminPassword: String) -> Result<String, Error> {
        let value = enabled ? "1" : "0"
        return runSudoCommand("/usr/bin/pmset disablesleep \(value)", adminPassword: adminPassword)
    }

    func removeQuarantine(from url: URL) -> Result<String, Error> {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        task.arguments = ["-d", "com.apple.quarantine", url.path]

        let errPipe = Pipe()
        task.standardError = errPipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                return .success("Quarantine removed")
            } else {
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Failed"
                return .failure(NSError(domain: "QuickBar", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: err]))
            }
        } catch {
            return .failure(error)
        }
    }

    func resetBluetooth(adminPassword: String) -> Result<String, Error> {
        runSudoCommand("/usr/bin/pkill -9 bluetoothd; /bin/sleep 2; /usr/sbin/systemsetup -setremotelogin on 2>/dev/null; echo 'Bluetooth reset'", adminPassword: adminPassword)
    }

    func findLargeFiles(in directories: [URL]) async -> [LargeFile] {
        var files: [LargeFile] = []
        let minSize: Int64 = 100 * 1024 * 1024

        for directory in directories {
            let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            while let item = enumerator?.nextObject() as? URL {
                do {
                    let values = try item.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                    if values.isDirectory == true { continue }
                    if let size = values.fileSize, size > minSize {
                        files.append(LargeFile(url: item, size: Int64(size)))
                    }
                } catch {
                    continue
                }
            }
        }

        return files.sorted { $0.size > $1.size }.prefix(50).map { $0 }
    }

    func forceEjectVolume(_ deviceNode: String) -> Result<String, Error> {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["unmountDisk", "force", "/dev/" + deviceNode]

        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        do {
            try task.run()
            task.waitUntilExit()

            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

            if task.terminationStatus == 0 {
                let output = String(data: outData, encoding: .utf8) ?? ""
                return .success(output)
            } else {
                let error = String(data: errData, encoding: .utf8) ?? "Failed to eject"
                return .failure(NSError(domain: "QuickBar", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: error]))
            }
        } catch {
            return .failure(error)
        }
    }

    func resetNetwork(adminPassword: String) -> Result<String, Error> {
        let commands = [
            "/usr/bin/dscacheutil -flushcache",
            "/usr/bin/killall -HUP mDNSResponder",
            "/usr/sbin/networksetup -setproxyautodiscovery Wi-Fi off"
        ].joined(separator: "; ")

        return runSudoCommand(commands, adminPassword: adminPassword)
    }

    func scheduledShutdown(date: Date, adminPassword: String) -> Result<Int, Error> {
        let interval = Int(date.timeIntervalSinceNow)
        guard interval > 0 else {
            return .failure(NSError(domain: "QuickBar", code: -1, userInfo: [NSLocalizedDescriptionKey: "Time must be in the future"]))
        }
        let seconds = interval
        let scriptPath = "/tmp/quickmac_shutdown.sh"
        let script = "#!/bin/bash\nsleep \(seconds)\n/sbin/shutdown -h now\n"
        
        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            let command = "chmod +x \(scriptPath) && nohup \(scriptPath) > /dev/null 2>&1 & echo $!"
            let result = runSudoCommand(command, adminPassword: adminPassword)
            
            switch result {
            case .success(let output):
                let pidStr = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if let pid = Int(pidStr) {
                    return .success(pid)
                } else {
                    return .failure(NSError(domain: "QuickBar", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to capture shutdown PID"]))
                }
            case .failure(let error):
                return .failure(error)
            }
        } catch {
            return .failure(error)
        }
    }

    func cancelScheduledShutdown(pid: Int, adminPassword: String) -> Result<String, Error> {
        runSudoCommand("kill -9 \(pid) 2>/dev/null; rm -f /tmp/quickmac_shutdown.sh /tmp/quickmac_shutdown.pid; exit 0", adminPassword: adminPassword)
    }

    func getGroupedProcesses() -> [ProcessGroup] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-ax", "-o", "pid,args,%cpu,%mem,stat"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return buildProcessGroups(parseProcessList(output))
            }
        } catch {
            return []
        }
        return []
    }

    private func buildProcessGroups(_ processes: [ProcessInfo]) -> [ProcessGroup] {
        var groups: [String: ProcessGroup] = [:]

        for process in processes {
            let key = process.normalizedKey
            guard let relevant = filterProcess(process) else { continue }

            if let existing = groups[key] {
                groups[key] = ProcessGroup(
                    name: existing.name,
                    description: existing.description,
                    category: existing.category,
                    pids: existing.pids + [process.pid],
                    count: existing.count + 1,
                    totalCPU: existing.totalCPU + process.cpu,
                    totalMemory: existing.totalMemory + process.memory
                )
            } else {
                groups[key] = ProcessGroup(
                    name: relevant.displayName,
                    description: relevant.description,
                    category: relevant.category,
                    pids: [process.pid],
                    count: 1,
                    totalCPU: process.cpu,
                    totalMemory: process.memory
                )
            }
        }

        return groups.values.sorted { a, b in
            if a.totalCPU != b.totalCPU { return a.totalCPU > b.totalCPU }
            return a.totalMemory > b.totalMemory
        }
    }

    private func filterProcess(_ process: ProcessInfo) -> ProcessInfo? {
        let cmd = process.command
        let lowerCmd = cmd.lowercased()

        // Skip kernel threads and very short commands
        if cmd.hasPrefix("[") || cmd.count < 3 { return nil }

        // Skip ps itself and QuickBar
        if cmd.contains("QuickBar") || lowerCmd.contains("/bin/ps") { return nil }

        // Skip all macOS system processes
        let systemPaths = [
            "/System/",
            "/usr/",
            "/usr/libexec/",
            "/usr/sbin/",
            "/usr/bin/",
            "/Library/Apple/",
            "/sbin/",
            "/bin/"
        ]
        for path in systemPaths {
            if cmd.hasPrefix(path) { return nil }
        }

        // Skip Apple system daemons and agents
        if lowerCmd.contains("com.apple.") && !cmd.contains("/Applications/") && !cmd.contains("/Users/") {
            return nil
        }

        // Skip known critical system processes by name
        let criticalProcesses = [
            "launchd", "kernel", "kernel_task", "kextd", "fseventsd",
            "sysmond", "logd", "reportcrash", "coresymbolicationd",
            "dyld", "sandboxd", "securityd", "trustd", "taskgated",
            "diskarbitrationd", "appleeventsd", "coreservicesd",
            "useractivityd", "sharingd", "rapportd", "bluetoothd",
            "WindowServer", "loginwindow", "CoreServicesUIAgent",
            "hidd", "coreaudiod", "audio", "powerd", "thermald",
            "configd", "networkd", "airportd", "mDNSResponder",
            "syslogd", "distnoted", "cfprefsd", "xpc",
            "mds", "mdworker", "mds_stores",
            "tccd", "usernoted", "contextstored",
            "cloudd", "bird", "nsurlsessiond", "nsurlstoraged",
            "softwareupdated", "storeagent", "storedownloadd",
            "apsd", "imagent", "identityservicesd",
            "corelocationd", "locationd", "corebrightnessd",
            "displaypolicyd", "AirPlayXPHelper",
            "pboard", "iconservicesagent", "fileproviderd",
            "backupd", "timemachine", "cupsd", "cups"
        ]
        let processName = URL(fileURLWithPath: cmd).lastPathComponent.lowercased()
        for critical in criticalProcesses {
            if processName == critical.lowercased() { return nil }
        }

        // Only include user-facing processes
        if cmd.contains("/Applications/") || cmd.contains("/Users/") || cmd.contains("/Library/") {
            return ProcessInfo(
                pid: process.pid,
                command: cmd,
                cpu: process.cpu,
                memory: process.memory,
                state: process.state,
                displayName: extractAppName(cmd),
                description: describeProcess(cmd),
                category: categorizeProcess(cmd)
            )
        }

        // Include processes with significant resource usage that aren't system processes
        if process.cpu > 5.0 || process.memory > 2.0 {
            return ProcessInfo(
                pid: process.pid,
                command: cmd,
                cpu: process.cpu,
                memory: process.memory,
                state: process.state,
                displayName: extractAppName(cmd),
                description: describeProcess(cmd),
                category: categorizeProcess(cmd)
            )
        }

        return nil
    }

    private func extractAppName(_ command: String) -> String {
        let url = URL(fileURLWithPath: command)
        var name = url.lastPathComponent

        // Remove common prefixes
        if name.hasPrefix("com.apple.") {
            name = String(name.dropFirst("com.apple.".count))
        }

        // Convert camelCase or dot.separated to readable
        name = name.replacingOccurrences(of: ".", with: " ")
        name = name.replacingOccurrences(of: "-", with: " ")
        name = name.replacingOccurrences(of: "_", with: " ")

        // Capitalize first letter of each word
        name = name.capitalized

        return name
    }

    private func describeProcess(_ command: String) -> String {
        let lowerCmd = command.lowercased()

        let descriptions: [String: String] = [
            "bluetoothd": "Manages Bluetooth connections",
            "WindowServer": "Renders windows and graphics",
            "coreaudiod": "Handles audio output and input",
            "hidd": "Human Interface Device daemon",
            "ControlCenter": "Menu bar control center",
            "NotificationCenter": "Notification center service",
            "Dock": "Dock and desktop management",
            "Finder": "File manager and desktop",
            "loginwindow": "Login and session manager",
            "mds": "Spotlight metadata server",
            "mdworker": "Spotlight file indexer",
            "cloudd": "iCloud sync service",
            "bird": "iCloud file sync daemon",
            "nsurlsessiond": "Network session manager",
            "mDNSResponder": "DNS and Bonjour service",
            "softwareupdated": "Software update service",
            "powerd": "Power management daemon",
            "thermald": "Thermal management",
            "configd": "System configuration daemon",
            "networkd": "Network management daemon",
            "airportd": "Wi-Fi management daemon",
            "sharingd": "File and screen sharing",
            "rapportd": "Continuity and Handoff",
            "apsd": "Apple Push Notification service",
            "tccd": "Privacy and permissions service",
            "syslogd": "System logging daemon",
            "launchd": "System launch daemon",
            "distnoted": "Distributed notifications",
            "cfprefsd": "Preferences caching daemon",
            "usernoted": "User notification service",
            "corelocationd": "Location services daemon",
            "identityservicesd": "Identity and accounts",
            "imagent": "Messages and FaceTime agent",
            "contextstored": "Context store service",
            "displaypolicyd": "Display management",
            "corebrightnessd": "Display brightness control",
            "backupd": "Time Machine backup daemon",
            "diskarbitrationd": "Disk mount management",
            "cupsd": "Print service daemon",
            "iconservicesagent": "App icon cache service",
            "fileproviderd": "File provider service",
            "nsurlstoraged": "URL cache and storage",
            "pboard": "Pasteboard service",
            "xpcroleaccountd": "XPC role account daemon",
            "bluetoothuseragent": "Bluetooth user agent",
            "AirPlayXPCHelper": "AirPlay helper service",
            "storeagent": "App Store agent",
            "com.apple.WebKit": "WebKit web engine"
        ]

        for (key, desc) in descriptions {
            if lowerCmd.contains(key.lowercased()) {
                return desc
            }
        }

        if command.contains("/Applications/") {
            return "User application"
        }

        if command.contains("/Users/") {
            return "User process"
        }

        if command.contains("/System/") {
            return "System service"
        }

        if command.contains("/usr/") {
            return "Unix utility"
        }

        return "Background process"
    }

    private func categorizeProcess(_ command: String) -> ProcessCategory {
        let lowerCmd = command.lowercased()

        if command.contains("/Applications/") { return .app }
        if command.contains("/Users/") { return .user }
        if lowerCmd.contains("bluetooth") { return .bluetooth }
        if lowerCmd.contains("network") || lowerCmd.contains("wifi") || lowerCmd.contains("dns") || lowerCmd.contains("mdns") { return .network }
        if lowerCmd.contains("audio") || lowerCmd.contains("sound") || lowerCmd.contains("coreaudio") { return .audio }
        if lowerCmd.contains("cloud") || lowerCmd.contains("icloud") || lowerCmd.contains("sync") || lowerCmd.contains("bird") { return .cloud }
        if lowerCmd.contains("security") || lowerCmd.contains("auth") || lowerCmd.contains("keychain") || lowerCmd.contains("tccd") { return .security }
        if lowerCmd.contains("power") || lowerCmd.contains("thermal") || lowerCmd.contains("battery") { return .power }
        if lowerCmd.contains("display") || lowerCmd.contains("window") || lowerCmd.contains("graphics") { return .display }
        if lowerCmd.contains("print") || lowerCmd.contains("cups") { return .print }
        if lowerCmd.contains("spotlight") || lowerCmd.contains("mds") || lowerCmd.contains("mdworker") { return .search }
        if lowerCmd.contains("notification") || lowerCmd.contains("apsd") { return .notification }
        if lowerCmd.contains("time") || lowerCmd.contains("backup") { return .backup }
        if lowerCmd.contains("update") || lowerCmd.contains("software") || lowerCmd.contains("store") { return .update }

        return .system
    }

    private func parseProcessList(_ output: String) -> [ProcessInfo] {
        let lines = output.components(separatedBy: .newlines)
        var processes: [ProcessInfo] = []

        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 4).map(String.init)
            guard parts.count >= 2, let pid = Int(parts[0]) else { continue }

            let command = parts.count > 1 ? parts[1] : ""
            let cpu = parts.count > 2 ? Double(parts[2]) ?? 0 : 0
            let mem = parts.count > 3 ? Double(parts[3]) ?? 0 : 0
            let state = parts.count > 4 ? parts[4] : ""

            processes.append(ProcessInfo(
                pid: pid,
                command: command,
                cpu: cpu,
                memory: mem,
                state: state,
                displayName: extractAppName(command),
                description: describeProcess(command),
                category: categorizeProcess(command)
            ))
        }

        return processes
    }

    func killProcess(pid: Int) -> Result<String, Error> {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/kill")
        task.arguments = ["-9", "\(pid)"]

        let errPipe = Pipe()
        task.standardError = errPipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                return .success("Process \(pid) killed")
            } else {
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Failed"
                return .failure(NSError(domain: "QuickBar", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: err]))
            }
        } catch {
            return .failure(error)
        }
    }
}

struct ProcessInfo: Identifiable {
    let id = UUID()
    let pid: Int
    let command: String
    let cpu: Double
    let memory: Double
    let state: String
    let displayName: String
    let description: String
    let category: ProcessCategory

    var normalizedKey: String {
        let url = URL(fileURLWithPath: command)
        return url.lastPathComponent.lowercased()
    }
}

struct ProcessGroup: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let category: ProcessCategory
    let pids: [Int]
    let count: Int
    let totalCPU: Double
    let totalMemory: Double
}

enum ProcessCategory: String {
    case app, user, bluetooth, network, audio, cloud, security, power, display, print, search, notification, backup, update, system

    var icon: String {
        switch self {
        case .app: "app.fill"
        case .user: "person.fill"
        case .bluetooth: "antenna.radiowaves.left.and.right"
        case .network: "network"
        case .audio: "speaker.wave.2.fill"
        case .cloud: "cloud.fill"
        case .security: "lock.shield.fill"
        case .power: "bolt.fill"
        case .display: "display"
        case .print: "printer.fill"
        case .search: "magnifyingglass"
        case .notification: "bell.fill"
        case .backup: "externaldrive.fill.badge.timemachine"
        case .update: "arrow.triangle.2.circlepath"
        case .system: "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .app: .blue
        case .user: .purple
        case .bluetooth: .cyan
        case .network: .teal
        case .audio: .orange
        case .cloud: .indigo
        case .security: .red
        case .power: .yellow
        case .display: .green
        case .print: .gray
        case .search: .mint
        case .notification: .pink
        case .backup: .brown
        case .update: .cyan
        case .system: .secondary
        }
    }
}
