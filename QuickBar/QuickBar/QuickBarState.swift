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
    var quarantineFileURL: URL?
    var forceEjectVolumes: [String] = []
    var isEjecting: Bool = false
    var memoryUsed: Double = 0
    var memoryTotal: Double = 0
    var memoryPurgeable: Double = 0
    var memoryUsagePercent: Double = 0
    var isShutdownScheduled: Bool = false
    var scheduledShutdownTime: Date?
    var shutdownPID: Int?
    var frontmostAppBundleID: String?
    var toolOrder: [QuickBarTool] = QuickBarTool.allCases
    var isDialogOpen: Bool = false

    enum ActionStatus {
        case idle, success, failure, inProgress
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
                parseBatteryInfo(output)
            }
        } catch {
            batteryHealth = "Error reading"
        }
    }

    func refreshEjectableVolumes() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        task.arguments = ["list", "-plist"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
               let allDisks = plist["AllDisksAndPartitions"] as? [[String: Any]] {
                forceEjectVolumes = allDisks.compactMap { disk -> String? in
                    guard let deviceNode = disk["DeviceIdentifier"] as? String,
                          let removable = disk["Removable"] as? Bool,
                          removable,
                          let content = disk["Content"] as? String,
                          content != "" else { return nil }
                    return deviceNode
                }
            }
        } catch {
            forceEjectVolumes = []
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
        let freePages = pages["Pages free"] ?? 0
        let activePages = pages["Pages active"] ?? 0
        let inactivePages = pages["Pages inactive"] ?? 0
        let speculativePages = pages["Pages speculative"] ?? 0
        let wiredPages = pages["Pages wired down"] ?? 0
        let purgeablePages = pages["Pages purgeable"] ?? 0
        
        let totalPages = freePages + activePages + inactivePages + speculativePages + wiredPages + purgeablePages
        
        memoryTotal = (totalPages * pageSize) / (1024 * 1024 * 1024)
        
        let active = activePages * pageSize
        let wired = wiredPages * pageSize
        let purgeable = purgeablePages * pageSize
        let inactive = inactivePages * pageSize
        
        memoryUsed = (active + wired) / (1024 * 1024 * 1024)
        memoryPurgeable = (inactive + purgeable) / (1024 * 1024 * 1024)
        memoryUsagePercent = (memoryUsed / memoryTotal) * 100
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
