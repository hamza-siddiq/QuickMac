import Foundation
import SwiftUI

enum QuickBarTool: String, CaseIterable, Identifiable {
    case quitAllApps = "quit_all"
    case killFrozenApp = "kill_frozen"
    case purgeMemory = "purge_memory"
    case processMonitor = "process_monitor"
    case noSleep = "no_sleep"
    case findLargeFiles = "find_large_files"
    case batteryHealth = "battery_health"
    case scheduledShutdown = "scheduled_shutdown"
    case toggleDarkMode = "toggle_dark_mode"
    case restartFinder = "restart_finder"
    case hideAllWindows = "hide_all_windows"
    case clearClipboard = "clear_clipboard"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quitAllApps: "Quit All Apps"
        case .killFrozenApp: "Force Quit"
        case .purgeMemory: "Free Memory"
        case .noSleep: "Keep Awake"
        case .findLargeFiles: "Large Files"
        case .batteryHealth: "Battery"
        case .processMonitor: "Processes"
        case .scheduledShutdown: "Shutdown Timer"
        case .toggleDarkMode: "Dark Mode"
        case .restartFinder: "Restart Finder"
        case .hideAllWindows: "Hide All"
        case .clearClipboard: "Clear Clipboard"
        }
    }

    var description: String {
        switch self {
        case .quitAllApps: "Close all open apps"
        case .killFrozenApp: "Force quit a stuck app"
        case .purgeMemory: "Clear inactive RAM"
        case .noSleep: "Prevent sleep mode"
        case .findLargeFiles: "Find space hogs"
        case .batteryHealth: "Cycles & condition"
        case .processMonitor: "View running processes"
        case .scheduledShutdown: "Auto shutdown later"
        case .toggleDarkMode: "Toggle appearance"
        case .restartFinder: "Fix Finder issues"
        case .hideAllWindows: "Show the desktop"
        case .clearClipboard: "Erase copied data"
        }
    }

    var icon: String {
        switch self {
        case .quitAllApps: "xmark.app"
        case .killFrozenApp: "exclamationmark.triangle"
        case .purgeMemory: "memorychip"
        case .noSleep: "moon.zzz"
        case .findLargeFiles: "externaldrive.badge.magnifyingglass"
        case .batteryHealth: "battery.100.bolt"
        case .processMonitor: "list.bullet.rectangle"
        case .scheduledShutdown: "power.circle"
        case .toggleDarkMode: "moon.fill"
        case .restartFinder: "arrow.triangle.2.circlepath"
        case .hideAllWindows: "macwindow.on.rectangle"
        case .clearClipboard: "doc.on.clipboard"
        }
    }

    var accentColor: Color {
        switch self {
        case .quitAllApps: .red
        case .killFrozenApp: .orange
        case .purgeMemory: .purple
        case .noSleep: .yellow
        case .findLargeFiles: .green
        case .batteryHealth: .mint
        case .processMonitor: .blue
        case .scheduledShutdown: .red
        case .toggleDarkMode: .indigo
        case .restartFinder: .cyan
        case .hideAllWindows: .teal
        case .clearClipboard: .pink
        }
    }

    var requiresAdmin: Bool {
        switch self {
        case .purgeMemory, .noSleep, .scheduledShutdown: true
        default: false
        }
    }
}
