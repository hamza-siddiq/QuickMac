import Foundation
import AppKit
import Observation
import SwiftUI

@Observable
class QuickBarState {
    var runningAppCount: Int = 0
    var isNoSleepEnabled: Bool = false
    var batteryHealth: String = "Unknown"
    var batteryCycleCount: Int = 0
    var isRefreshing: Bool = false
    var adminPassword: String?
    var lastAction: String?
    var lastActionStatus: ActionStatus = .idle
    var largeFiles: [LargeFile] = []
    var isScanningFiles: Bool = false
    var memoryUsed: Double = 0
    var memoryTotal: Double = 0
    var memoryPurgeable: Double = 0
    var memoryUsagePercent: Double = 0
    var frontmostAppBundleID: String?
    var toolOrder: [QuickBarTool] = QuickBarTool.allCases
    var isDialogOpen: Bool = false

    // Disk info
    var diskUsed: Double = 0
    var diskTotal: Double = 0
    var diskPercent: Double = 0

    // Scheduled shutdown
    var isShutdownScheduled: Bool = false
    var scheduledShutdownTime: Date?
    var shutdownPID: Int?

    // Dark mode
    var isDarkMode: Bool = false

    enum ActionStatus {
        case idle, success, failure, inProgress
    }

    init() {
        if let saved = UserDefaults.standard.stringArray(forKey: "toolOrder") {
            let restored = saved.compactMap { QuickBarTool(rawValue: $0) }
            if restored.count == QuickBarTool.allCases.count {
                toolOrder = restored
            }
        }
    }

    func saveToolOrder() {
        UserDefaults.standard.set(toolOrder.map { $0.rawValue }, forKey: "toolOrder")
    }

    func setStatus(_ status: ActionStatus, message: String, autoClearAfter seconds: Double = 3.0) {
        lastActionStatus = status
        lastAction = message
        if status == .success || status == .failure {
            let currentMessage = message
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
                guard let self, self.lastAction == currentMessage else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    self.lastActionStatus = .idle
                    self.lastAction = nil
                }
            }
        }
    }

    func refreshAppCount() {
        let apps = NSWorkspace.shared.runningApplications
        let excluded = ["com.apple.finder", "com.apple.dock", Bundle.main.bundleIdentifier]
        runningAppCount = apps.filter { app in
            guard app.activationPolicy == .regular else { return false }
            guard let bundleID = app.bundleIdentifier else { return false }
            return !excluded.contains(bundleID)
        }.count
    }

    func refreshBatteryInfo() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            task.arguments = ["SPPowerDataType"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.parseBatteryInfo(output)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.batteryHealth = "Error reading"
                }
            }
        }
    }

    func refreshMemoryInfo() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/vm_stat")

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                parseMemoryInfo(output)
            }
        } catch {
            memoryUsed = 0
            memoryTotal = 0
            memoryPurgeable = 0
            memoryUsagePercent = 0
        }
    }

    func refreshDiskInfo() {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
            if let totalSize = attrs[.systemSize] as? Int64,
               let freeSize = attrs[.systemFreeSize] as? Int64 {
                diskTotal = Double(totalSize) / (1024 * 1024 * 1024)
                let used = totalSize - freeSize
                diskUsed = Double(used) / (1024 * 1024 * 1024)
                diskPercent = diskTotal > 0 ? (diskUsed / diskTotal) * 100 : 0
            }
        } catch {
            diskUsed = 0
            diskTotal = 0
            diskPercent = 0
        }
    }

    func refreshDarkMode() {
        let result = QuickBarServices.shared.runAppleScript(
            "tell application \"System Events\" to get dark mode of appearance preferences"
        )
        if case .success(let output) = result {
            isDarkMode = output.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        }
    }

    private func parseMemoryInfo(_ output: String) {
        let lines = output.components(separatedBy: .newlines)
        var pages: [String: Double] = [:]

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
            let valueStr = parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: "")

            if let value = Double(valueStr) {
                pages[key] = value
            }
        }

        let pageSize: Double = 4096
        let activePages = pages["Pages active"] ?? 0
        let wiredPages = pages["Pages wired down"] ?? 0
        let compressedPages = pages["Pages occupied by compressor"] ?? 0
        let inactivePages = pages["Pages inactive"] ?? 0
        let purgeablePages = pages["Pages purgeable"] ?? 0

        // Use the definitive API for total physical memory
        memoryTotal = Double(Foundation.ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)

        let active = activePages * pageSize
        let wired = wiredPages * pageSize
        let compressed = compressedPages * pageSize

        memoryUsed = (active + wired + compressed) / (1024 * 1024 * 1024)
        memoryPurgeable = (inactivePages + purgeablePages) * pageSize / (1024 * 1024 * 1024)
        memoryUsagePercent = memoryTotal > 0 ? (memoryUsed / memoryTotal) * 100 : 0
    }

    private func parseBatteryInfo(_ output: String) {
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("Cycle Count") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1, let count = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                    batteryCycleCount = count
                }
            }
            if trimmed.contains("Condition") {
                let parts = trimmed.components(separatedBy: ":")
                if parts.count > 1 {
                    batteryHealth = parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
    }
}

struct LargeFile: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64

    var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    var name: String {
        url.lastPathComponent
    }
}
