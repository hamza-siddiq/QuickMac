import Foundation
import SwiftUI

enum QuickBarTool: String, CaseIterable, Identifiable {
    case quitAllApps = "quit_all"
    case killFrozenApp = "kill_frozen"
    case purgeMemory = "purge_memory"
    case processMonitor = "process_monitor"
    case noSleep = "no_sleep"
    case resetBluetooth = "reset_bluetooth"
    case removeQuarantine = "remove_quarantine"
    case networkReset = "network_reset"
    case scheduledShutdown = "scheduled_shutdown"
    case forceEject = "force_eject"
    case findLargeFiles = "find_large_files"
    case batteryHealth = "battery_health"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quitAllApps: "Quit All Other Apps"
        case .killFrozenApp: "Kill Frozen App"
        case .purgeMemory: "Purge Memory"
        case .noSleep: "No Sleep"
        case .removeQuarantine: "Remove Quarantine"
        case .resetBluetooth: "Reset Bluetooth"
        case .findLargeFiles: "Find Large Files"
        case .batteryHealth: "Battery Health"
        case .forceEject: "Force Eject"
        case .networkReset: "Network Reset"
        case .scheduledShutdown: "Scheduled Shutdown"
        case .processMonitor: "Process Monitor"
        }
    }

    var description: String {
        switch self {
        case .quitAllApps: "Quit all apps except the frontmost one"
        case .killFrozenApp: "Force quit a hung application"
        case .purgeMemory: "Clear inactive RAM to free memory"
        case .noSleep: "Prevent Mac from sleeping"
        case .removeQuarantine: "Fix 'unidentified developer' blocks"
        case .resetBluetooth: "Restart Bluetooth when devices disconnect"
        case .findLargeFiles: "Find files taking up disk space"
        case .batteryHealth: "Check battery cycle count and condition"
        case .forceEject: "Eject stuck external drives"
        case .networkReset: "Flush DNS and renew network connection"
        case .scheduledShutdown: "Shut down after set minutes"
        case .processMonitor: "View and kill background processes"
        }
    }

    var icon: String {
        switch self {
        case .quitAllApps: "xmark.app"
        case .killFrozenApp: "exclamationmark.triangle"
        case .purgeMemory: "memorychip"
        case .noSleep: "moon.circle"
        case .removeQuarantine: "shield.slash"
        case .resetBluetooth: "antenna.radiowaves.left.and.right"
        case .findLargeFiles: "magnifyingglass"
        case .batteryHealth: "battery.100.bolt"
        case .forceEject: "eject.circle"
        case .networkReset: "network"
        case .scheduledShutdown: "power.circle"
        case .processMonitor: "list.bullet.rectangle"
        }
    }

    var accentColor: Color {
        .primary
    }

    var requiresAdmin: Bool {
        switch self {
        case .purgeMemory, .noSleep, .resetBluetooth, .networkReset, .scheduledShutdown: true
        default: false
        }
    }
}
