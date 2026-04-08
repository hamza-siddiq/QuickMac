import SwiftUI

struct QuickBarView: View {
    let state: QuickBarState
    let delegate: AppDelegate
    let services = QuickBarServices.shared

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            systemBarsSection
            toolsList
            statusSection
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .onAppear {
            refreshData()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("QuickBar")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                HStack(spacing: 6) {
                    Text("\(state.runningAppCount) apps")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(.secondary.opacity(0.10))
                        .clipShape(Capsule())

                    Button(action: refreshData) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(state.isRefreshing ? 360 : 0))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().opacity(0.4)
        }
    }

    // MARK: - System Bars

    private var systemBarsSection: some View {
        VStack(spacing: 6) {
            SystemBarView(
                label: "MEMORY",
                used: state.memoryUsed,
                total: state.memoryTotal,
                percent: state.memoryUsagePercent,
                extra: state.memoryPurgeable > 0.5
                    ? "~\(String(format: "%.1f", state.memoryPurgeable)) GB freeable"
                    : nil
            )

            SystemBarView(
                label: "DISK",
                used: state.diskUsed,
                total: state.diskTotal,
                percent: state.diskPercent
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Tools Grid

    private var toolsList: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            ForEach(state.toolOrder) { tool in
                ToolBlockView(tool: tool, state: state) {
                    handleToolAction(tool)
                }
                .onDrag {
                    NSItemProvider(object: tool.rawValue as NSString)
                }
                .onDrop(of: [.text], delegate: ToolDropDelegate(
                    tool: tool,
                    currentOrder: { state.toolOrder },
                    onReorder: {
                        state.toolOrder = $0
                        state.saveToolOrder()
                    }
                ))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Status

    private var statusSection: some View {
        Group {
            switch state.lastActionStatus {
            case .idle:
                EmptyView()
            case .inProgress:
                HStack(spacing: 5) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text(state.lastAction ?? "")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.secondary.opacity(0.08))
                .clipShape(Capsule())
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            case .success:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text(state.lastAction ?? "Done")
                        .font(.system(size: 10))
                }
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.green.opacity(0.08))
                .clipShape(Capsule())
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            case .failure:
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10))
                    Text(state.lastAction ?? "Failed")
                        .font(.system(size: 10))
                }
                .foregroundColor(.red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.red.opacity(0.08))
                .clipShape(Capsule())
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state.lastActionStatus)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Data

    private func refreshData() {
        state.refreshAppCount()
        state.refreshBatteryInfo()
        state.refreshMemoryInfo()
        state.refreshDiskInfo()
        state.refreshDarkMode()
    }

    // MARK: - Tool Actions

    private func handleToolAction(_ tool: QuickBarTool) {
        switch tool {
        case .quitAllApps:
            state.setStatus(.inProgress, message: "Quitting all other apps...")
            services.quitAllOtherApps(excludeBundleID: state.frontmostAppBundleID)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                state.refreshAppCount()
                state.setStatus(.success, message: "All other apps quit")
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
                    state.setStatus(.success, message: String(format: "Memory purged (%.1f GB freed)", freed))
                case .failure(let error):
                    state.adminPassword = nil
                    state.setStatus(.failure, message: error.localizedDescription)
                }
            }

        case .noSleep:
            let newState = !state.isNoSleepEnabled
            handleAdminAction(newState ? "Enabling keep awake..." : "Disabling keep awake...") { password in
                let result = services.toggleNoSleep(enabled: newState, adminPassword: password)
                switch result {
                case .success:
                    state.isNoSleepEnabled = newState
                    state.setStatus(.success, message: newState ? "Keep awake enabled" : "Keep awake disabled")
                case .failure(let error):
                    state.adminPassword = nil
                    state.setStatus(.failure, message: error.localizedDescription)
                }
            }

        case .findLargeFiles:
            Task {
                state.isScanningFiles = true
                state.setStatus(.inProgress, message: "Scanning for large files...")

                let dirs = [
                    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads"),
                    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"),
                    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
                ]

                let files = await services.findLargeFiles(in: dirs)
                state.largeFiles = files
                state.isScanningFiles = false

                if files.isEmpty {
                    state.setStatus(.success, message: "No large files found")
                } else {
                    state.setStatus(.success, message: "Found \(files.count) large files")
                    delegate.showLargeFilesDialog(files: files)
                }
            }

        case .batteryHealth:
            state.refreshBatteryInfo()
            state.setStatus(.success, message: "Battery: \(state.batteryHealth) (\(state.batteryCycleCount) cycles)")

        case .processMonitor:
            delegate.showProcessMonitorDialog()

        case .scheduledShutdown:
            if state.isShutdownScheduled {
                delegate.showCancelShutdownDialog()
            } else {
                delegate.showScheduledShutdownDialog()
            }

        case .toggleDarkMode:
            state.setStatus(.inProgress, message: "Toggling dark mode...")
            DispatchQueue.global(qos: .userInitiated).async {
                let result = services.toggleDarkMode()
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        state.refreshDarkMode()
                        state.setStatus(.success, message: state.isDarkMode ? "Dark mode enabled" : "Light mode enabled")
                    case .failure(let error):
                        state.setStatus(.failure, message: error.localizedDescription)
                    }
                }
            }

        case .restartFinder:
            state.setStatus(.inProgress, message: "Restarting Finder...")
            DispatchQueue.global(qos: .userInitiated).async {
                let result = services.restartFinder()
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        state.setStatus(.success, message: "Finder restarted")
                    case .failure(let error):
                        state.setStatus(.failure, message: error.localizedDescription)
                    }
                }
            }

        case .hideAllWindows:
            state.setStatus(.inProgress, message: "Hiding all windows...")
            DispatchQueue.global(qos: .userInitiated).async {
                let result = services.hideAllWindows()
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        state.setStatus(.success, message: "All windows hidden")
                    case .failure(let error):
                        state.setStatus(.failure, message: error.localizedDescription)
                    }
                }
            }

        case .clearClipboard:
            let result = services.clearClipboard()
            switch result {
            case .success:
                state.setStatus(.success, message: "Clipboard cleared")
            case .failure(let error):
                state.setStatus(.failure, message: error.localizedDescription)
            }
        }
    }

    private func handleAdminAction(_ message: String, action: @escaping (String) -> Void) {
        if let cached = state.adminPassword {
            state.setStatus(.inProgress, message: message)
            action(cached)
        } else {
            delegate.showPasswordPrompt { password in
                guard let password else { return }
                state.adminPassword = password
                state.setStatus(.inProgress, message: message)
                action(password)
            }
        }
    }
}

struct ToolDropDelegate: DropDelegate {
    let tool: QuickBarTool
    let currentOrder: () -> [QuickBarTool]
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
                DispatchQueue.main.async {
                    guard let raw = obj as? String,
                          let source = QuickBarTool(rawValue: raw) else { return }
                    let order = currentOrder()
                    guard let fromIndex = order.firstIndex(of: source),
                          let toIndex = order.firstIndex(of: tool),
                          fromIndex != toIndex else { return }
                    withAnimation {
                        var newOrder = order
                        let moved = newOrder.remove(at: fromIndex)
                        newOrder.insert(moved, at: toIndex)
                        self.onReorder(newOrder)
                    }
                }
            }
        }
    }
}
