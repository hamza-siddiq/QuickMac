import SwiftUI

struct QuickBarView: View {
    let state: QuickBarState
    let delegate: AppDelegate
    let services = QuickBarServices.shared

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            memoryBarSection
            Divider()
            toolsList
            Divider()
            statusSection
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            refreshData()
        }
    }

    private var headerSection: some View {
        HStack {
            Text("QuickBar")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            HStack(spacing: 4) {
                Text("\(state.runningAppCount) apps")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Button(action: refreshData) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var memoryBarSection: some View {
        MemoryBarView(
            used: state.memoryUsed,
            total: state.memoryTotal,
            purgeable: state.memoryPurgeable,
            percent: state.memoryUsagePercent
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var toolsList: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(state.toolOrder) { tool in
                ToolBlockView(tool: tool, state: state) {
                    handleToolAction(tool)
                }
                .onDrag {
                    NSItemProvider(object: tool.rawValue as NSString)
                }
                .onDrop(of: [.text], delegate: ToolDropDelegate(tool: tool, toolOrder: state.toolOrder, onReorder: { state.toolOrder = $0 }))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusSection: some View {
        Group {
            switch state.lastActionStatus {
            case .idle:
                EmptyView()
            case .inProgress:
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(state.lastAction ?? "")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            case .success:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 11))
                    Text(state.lastAction ?? "Done")
                        .font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
            case .failure:
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 11))
                    Text(state.lastAction ?? "Failed")
                        .font(.system(size: 11))
                }
                .foregroundColor(.red)
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func refreshData() {
        state.refreshAppCount()
        state.refreshBatteryInfo()
        state.refreshEjectableVolumes()
        state.refreshMemoryInfo()
    }

    private func handleToolAction(_ tool: QuickBarTool) {
        switch tool {
        case .quitAllApps:
            state.lastActionStatus = .inProgress
            state.lastAction = "Quitting all other apps..."
            services.quitAllOtherApps(excludeBundleID: state.frontmostAppBundleID)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                state.refreshAppCount()
                state.lastActionStatus = .success
                state.lastAction = "All other apps quit"
            }

        case .killFrozenApp:
            delegate.showKillFrozenAppDialog()

        case .purgeMemory:
            handleAdminAction("Purging memory...") { password in
                let freed = state.memoryPurgeable
                let result = services.purgeMemory(adminPassword: password)
                switch result {
                case .success:
                    state.refreshMemoryInfo()
                    state.lastActionStatus = .success
                    state.lastAction = String(format: "Memory purged (%.1f GB freed)", freed)
                case .failure(let error):
                    state.adminPassword = nil
                    state.lastActionStatus = .failure
                    state.lastAction = error.localizedDescription
                }
            }

        case .noSleep:
            let newState = !state.isNoSleepEnabled
            handleAdminAction(newState ? "Enabling no sleep..." : "Disabling no sleep...") { password in
                let result = services.toggleNoSleep(enabled: newState, adminPassword: password)
                switch result {
                case .success:
                    state.isNoSleepEnabled = newState
                    state.lastActionStatus = .success
                    state.lastAction = newState ? "No sleep enabled" : "No sleep disabled"
                case .failure(let error):
                    state.adminPassword = nil
                    state.lastActionStatus = .failure
                    state.lastAction = error.localizedDescription
                }
            }

        case .removeQuarantine:
            delegate.showQuarantineDialog()

        case .resetBluetooth:
            handleAdminAction("Resetting Bluetooth...") { password in
                let result = services.resetBluetooth(adminPassword: password)
                switch result {
                case .success:
                    state.lastActionStatus = .success
                    state.lastAction = "Bluetooth reset"
                case .failure(let error):
                    state.adminPassword = nil
                    state.lastActionStatus = .failure
                    state.lastAction = error.localizedDescription
                }
            }

        case .findLargeFiles:
            Task {
                state.isScanningFiles = true
                state.lastActionStatus = .inProgress
                state.lastAction = "Scanning for large files..."

                let dirs = [
                    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"),
                    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"),
                    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
                ]

                let files = await services.findLargeFiles(in: dirs)
                state.largeFiles = files
                state.isScanningFiles = false
                state.lastActionStatus = .success
                state.lastAction = "Found \(files.count) large files"

                if !files.isEmpty {
                    delegate.showLargeFilesDialog(files: files)
                }
            }

        case .batteryHealth:
            state.refreshBatteryInfo()
            state.lastActionStatus = .success
            state.lastAction = "Battery: \(state.batteryHealth) (\(state.batteryCycleCount) cycles)"

        case .forceEject:
            state.refreshEjectableVolumes()
            if state.forceEjectVolumes.isEmpty {
                state.lastActionStatus = .success
                state.lastAction = "No external drives found"
            } else {
                delegate.showForceEjectDialog(volumes: state.forceEjectVolumes)
            }

        case .networkReset:
            handleAdminAction("Resetting network...") { password in
                let result = services.resetNetwork(adminPassword: password)
                switch result {
                case .success:
                    state.lastActionStatus = .success
                    state.lastAction = "Network reset"
                case .failure(let error):
                    state.adminPassword = nil
                    state.lastActionStatus = .failure
                    state.lastAction = error.localizedDescription
                }
            }

        case .scheduledShutdown:
            if state.isShutdownScheduled {
                delegate.showCancelShutdownDialog()
            } else {
                delegate.showScheduledShutdownDialog()
            }

        case .processMonitor:
            delegate.showProcessMonitorDialog()
        }
    }

    private func handleAdminAction(_ message: String, action: @escaping (String) -> Void) {
        if let cached = state.adminPassword {
            state.lastActionStatus = .inProgress
            state.lastAction = message
            action(cached)
        } else {
            delegate.showPasswordPrompt { password in
                guard let password else { return }
                state.adminPassword = password
                state.lastActionStatus = .inProgress
                state.lastAction = message
                action(password)
            }
        }
    }
}

struct ToolDropDelegate: DropDelegate {
    let tool: QuickBarTool
    let toolOrder: [QuickBarTool]
    let onReorder: ([QuickBarTool]) -> Void

    func performDrop(info: DropInfo) -> Bool {
        true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropEntered(info: DropInfo) {
        if let item = info.itemProviders(for: ["public.plain-text"]).first {
            _ = item.loadObject(ofClass: NSString.self) { (obj, error) in
                if let raw = obj as? String,
                   let source = QuickBarTool(rawValue: raw),
                   let fromIndex = toolOrder.firstIndex(of: source),
                   let toIndex = toolOrder.firstIndex(of: tool),
                   fromIndex != toIndex {
                    var newOrder = toolOrder
                    DispatchQueue.main.async {
                        withAnimation {
                            let moved = newOrder.remove(at: fromIndex)
                            newOrder.insert(moved, at: toIndex)
                            self.onReorder(newOrder)
                        }
                    }
                }
            }
        }
    }
}
