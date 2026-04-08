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
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

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

    @State private var hoveredApp: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Force Quit App")
                    .font(.headline)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider().opacity(0.4)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(apps, id: \.bundleIdentifier) { app in
                        Button(action: { onQuit(app) }) {
                            HStack(spacing: 10) {
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                }
                                Text(app.localizedName ?? "Unknown")
                                    .font(.system(size: 13))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.red.opacity(0.7))
                                    .font(.system(size: 14))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(hoveredApp == app.bundleIdentifier ? .red.opacity(0.06) : .clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            hoveredApp = hovering ? app.bundleIdentifier : nil
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
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

    var totalSize: String {
        let total = files.reduce(Int64(0)) { $0 + $1.size }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: total)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Large Files")
                        .font(.headline)
                    Text("\(files.count) files using \(totalSize)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider().opacity(0.4)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(files.enumerated()), id: \.element.id) { _, file in
                        HStack(spacing: 10) {
                            Image(systemName: fileIcon(for: file.name))
                                .foregroundColor(.secondary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                Text(file.url.deletingLastPathComponent().path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(file.sizeFormatted)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(file.size > 1_000_000_000 ? .orange : .secondary)

                            Button("Reveal") {
                                NSWorkspace.shared.activateFileViewerSelecting([file.url])
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.secondary.opacity(0.03))
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .frame(height: 350)
        }
        .frame(width: 480, height: 450)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func fileIcon(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "mp4", "mov", "avi", "mkv": return "film"
        case "zip", "rar", "7z", "tar", "gz": return "doc.zipper"
        case "dmg", "iso", "img": return "opticaldisc"
        case "pdf": return "doc.text"
        case "jpg", "jpeg", "png", "heic", "gif": return "photo"
        case "mp3", "wav", "aac", "flac": return "music.note"
        case "app": return "app"
        default: return "doc"
        }
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
                .foregroundStyle(.red)

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
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        selectedMinutes == mins && !useCustom
                                            ? Color.accentColor.opacity(0.15)
                                            : Color(nsColor: .controlBackgroundColor)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        selectedMinutes == mins && !useCustom
                                            ? Color.accentColor.opacity(0.3)
                                            : .clear,
                                        lineWidth: 1
                                    )
                            )
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
                .foregroundStyle(.red)

            Text("Cancel Shutdown?")
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
                .tint(.red)
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
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.system(size: 16))
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
            .padding(.vertical, 6)
            .background(.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider().opacity(0.4)

            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading processes...")
                    Spacer()
                }
                .frame(height: 400)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(filteredGroups.enumerated()), id: \.element.id) { _, group in
                            HStack(spacing: 10) {
                                Image(systemName: group.category.icon)
                                    .foregroundColor(group.category.color)
                                    .font(.system(size: 14))
                                    .frame(width: 22)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(group.name)
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)

                                        if group.count > 1 {
                                            Text("\u{00D7}\(group.count)")
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(.secondary.opacity(0.08))
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
                                            .foregroundColor(group.totalCPU > 50 ? .orange : .secondary)
                                    }

                                    VStack(spacing: 1) {
                                        Text("MEM")
                                            .font(.system(size: 8, weight: .medium))
                                            .foregroundColor(.secondary)
                                        Text("\(group.totalMemory, specifier: "%.1f")%")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(group.totalMemory > 10 ? .orange : .secondary)
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
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.secondary.opacity(0.03))
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
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
