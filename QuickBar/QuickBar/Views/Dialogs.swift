import SwiftUI

struct PasswordPromptView: View {
    @State private var password: String = ""
    @FocusState private var isPasswordFocused: Bool
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("Admin Password")
                .font(.headline)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
                .focused($isPasswordFocused)
                .onSubmit {
                    guard !password.isEmpty else { return }
                    onConfirm(password)
                }

            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Button("OK") {
                    guard !password.isEmpty else { return }
                    onConfirm(password)
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)
            }
        }
        .padding()
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPasswordFocused = true
            }
        }
    }
}

struct KillAppPickerView: View {
    let apps: [NSRunningApplication]
    let onQuit: (NSRunningApplication) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Force Quit App")
                    .font(.headline)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(apps, id: \.bundleIdentifier) { app in
                        Button(action: { onQuit(app) }) {
                            HStack(spacing: 10) {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                }
                                Text(app.localizedName ?? "Unknown")
                                    .font(.system(size: 13))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())

                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
            .frame(height: 300)
        }
        .frame(width: 300, height: 400)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct LargeFilesView: View {
    let files: [LargeFile]
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Large Files (\(files.count))")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(files.enumerated()), id: \.element.id) { _, file in
                        HStack(spacing: 10) {
                            Image(systemName: "doc")
                                .foregroundColor(.secondary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                Text(file.url.path)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(file.sizeFormatted)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)

                            Button("Reveal") {
                                NSWorkspace.shared.activateFileViewerSelecting([file.url])
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
            .frame(height: 350)
        }
        .frame(width: 480, height: 450)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ForceEjectView: View {
    let volumes: [String]
    let onEject: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Force Eject Drives")
                    .font(.headline)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(volumes.enumerated()), id: \.element) { _, volume in
                        HStack(spacing: 10) {
                            Image(systemName: "externaldrive")
                                .foregroundColor(.secondary)
                                .frame(width: 20)

                            Text(volume)
                                .font(.system(size: 13))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button("Eject") {
                                onEject(volume)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            }
            .frame(height: 200)
        }
        .frame(width: 320, height: 300)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct QuarantinePickerView: View {
    let onPick: (URL) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("Remove Quarantine")
                .font(.headline)

            Text("Select the app or file blocked by Gatekeeper")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Choose File...") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.prompt = "Select"

                if panel.runModal() == .OK, let url = panel.url {
                    onPick(url)
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Cancel") {
                onDismiss()
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ScheduledShutdownView: View {
    @State private var selectedMinutes: Int = 30
    @State private var customMinutes: String = ""
    @State private var useCustom: Bool = false
    let onSchedule: (Date) -> Void
    let onDismiss: () -> Void
    
    let presets = [15, 30, 45, 60, 90, 120]
    
    var shutdownDate: Date {
        let minutes = useCustom ? (Int(customMinutes) ?? 30) : selectedMinutes
        return Date().addingTimeInterval(Double(max(1, minutes) * 60))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "power.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("Schedule Shutdown")
                .font(.headline)

            VStack(spacing: 8) {
                Text("Shut down in")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(presets, id: \.self) { mins in
                        Button(action: { selectedMinutes = mins; useCustom = false }) {
                            VStack(spacing: 2) {
                                Text("\(mins)")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("min")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                selectedMinutes == mins && !useCustom
                                    ? Color.accentColor.opacity(0.15)
                                    : Color(nsColor: .controlBackgroundColor)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                HStack(spacing: 8) {
                    Toggle("Custom", isOn: $useCustom)
                        .toggleStyle(.switch)
                        .scaleEffect(0.8)
                    
                    TextField("Minutes", text: $customMinutes)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!useCustom)
                }
            }
            
            Text("Shutdown at \(formattedTime)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.bordered)

                Button("Schedule") {
                    onSchedule(shutdownDate)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: shutdownDate)
    }
}

struct CancelShutdownView: View {
    let scheduledTime: Date
    let onCancel: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "power.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("Cancel Scheduled Shutdown")
                .font(.headline)

            Text("Your Mac is scheduled to shut down at \(formattedTime)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button("Keep Schedule") {
                    onDismiss()
                }
                .buttonStyle(.bordered)

                Button("Cancel Shutdown") {
                    onCancel()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: scheduledTime)
    }
}

struct ProcessMonitorView: View {
    @State private var groups: [ProcessGroup] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = true
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Process Monitor")
                    .font(.headline)
                Spacer()
                Button(action: loadProcesses) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Search processes...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading processes...")
                    Spacer()
                }
                .frame(height: 400)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredGroups.enumerated()), id: \.element.id) { _, group in
                            HStack(spacing: 10) {
                                Image(systemName: group.category.icon)
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                                    .frame(width: 22)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(group.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)
                                        
                                        if group.count > 1 {
                                            Text("×\(group.count)")
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(.secondary.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    
                                    Text(group.description)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                HStack(spacing: 12) {
                                    VStack(spacing: 1) {
                                        Text("CPU")
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Text("\(group.totalCPU, specifier: "%.1f")%")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    VStack(spacing: 1) {
                                        Text("MEM")
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Text("\(group.totalMemory, specifier: "%.1f")%")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }

                                    Button("Kill") {
                                        for pid in group.pids {
                                            _ = QuickBarServices.shared.killProcess(pid: pid)
                                        }
                                        loadProcesses()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)

                            Divider()
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .frame(height: 400)
            }
        }
        .frame(width: 520, height: 520)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            loadProcesses()
        }
    }

    private var filteredGroups: [ProcessGroup] {
        guard !searchText.isEmpty else { return groups }
        let term = searchText.lowercased()
        return groups.filter {
            $0.name.lowercased().contains(term) ||
            $0.description.lowercased().contains(term)
        }
    }

    private func loadProcesses() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let procs = QuickBarServices.shared.getGroupedProcesses()
            DispatchQueue.main.async {
                groups = procs
                isLoading = false
            }
        }
    }
}
