import AppKit

let AC_VERSION = "0.1.0"

// MARK: - Catppuccin Mocha Colors
struct Colors {
    static let crust    = NSColor(red: 0x11/255, green: 0x11/255, blue: 0x1b/255, alpha: 1)
    static let mantle   = NSColor(red: 0x18/255, green: 0x18/255, blue: 0x25/255, alpha: 1)
    static let base     = NSColor(red: 0x1e/255, green: 0x1e/255, blue: 0x2e/255, alpha: 0.97)
    static let surface0 = NSColor(red: 0x31/255, green: 0x32/255, blue: 0x44/255, alpha: 1)
    static let surface1 = NSColor(red: 0x45/255, green: 0x47/255, blue: 0x5a/255, alpha: 1)
    static let surface2 = NSColor(red: 0x58/255, green: 0x5b/255, blue: 0x70/255, alpha: 1)
    static let overlay0 = NSColor(red: 0x6c/255, green: 0x70/255, blue: 0x86/255, alpha: 1)
    static let subtext0 = NSColor(red: 0xa6/255, green: 0xad/255, blue: 0xc8/255, alpha: 1)
    static let subtext1 = NSColor(red: 0xba/255, green: 0xc2/255, blue: 0xde/255, alpha: 1)
    static let text     = NSColor(red: 0xcd/255, green: 0xd6/255, blue: 0xf4/255, alpha: 1)
    static let pink     = NSColor(red: 0xf5/255, green: 0xc2/255, blue: 0xe7/255, alpha: 1)
    static let mauve    = NSColor(red: 0xcb/255, green: 0xa6/255, blue: 0xf7/255, alpha: 1)
    static let lavender = NSColor(red: 0xb4/255, green: 0xbe/255, blue: 0xfe/255, alpha: 1)
    static let sapphire = NSColor(red: 0x74/255, green: 0xc7/255, blue: 0xec/255, alpha: 1)
    static let blue     = NSColor(red: 0x89/255, green: 0xb4/255, blue: 0xfa/255, alpha: 1)
    static let teal     = NSColor(red: 0x94/255, green: 0xe2/255, blue: 0xd5/255, alpha: 1)
    static let green    = NSColor(red: 0xa6/255, green: 0xe3/255, blue: 0xa1/255, alpha: 1)
    static let peach    = NSColor(red: 0xfa/255, green: 0xb3/255, blue: 0x87/255, alpha: 1)
    static let red      = NSColor(red: 0xf3/255, green: 0x8b/255, blue: 0xa8/255, alpha: 1)
    static let yellow   = NSColor(red: 0xf9/255, green: 0xe2/255, blue: 0xaf/255, alpha: 1)
    static let sky      = NSColor(red: 0x89/255, green: 0xdc/255, blue: 0xeb/255, alpha: 1)

    static func byName(_ name: String) -> NSColor {
        switch name.lowercased() {
        case "mauve":    return mauve
        case "pink":     return pink
        case "blue":     return blue
        case "sapphire": return sapphire
        case "lavender": return lavender
        case "teal":     return teal
        case "peach":    return peach
        case "green":    return green
        case "red":      return red
        case "yellow":   return yellow
        case "sky":      return sky
        default:         return mauve
        }
    }
}

// MARK: - Shell
@discardableResult
func shell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", command]
    task.launch()
    task.waitUntilExit()
    return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
}

// MARK: - Config Model
struct WorkspaceConfig: Codable {
    var id: String
    var color: String
    var label: String?
}

/// Catppuccin palette names available for workspaces (picker order).
let ALL_COLOR_NAMES = ["mauve", "pink", "blue", "sapphire", "lavender", "teal", "peach", "green", "red", "yellow", "sky"]

struct AppAssignment: Codable {
    var app_id: String
    var app_name: String
    var workspace: String  // workspace id or "" for unassigned
}

/// Optional sketchybar integration. Disabled by default — most users don't run sketchybar.
struct SketchybarConfig: Codable {
    var enabled: Bool
    var path: String?  // optional override; if nil, the binary is auto-detected
}

struct AppConfig: Codable {
    var version: Int
    var workspaces: [WorkspaceConfig]
    var apps: [AppAssignment]
    /// Saved workspace→monitor-name mapping per monitor-name signature, so that
    /// switching between mono / dual / triple-monitor setups restores the user's
    /// previous layout for that exact combination.
    var monitor_layouts: [String: [String: String]]?
    /// Optional sketchybar integration (off by default).
    var sketchybar: SketchybarConfig?

    func color(for workspaceId: String) -> NSColor {
        if let ws = workspaces.first(where: { $0.id == workspaceId }) {
            return Colors.byName(ws.color)
        }
        return Colors.mauve
    }

    func hasWorkspace(_ id: String) -> Bool {
        return workspaces.contains { $0.id == id }
    }

    /// Translate the saved layout for `monitors` (if any) into AeroSpace IDs.
    func savedAssignments(for monitors: [MonitorInfo]) -> [String: Int]? {
        let sig = monitorSignature(monitors)
        guard let saved = monitor_layouts?[sig] else { return nil }
        var out: [String: Int] = [:]
        for (ws, monName) in saved {
            if let m = monitors.first(where: { $0.name == monName }) {
                out[ws] = m.aerospaceId
            }
        }
        return out
    }
}

/// Stable identifier for a monitor combination — sorted names joined with `|`.
/// Names persist across sessions while AeroSpace monitor IDs do not.
func monitorSignature(_ monitors: [MonitorInfo]) -> String {
    return monitors.map { $0.name }.sorted().joined(separator: "|")
}

// MARK: - Paths
/// Centralized path constants. All paths are relative to the user's $HOME
/// (via NSHomeDirectory()) and contain no machine-specific identifiers.
enum Paths {
    static var configDir: String     { NSHomeDirectory() + "/.config/aerospace-control" }
    static var configFile: String    { configDir + "/config.json" }
    static var workspacesSh: String  { configDir + "/workspaces.sh" }
    static var colorsSh: String      { configDir + "/workspace-colors.sh" }
    static var sketchybarMap: String { configDir + "/sketchybar-map.sh" }
    static var resetWindowsSh: String { configDir + "/reset-windows.sh" }
    static var aerospaceToml: String { NSHomeDirectory() + "/.config/aerospace/aerospace.toml" }
    static var sketchybarrc: String  { NSHomeDirectory() + "/.config/sketchybar/sketchybarrc" }

    /// Locate the sketchybar binary. Returns nil if not installed.
    static func sketchybarBinary(override: String? = nil) -> String? {
        if let o = override, FileManager.default.isExecutableFile(atPath: o) { return o }
        let candidates = [
            "/opt/homebrew/bin/sketchybar",   // Apple Silicon brew
            "/usr/local/bin/sketchybar",      // Intel brew
            "/usr/bin/sketchybar",
        ]
        for c in candidates where FileManager.default.isExecutableFile(atPath: c) { return c }
        // Fallback: ask the shell
        let which = shell("command -v sketchybar 2>/dev/null").trimmingCharacters(in: .whitespacesAndNewlines)
        return which.isEmpty ? nil : which
    }
}

// MARK: - Default config
/// Minimal sane default for first-time installs. 4 generic workspaces, no apps,
/// sketchybar disabled. The user customizes via the GUI.
let DEFAULT_CONFIG = AppConfig(
    version: 1,
    workspaces: [
        WorkspaceConfig(id: "1", color: "mauve",    label: nil),
        WorkspaceConfig(id: "2", color: "blue",     label: nil),
        WorkspaceConfig(id: "3", color: "green",    label: nil),
        WorkspaceConfig(id: "4", color: "peach",    label: nil),
    ],
    apps: [],
    monitor_layouts: nil,
    sketchybar: SketchybarConfig(enabled: false, path: nil)
)

class ConfigManager {
    static var path: String { Paths.configFile }

    /// Load config from disk. If missing, write the default and return that.
    static func load() -> AppConfig {
        // Ensure config directory exists.
        try? FileManager.default.createDirectory(atPath: Paths.configDir,
                                                 withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: path)
        if let data = try? Data(contentsOf: url),
           let cfg = try? JSONDecoder().decode(AppConfig.self, from: data) {
            return cfg
        }
        // Bootstrap a default config on first run.
        save(DEFAULT_CONFIG)
        return DEFAULT_CONFIG
    }

    static func save(_ config: AppConfig) {
        try? FileManager.default.createDirectory(atPath: Paths.configDir,
                                                 withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }
}

// MARK: - Bootstrap (first-run setup)
/// Ensure aerospace.toml has the marker blocks we need to write into. Inserts
/// empty marker pairs at sensible positions if missing. Idempotent.
enum Bootstrap {
    static func ensureAerospaceMarkers() {
        let path = Paths.aerospaceToml
        guard var text = try? String(contentsOfFile: path, encoding: .utf8) else {
            NSLog("[bootstrap] aerospace.toml not found at \(path) — skipping marker insertion.")
            return
        }
        var changed = false

        // workspace-bindings marker — must live inside [mode.main.binding]
        if !text.contains("# === BEGIN GENERATED: workspace-bindings ===") {
            let bindingsHeader = "[mode.main.binding]"
            if let headerRange = text.range(of: bindingsHeader) {
                // Find the end of the section (start of next [section] or EOF).
                let afterHeader = headerRange.upperBound
                let rest = text[afterHeader...]
                let nextSectionRel = rest.range(of: "\n[",
                                                options: .literal,
                                                range: rest.startIndex..<rest.endIndex)
                let insertIdx = nextSectionRel?.lowerBound ?? text.endIndex
                let block = "\n\n# === BEGIN GENERATED: workspace-bindings ===\n# === END GENERATED: workspace-bindings ===\n"
                text.insert(contentsOf: block, at: insertIdx)
                changed = true
            } else {
                // Whole [mode.main.binding] section missing — append.
                text += "\n\n[mode.main.binding]\n# === BEGIN GENERATED: workspace-bindings ===\n# === END GENERATED: workspace-bindings ===\n"
                changed = true
            }
        }

        // app-assignments marker — root-level [[on-window-detected]] entries.
        if !text.contains("# === BEGIN GENERATED: app-assignments ===") {
            text += "\n# === BEGIN GENERATED: app-assignments ===\n# === END GENERATED: app-assignments ===\n"
            changed = true
        }

        if changed {
            try? text.write(toFile: path, atomically: true, encoding: .utf8)
            NSLog("[bootstrap] inserted marker blocks into aerospace.toml")
        }
    }
}

// MARK: - Generators (marker-based section rewriting)
private let GEN_HEADER = "# Generated from ~/.config/aerospace-control/config.json — do not edit manually."

enum Generators {
    /// Replace the content between `# === BEGIN GENERATED: <marker> ===` and
    /// `# === END GENERATED: <marker> ===` with newContent. Markers are preserved.
    /// Silently no-ops if the file or markers don't exist (so users opting out of
    /// e.g. sketchybar don't get errors).
    static func replaceSection(file: String, marker: String, newBody: String) {
        let begin = "# === BEGIN GENERATED: \(marker) ==="
        let end   = "# === END GENERATED: \(marker) ==="
        guard var text = try? String(contentsOfFile: file, encoding: .utf8) else { return }
        guard let beginRange = text.range(of: begin),
              let endRange = text.range(of: end, range: beginRange.upperBound..<text.endIndex) else {
            return
        }
        let replacement = "\(begin)\n\(newBody)\n\(end)"
        text.replaceSubrange(beginRange.lowerBound..<endRange.upperBound, with: replacement)
        try? text.write(toFile: file, atomically: true, encoding: .utf8)
    }

    // ── AeroSpace (always run) ──────────────────────────────────────────────

    static func regenerateAerospaceBindings(_ config: AppConfig) {
        var lines = [GEN_HEADER]
        for ws in config.workspaces {
            lines.append("alt-\(ws.id.lowercased()) = 'workspace \(ws.id)'")
        }
        for ws in config.workspaces {
            lines.append("alt-shift-\(ws.id.lowercased()) = 'move-node-to-workspace \(ws.id)'")
        }
        replaceSection(file: Paths.aerospaceToml, marker: "workspace-bindings",
                       newBody: lines.joined(separator: "\n"))
    }

    static func regenerateAerospaceApps(_ config: AppConfig) {
        var lines = [GEN_HEADER]
        let assigned = config.apps.filter { !$0.workspace.isEmpty && config.hasWorkspace($0.workspace) }
        for app in assigned {
            lines.append("[[on-window-detected]]")
            lines.append("if.app-id = \"\(app.app_id)\"")
            lines.append("run = \"move-node-to-workspace \(app.workspace)\"")
            lines.append("")
        }
        if lines.last == "" { lines.removeLast() }
        replaceSection(file: Paths.aerospaceToml, marker: "app-assignments",
                       newBody: lines.joined(separator: "\n"))
    }

    /// Standalone reset-windows script in our own config dir. Independent of any
    /// pre-existing reset script in ~/.config/aerospace/scripts/.
    static func regenerateResetWindowsScript(_ config: AppConfig) {
        var byWorkspace: [String: [String]] = [:]
        for app in config.apps where !app.workspace.isEmpty && config.hasWorkspace(app.workspace) {
            byWorkspace[app.workspace, default: []].append(app.app_name)
        }
        var cases = ""
        for ws in config.workspaces {
            guard let names = byWorkspace[ws.id], !names.isEmpty else { continue }
            let patterns = names.map { name -> String in
                name.contains(" ") || name.contains("'") ? "\"\(name)\"" : name
            }.joined(separator: "|")
            cases += "        \(patterns)) aerospace move-node-to-workspace \(ws.id) --window-id \"$wid\" ;;\n"
        }
        let content = """
        #!/bin/bash
        \(GEN_HEADER)
        # Move every existing window to its assigned workspace.
        aerospace list-windows --all | while IFS='|' read -r wid app rest; do
            wid=$(echo "$wid" | xargs)
            app=$(echo "$app" | xargs)
            case "$app" in
        \(cases)        esac
        done 2>/dev/null
        """
        try? content.write(toFile: Paths.resetWindowsSh, atomically: true, encoding: .utf8)
        _ = shell("chmod +x \(Paths.resetWindowsSh)")
    }

    /// Bash-sourceable file with current workspace list (WS_ALL).
    static func regenerateWorkspacesShell(_ config: AppConfig) {
        let list = config.workspaces.map { $0.id }.joined(separator: " ")
        let content = """
        #!/bin/bash
        \(GEN_HEADER)
        WS_ALL=(\(list))
        """
        try? content.write(toFile: Paths.workspacesSh, atomically: true, encoding: .utf8)
        _ = shell("chmod +x \(Paths.workspacesSh)")
    }

    /// Bash-sourceable `ws_color` function for sketchybar integrations.
    static func regenerateWorkspaceColorsShell(_ config: AppConfig) {
        let hex: [String: String] = [
            "mauve":    "0xFFcba6f7",
            "pink":     "0xFFf5c2e7",
            "blue":     "0xFF89b4fa",
            "sapphire": "0xFF74c7ec",
            "lavender": "0xFFb4befe",
            "teal":     "0xFF94e2d5",
            "peach":    "0xFFfab387",
            "green":    "0xFFa6e3a1",
            "red":      "0xFFf38ba8",
            "yellow":   "0xFFf9e2af",
            "sky":      "0xFF89dceb",
        ]
        var cases = ""
        for ws in config.workspaces {
            let code = hex[ws.color.lowercased()] ?? "0xFFcba6f7"
            cases += "        \(ws.id)) echo \(code) ;;\n"
        }
        let content = """
        #!/bin/bash
        \(GEN_HEADER)
        ws_color() {
            case "$1" in
        \(cases)        *) echo 0xFFcba6f7 ;;
            esac
        }
        """
        try? content.write(toFile: Paths.colorsSh, atomically: true, encoding: .utf8)
        _ = shell("chmod +x \(Paths.colorsSh)")
    }

    // ── Sketchybar (opt-in) ─────────────────────────────────────────────────

    /// Rewrite SPACE_ICONS / SPACE_COLORS in sketchybarrc, but only if the user
    /// added the marker block themselves (we never modify their file unsolicited).
    static func regenerateSketchybarWorkspaces(_ config: AppConfig) {
        guard config.sketchybar?.enabled == true else { return }
        let ids = config.workspaces.map { "\"\($0.id)\"" }.joined(separator: " ")
        let colors = config.workspaces.map { "$\($0.color.uppercased())" }.joined(separator: " ")
        let body = """
        \(GEN_HEADER)
        SPACE_ICONS=(\(ids))
        SPACE_COLORS=(\(colors))
        """
        replaceSection(file: Paths.sketchybarrc, marker: "workspaces", newBody: body)
    }

    static func regenerateAll(_ config: AppConfig) {
        regenerateAerospaceBindings(config)
        regenerateAerospaceApps(config)
        regenerateResetWindowsScript(config)
        regenerateWorkspacesShell(config)
        regenerateWorkspaceColorsShell(config)
        regenerateSketchybarWorkspaces(config)  // no-op if disabled
    }

    static func reloadAerospace() {
        _ = shell("aerospace reload-config")
    }

    /// Hard-restart sketchybar (only when enabled and installed). `--reload`
    /// leaves duplicate items behind, so we kill and relaunch the process.
    static func reloadSketchybar(_ config: AppConfig) {
        guard config.sketchybar?.enabled == true,
              let bin = Paths.sketchybarBinary(override: config.sketchybar?.path) else { return }
        _ = shell("""
        killall sketchybar 2>/dev/null
        sleep 0.3
        nohup \(bin) >/dev/null 2>&1 </dev/null &
        """)
    }

    /// Move every existing window to its assigned workspace (since
    /// `on-window-detected` rules only fire for NEW windows).
    static func runResetWindows() {
        _ = shell("\(Paths.resetWindowsSh) 2>/dev/null")
    }
}

// MARK: - Data
struct MonitorInfo {
    let aerospaceId: Int
    let name: String
    let screen: NSScreen?
    let sketchybarIndex: Int
    let physicalX: CGFloat
}

func detectMonitors() -> [MonitorInfo] {
    let output = shell("aerospace list-monitors --format '%{monitor-id} | %{monitor-name}'")
    let screens = NSScreen.screens
    var result: [MonitorInfo] = []

    for line in output.components(separatedBy: "\n") where !line.isEmpty {
        let parts = line.components(separatedBy: " | ")
        guard parts.count >= 2,
              let aid = Int(parts[0].trimmingCharacters(in: .whitespaces)) else { continue }
        let name = parts[1].trimmingCharacters(in: .whitespaces)
        let screen = screens.first { screen in
            if #available(macOS 10.15, *) { return screen.localizedName == name }
            return false
        }
        let sbIdx: Int
        if let screen = screen, let idx = screens.firstIndex(of: screen) {
            sbIdx = idx + 1
        } else {
            sbIdx = aid
        }
        let px = screen?.frame.origin.x ?? CGFloat(aid) * 10000
        result.append(MonitorInfo(aerospaceId: aid, name: name, screen: screen,
                                  sketchybarIndex: sbIdx, physicalX: px))
    }
    return result.sorted { $0.physicalX < $1.physicalX }
}

func detectCurrentAssignments(workspaces: [String]) -> [String: Int] {
    let output = shell("aerospace list-workspaces --all --format '%{workspace} | %{monitor-id}'")
    var map: [String: Int] = [:]
    for line in output.components(separatedBy: "\n") where !line.isEmpty {
        let parts = line.components(separatedBy: " | ")
        guard parts.count >= 2,
              let mid = Int(parts[1].trimmingCharacters(in: .whitespaces)) else { continue }
        let ws = parts[0].trimmingCharacters(in: .whitespaces)
        if workspaces.contains(ws) { map[ws] = mid }
    }
    return map
}

// MARK: - Button helper
func makeButton(title: String, width: CGFloat = 72, height: CGFloat = 26, color: NSColor, accent: Bool = false, target: AnyObject?, action: Selector) -> NSButton {
    let btn = NSButton(frame: NSRect(x: 0, y: 0, width: width, height: height))
    btn.title = title
    btn.bezelStyle = .regularSquare
    btn.isBordered = false
    btn.wantsLayer = true
    btn.layer?.cornerRadius = 8
    btn.layer?.backgroundColor = accent ? color.withAlphaComponent(0.25).cgColor : Colors.surface0.cgColor
    btn.layer?.borderWidth = 1
    btn.layer?.borderColor = accent ? color.withAlphaComponent(0.7).cgColor : Colors.surface1.cgColor
    btn.contentTintColor = accent ? color : Colors.subtext1
    btn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
    btn.target = target
    btn.action = action
    return btn
}

// MARK: - Tab Bar
protocol TabBarDelegate: AnyObject {
    func tabBar(_ bar: TabBarView, didSelectTab index: Int)
}

class TabBarView: NSView {
    let tabs: [String]
    weak var delegate: TabBarDelegate?
    private(set) var selectedIndex = 0
    private var buttons: [NSButton] = []
    override var mouseDownCanMoveWindow: Bool { false }

    init(tabs: [String], frame: NSRect) {
        self.tabs = tabs
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        let gap: CGFloat = 4
        let btnW: CGFloat = 90
        let btnH: CGFloat = 28
        let total = CGFloat(tabs.count) * btnW + CGFloat(tabs.count - 1) * gap
        var x = (bounds.width - total) / 2
        for (i, t) in tabs.enumerated() {
            let btn = NSButton(frame: NSRect(x: x, y: (bounds.height - btnH) / 2, width: btnW, height: btnH))
            btn.title = t
            btn.bezelStyle = .regularSquare
            btn.isBordered = false
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 10
            btn.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            btn.tag = i
            btn.target = self
            btn.action = #selector(tabClicked(_:))
            addSubview(btn)
            buttons.append(btn)
            x += btnW + gap
        }
        updateStyle()
    }

    @objc private func tabClicked(_ sender: NSButton) {
        select(index: sender.tag)
    }

    func select(index: Int) {
        guard index != selectedIndex, index >= 0, index < tabs.count else { return }
        selectedIndex = index
        updateStyle()
        delegate?.tabBar(self, didSelectTab: index)
    }

    private func updateStyle() {
        for (i, btn) in buttons.enumerated() {
            if i == selectedIndex {
                btn.layer?.backgroundColor = Colors.mauve.withAlphaComponent(0.22).cgColor
                btn.layer?.borderWidth = 1
                btn.layer?.borderColor = Colors.mauve.withAlphaComponent(0.7).cgColor
                btn.contentTintColor = Colors.mauve
            } else {
                btn.layer?.backgroundColor = Colors.surface0.withAlphaComponent(0.7).cgColor
                btn.layer?.borderWidth = 1
                btn.layer?.borderColor = Colors.surface1.cgColor
                btn.contentTintColor = Colors.subtext1
            }
        }
    }
}

// MARK: - Workspace Chip (for Monitors tab — draggable)
class WorkspaceChipView: NSView {
    let workspace: String
    let color: NSColor
    var monitorId: Int
    weak var mapperView: MonitorsTabView?
    var label: NSTextField!

    override var mouseDownCanMoveWindow: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    init(workspace: String, color: NSColor, monitorId: Int, mapperView: MonitorsTabView) {
        self.workspace = workspace
        self.color = color
        self.monitorId = monitorId
        self.mapperView = mapperView
        super.init(frame: NSRect(x: 0, y: 0, width: 44, height: 44))
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.backgroundColor = color.withAlphaComponent(0.18).cgColor
        layer?.borderWidth = 1.5
        layer?.borderColor = color.withAlphaComponent(0.7).cgColor

        let shadow = NSShadow()
        shadow.shadowColor = color.withAlphaComponent(0.5)
        shadow.shadowBlurRadius = 6
        shadow.shadowOffset = .zero
        self.shadow = shadow

        label = NSTextField(labelWithString: workspace)
        label.font = NSFont.monospacedSystemFont(ofSize: 18, weight: .bold)
        label.textColor = color
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.alignment = .center
        label.refusesFirstResponder = true
        addSubview(label)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return self.frame.contains(point) ? self : nil
    }

    override func layout() {
        super.layout()
        label.sizeToFit()
        label.frame.origin = NSPoint(
            x: (bounds.width - label.frame.width) / 2,
            y: (bounds.height - label.frame.height) / 2
        )
    }

    override func mouseDown(with event: NSEvent)   { mapperView?.chipBeganDrag(self) }
    override func mouseDragged(with event: NSEvent){ mapperView?.chipDragged(self, event: event) }
    override func mouseUp(with event: NSEvent)     { mapperView?.chipEndedDrag(self) }

    func setDragging(_ dragging: Bool) {
        if dragging {
            layer?.backgroundColor = color.withAlphaComponent(0.35).cgColor
            layer?.borderColor = color.cgColor
            layer?.borderWidth = 2
        } else {
            layer?.backgroundColor = color.withAlphaComponent(0.18).cgColor
            layer?.borderColor = color.withAlphaComponent(0.7).cgColor
            layer?.borderWidth = 1.5
        }
    }
}

// MARK: - Monitor Box
class MonitorBoxView: NSView {
    let monitor: MonitorInfo
    var isBuiltIn: Bool { monitor.name.contains("Built-in") }
    override var mouseDownCanMoveWindow: Bool { false }

    init(monitor: MonitorInfo, frame: NSRect) {
        self.monitor = monitor
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.backgroundColor = Colors.mantle.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = Colors.surface1.cgColor

        let icon = NSTextField(labelWithString: isBuiltIn ? "🖥" : "🖵")
        icon.font = NSFont.systemFont(ofSize: 18)
        icon.backgroundColor = .clear
        icon.isBezeled = false
        icon.isEditable = false
        icon.sizeToFit()
        icon.frame.origin = NSPoint(x: 10, y: bounds.height - icon.frame.height - 10)
        addSubview(icon)

        let name = NSTextField(labelWithString: monitor.name)
        name.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        name.textColor = Colors.subtext1
        name.backgroundColor = .clear
        name.isBezeled = false
        name.isEditable = false
        name.lineBreakMode = .byTruncatingTail
        name.sizeToFit()
        let maxW = bounds.width - icon.frame.maxX - 50
        name.frame = NSRect(
            x: icon.frame.maxX + 6,
            y: bounds.height - name.frame.height - 12,
            width: min(name.frame.width, maxW),
            height: name.frame.height
        )
        addSubview(name)

        let sb = NSTextField(labelWithString: "sb·\(monitor.sketchybarIndex)")
        sb.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        sb.textColor = Colors.overlay0
        sb.backgroundColor = .clear
        sb.isBezeled = false
        sb.isEditable = false
        sb.sizeToFit()
        sb.frame.origin = NSPoint(
            x: bounds.width - sb.frame.width - 10,
            y: bounds.height - sb.frame.height - 13
        )
        addSubview(sb)

        let divider = NSView(frame: NSRect(x: 10, y: bounds.height - 40, width: bounds.width - 20, height: 1))
        divider.wantsLayer = true
        divider.layer?.backgroundColor = Colors.surface0.cgColor
        addSubview(divider)
    }

    func setHighlighted(_ highlighted: Bool) {
        if highlighted {
            layer?.borderColor = Colors.mauve.cgColor
            layer?.borderWidth = 2
            layer?.backgroundColor = Colors.surface0.withAlphaComponent(0.4).cgColor
        } else {
            layer?.borderColor = Colors.surface1.cgColor
            layer?.borderWidth = 1
            layer?.backgroundColor = Colors.mantle.cgColor
        }
    }

    var chipArea: NSRect {
        return NSRect(x: 8, y: 8, width: bounds.width - 16, height: bounds.height - 48)
    }
}

// MARK: - Monitors Tab
class MonitorsTabView: NSView {
    var monitors: [MonitorInfo] = []
    var config: AppConfig
    var monitorBoxes: [MonitorBoxView] = []
    var chips: [WorkspaceChipView] = []

    private var draggingChip: WorkspaceChipView?
    private var dragStartPointInSelf: NSPoint = .zero
    private var chipStartPoint: NSPoint = .zero

    override var mouseDownCanMoveWindow: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    init(frame: NSRect, config: AppConfig) {
        self.config = config
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError() }

    func setup(monitors: [MonitorInfo], assignments: [String: Int]) {
        self.monitors = monitors
        for sub in subviews { sub.removeFromSuperview() }
        monitorBoxes.removeAll()
        chips.removeAll()

        let topMargin: CGFloat = 40
        let bottomMargin: CGFloat = 16
        let sideMargin: CGFloat = 24
        let boxGap: CGFloat = 14
        let boxHeight = bounds.height - topMargin - bottomMargin

        // Preset buttons (top-right)
        var px = bounds.width - 24
        let presets: [(String, Selector, NSColor)] = [
            ("Laptop", #selector(applyPresetLaptop), Colors.peach),
            ("2-Mon",  #selector(applyPreset2),      Colors.sapphire),
            ("3-Mon",  #selector(applyPreset3),      Colors.green),
        ]
        for (label, sel, color) in presets {
            let btn = makeButton(title: label, width: 64, color: color, accent: true, target: self, action: sel)
            btn.frame.origin = NSPoint(x: px - btn.frame.width, y: bounds.height - topMargin + 8)
            px = btn.frame.origin.x - 6
            addSubview(btn)
        }

        // Subtitle (left)
        let subtitle = NSTextField(labelWithString: "Drag workspace chips between monitors")
        subtitle.font = NSFont.systemFont(ofSize: 11)
        subtitle.textColor = Colors.subtext0
        subtitle.backgroundColor = .clear
        subtitle.isBezeled = false
        subtitle.isEditable = false
        subtitle.sizeToFit()
        subtitle.frame.origin = NSPoint(x: 24, y: bounds.height - topMargin + 10)
        addSubview(subtitle)

        if monitors.isEmpty {
            let none = NSTextField(labelWithString: "No monitors detected")
            none.font = NSFont.systemFont(ofSize: 14)
            none.textColor = Colors.subtext0
            none.backgroundColor = .clear
            none.isBezeled = false
            none.isEditable = false
            none.sizeToFit()
            none.frame.origin = NSPoint(x: (bounds.width - none.frame.width) / 2, y: bounds.height / 2)
            addSubview(none)
            return
        }

        let totalGaps = boxGap * CGFloat(max(monitors.count - 1, 0))
        let availableWidth = bounds.width - 2 * sideMargin - totalGaps
        let boxWidth = availableWidth / CGFloat(monitors.count)
        for (i, mon) in monitors.enumerated() {
            let x = sideMargin + CGFloat(i) * (boxWidth + boxGap)
            let box = MonitorBoxView(
                monitor: mon,
                frame: NSRect(x: x, y: bottomMargin, width: boxWidth, height: boxHeight)
            )
            addSubview(box)
            monitorBoxes.append(box)
        }

        let fallbackId = monitors.first?.aerospaceId ?? 1
        for ws in config.workspaces {
            let monId = assignments[ws.id].flatMap { mid in
                monitors.contains { $0.aerospaceId == mid } ? mid : nil
            } ?? fallbackId
            let chip = WorkspaceChipView(
                workspace: ws.id,
                color: config.color(for: ws.id),
                monitorId: monId,
                mapperView: self
            )
            addSubview(chip)
            chips.append(chip)
        }
        layoutChips()
    }

    func layoutChips() {
        let orphans = chips.filter { c in !monitorBoxes.contains(where: { $0.monitor.aerospaceId == c.monitorId }) }
        if !orphans.isEmpty, let firstBox = monitorBoxes.first {
            for c in orphans { c.monitorId = firstBox.monitor.aerospaceId }
        }
        for box in monitorBoxes {
            let inBox = chips.filter { $0.monitorId == box.monitor.aerospaceId }
            layoutChipsIn(box: box, chips: inBox)
        }
    }

    private func layoutChipsIn(box: MonitorBoxView, chips: [WorkspaceChipView]) {
        let chipW: CGFloat = 44, chipH: CGFloat = 44, gap: CGFloat = 8
        let area = box.chipArea
        let areaInSelf = NSRect(x: box.frame.origin.x + area.origin.x,
                                y: box.frame.origin.y + area.origin.y,
                                width: area.width, height: area.height)
        let perRow = max(1, Int((areaInSelf.width + gap) / (chipW + gap)))
        for (i, chip) in chips.enumerated() {
            let row = i / perRow
            let col = i % perRow
            let countInThisRow = min(chips.count - row * perRow, perRow)
            let rowW = CGFloat(countInThisRow) * chipW + CGFloat(countInThisRow - 1) * gap
            let startX = areaInSelf.origin.x + (areaInSelf.width - rowW) / 2
            let x = startX + CGFloat(col) * (chipW + gap)
            let y = areaInSelf.origin.y + areaInSelf.height - CGFloat(row + 1) * chipH - CGFloat(row) * gap
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                chip.animator().frame = NSRect(x: x, y: y, width: chipW, height: chipH)
            }
        }
    }

    func chipBeganDrag(_ chip: WorkspaceChipView) {
        guard let event = NSApp.currentEvent else { return }
        draggingChip = chip
        chip.setDragging(true)
        dragStartPointInSelf = convert(event.locationInWindow, from: nil)
        chipStartPoint = chip.frame.origin
        chip.layer?.zPosition = 100
    }

    func chipDragged(_ chip: WorkspaceChipView, event: NSEvent) {
        guard draggingChip == chip else { return }
        let pt = convert(event.locationInWindow, from: nil)
        let dx = pt.x - dragStartPointInSelf.x
        let dy = pt.y - dragStartPointInSelf.y
        chip.frame.origin = NSPoint(x: chipStartPoint.x + dx, y: chipStartPoint.y + dy)
        let center = NSPoint(x: chip.frame.midX, y: chip.frame.midY)
        for box in monitorBoxes { box.setHighlighted(box.frame.contains(center)) }
    }

    func chipEndedDrag(_ chip: WorkspaceChipView) {
        guard draggingChip == chip else { return }
        let center = NSPoint(x: chip.frame.midX, y: chip.frame.midY)
        if let target = monitorBoxes.first(where: { $0.frame.contains(center) }) {
            chip.monitorId = target.monitor.aerospaceId
        }
        for box in monitorBoxes { box.setHighlighted(false) }
        chip.setDragging(false)
        chip.layer?.zPosition = 0
        draggingChip = nil
        layoutChips()
    }

    @objc func applyPreset3() {
        guard monitors.count >= 3 else { flashMessage("Need at least 3 monitors"); return }
        let builtIn = monitors.first { $0.name.contains("Built-in") } ?? monitors[0]
        let externals = monitors.filter { $0.aerospaceId != builtIn.aerospaceId }
        guard externals.count >= 2 else { flashMessage("Need at least 2 externals"); return }
        // Split workspaces by position in config: first 2 → built-in, next 3 → primary, rest → secondary
        let ordered = config.workspaces.map { $0.id }
        var map: [String: Int] = [:]
        for (i, ws) in ordered.enumerated() {
            if i < 2                       { map[ws] = builtIn.aerospaceId }
            else if i < 5 || externals.count < 2 { map[ws] = externals[0].aerospaceId }
            else                           { map[ws] = externals[1].aerospaceId }
        }
        setAssignments(map)
    }

    @objc func applyPreset2() {
        guard monitors.count >= 2 else { flashMessage("Need at least 2 monitors"); return }
        let builtIn = monitors.first { $0.name.contains("Built-in") } ?? monitors[0]
        let external = monitors.first { $0.aerospaceId != builtIn.aerospaceId } ?? monitors[1]
        // Workspaces 2..4 (0-indexed) → external (B, C, D in default setup); rest → built-in
        var map: [String: Int] = [:]
        for (i, ws) in config.workspaces.enumerated() {
            map[ws.id] = (i >= 2 && i <= 4) ? external.aerospaceId : builtIn.aerospaceId
        }
        setAssignments(map)
    }

    @objc func applyPresetLaptop() {
        let target = monitors.first { $0.name.contains("Built-in") } ?? monitors.first
        guard let t = target else { return }
        var m: [String: Int] = [:]
        for ws in config.workspaces { m[ws.id] = t.aerospaceId }
        setAssignments(m)
    }

    private func setAssignments(_ map: [String: Int]) {
        for chip in chips {
            if let mid = map[chip.workspace],
               monitors.contains(where: { $0.aerospaceId == mid }) {
                chip.monitorId = mid
            }
        }
        layoutChips()
    }

    private var messageLabel: NSTextField?
    func flashMessage(_ text: String) {
        messageLabel?.removeFromSuperview()
        let lbl = NSTextField(labelWithString: text)
        lbl.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        lbl.textColor = Colors.red
        lbl.backgroundColor = .clear
        lbl.isBezeled = false
        lbl.isEditable = false
        lbl.sizeToFit()
        lbl.frame.origin = NSPoint(x: (bounds.width - lbl.frame.width) / 2, y: bounds.height - 20)
        addSubview(lbl)
        messageLabel = lbl
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.messageLabel == lbl { lbl.removeFromSuperview() }
        }
    }

    /// Apply monitor layout: move workspaces, regenerate sketchybar-map.sh, and
    /// return workspace→monitor-name so the caller can persist it.
    func applyMonitorLayout() -> [String: String] {
        var nameByWs: [String: String] = [:]
        for chip in chips {
            _ = shell("aerospace move-workspace-to-monitor --workspace \(chip.workspace) \(chip.monitorId)")
            if let mon = monitors.first(where: { $0.aerospaceId == chip.monitorId }) {
                nameByWs[chip.workspace] = mon.name
            }
        }
        regenerateSketchybarMap()
        return nameByWs
    }

    private func regenerateSketchybarMap() {
        var cases = ""
        for chip in chips {
            let mon = monitors.first { $0.aerospaceId == chip.monitorId }
            let sb = mon?.sketchybarIndex ?? 1
            cases += "        \(chip.workspace)) echo \(sb) ;;\n"
        }
        let content = """
        #!/bin/bash
        # Auto-generated by aerospace-control — do not edit manually.
        ws_to_sketchybar_display() {
            case "$1" in
        \(cases)        *) echo 1 ;;
            esac
        }
        """
        try? content.write(toFile: Paths.sketchybarMap, atomically: true, encoding: .utf8)
        _ = shell("chmod +x \(Paths.sketchybarMap)")
    }
}

// MARK: - Apps Tab
class AppRowView: NSView {
    let assignment: AppAssignment
    let isRunning: Bool
    let icon: NSImage?
    var workspaceChip: WorkspaceBadge!
    weak var appsTab: AppsTabView?
    override var mouseDownCanMoveWindow: Bool { false }

    init(frame: NSRect, assignment: AppAssignment, isRunning: Bool, icon: NSImage?, appsTab: AppsTabView) {
        self.assignment = assignment
        self.isRunning = isRunning
        self.icon = icon
        self.appsTab = appsTab
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = Colors.mantle.withAlphaComponent(0.5).cgColor

        // Icon
        let iconSize: CGFloat = 28
        let iconView = NSImageView(frame: NSRect(x: 10, y: (bounds.height - iconSize) / 2, width: iconSize, height: iconSize))
        iconView.image = icon ?? NSWorkspace.shared.icon(for: .applicationBundle)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.alphaValue = isRunning ? 1.0 : 0.5
        addSubview(iconView)

        // Running dot
        if isRunning {
            let dot = NSView(frame: NSRect(x: 32, y: (bounds.height - iconSize) / 2 - 1, width: 8, height: 8))
            dot.wantsLayer = true
            dot.layer?.backgroundColor = Colors.green.cgColor
            dot.layer?.cornerRadius = 4
            dot.layer?.borderWidth = 1.5
            dot.layer?.borderColor = Colors.base.cgColor
            addSubview(dot)
        }

        // Name
        let name = NSTextField(labelWithString: assignment.app_name)
        name.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        name.textColor = isRunning ? Colors.text : Colors.subtext0
        name.backgroundColor = .clear
        name.isBezeled = false
        name.isEditable = false
        name.lineBreakMode = .byTruncatingTail
        name.sizeToFit()
        name.frame = NSRect(x: 50, y: bounds.height / 2 + 2,
                            width: bounds.width - 50 - 80,
                            height: name.frame.height)
        addSubview(name)

        // Bundle ID (small)
        let bid = NSTextField(labelWithString: assignment.app_id)
        bid.font = NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        bid.textColor = Colors.overlay0
        bid.backgroundColor = .clear
        bid.isBezeled = false
        bid.isEditable = false
        bid.lineBreakMode = .byTruncatingTail
        bid.sizeToFit()
        bid.frame = NSRect(x: 50, y: bounds.height / 2 - 14,
                           width: bounds.width - 50 - 80,
                           height: bid.frame.height)
        addSubview(bid)

        // Workspace chip (right-aligned, clickable)
        workspaceChip = WorkspaceBadge(
            workspaceId: assignment.workspace,
            config: appsTab!.config,
            target: self,
            action: #selector(chipClicked)
        )
        workspaceChip.frame.origin = NSPoint(
            x: bounds.width - workspaceChip.frame.width - 10,
            y: (bounds.height - workspaceChip.frame.height) / 2
        )
        addSubview(workspaceChip)
    }

    @objc private func chipClicked() {
        appsTab?.showWorkspacePicker(for: self)
    }

    func updateWorkspace(_ wsId: String) {
        workspaceChip.removeFromSuperview()
        let newChip = WorkspaceBadge(
            workspaceId: wsId,
            config: appsTab!.config,
            target: self,
            action: #selector(chipClicked)
        )
        newChip.frame.origin = NSPoint(
            x: bounds.width - newChip.frame.width - 10,
            y: (bounds.height - newChip.frame.height) / 2
        )
        addSubview(newChip)
        workspaceChip = newChip
    }

    var chipScreenFrame: NSRect {
        return self.convert(workspaceChip.frame, to: nil)
    }
}

/// A small clickable badge used in app rows to show the workspace assignment.
class WorkspaceBadge: NSButton {
    let workspaceId: String
    override var mouseDownCanMoveWindow: Bool { false }

    init(workspaceId: String, config: AppConfig, target: AnyObject?, action: Selector) {
        self.workspaceId = workspaceId
        super.init(frame: NSRect(x: 0, y: 0, width: 64, height: 28))
        self.target = target
        self.action = action
        self.bezelStyle = .regularSquare
        self.isBordered = false
        self.wantsLayer = true
        self.layer?.cornerRadius = 8
        self.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
        self.title = workspaceId.isEmpty ? "—" : workspaceId

        if workspaceId.isEmpty {
            self.layer?.backgroundColor = Colors.surface0.cgColor
            self.layer?.borderWidth = 1
            self.layer?.borderColor = Colors.surface1.cgColor
            self.contentTintColor = Colors.overlay0
        } else {
            let color = config.color(for: workspaceId)
            self.layer?.backgroundColor = color.withAlphaComponent(0.22).cgColor
            self.layer?.borderWidth = 1.5
            self.layer?.borderColor = color.withAlphaComponent(0.7).cgColor
            self.contentTintColor = color
        }
    }
    required init?(coder: NSCoder) { fatalError() }
}

class AppsTabView: NSView {
    var config: AppConfig
    weak var rootView: RootView?
    private var scrollView: NSScrollView!
    private var docView: NSView!
    private var rows: [AppRowView] = []
    private var searchField: NSTextField!
    private var searchText: String = ""

    override var mouseDownCanMoveWindow: Bool { false }

    init(frame: NSRect, config: AppConfig) {
        self.config = config
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true

        // Subtitle
        let subtitle = NSTextField(labelWithString: "Click a workspace chip to (re)assign an app")
        subtitle.font = NSFont.systemFont(ofSize: 11)
        subtitle.textColor = Colors.subtext0
        subtitle.backgroundColor = .clear
        subtitle.isBezeled = false
        subtitle.isEditable = false
        subtitle.sizeToFit()
        subtitle.frame.origin = NSPoint(x: 24, y: bounds.height - 20)
        addSubview(subtitle)

        // Search field (top-right)
        searchField = NSTextField(frame: NSRect(x: bounds.width - 220, y: bounds.height - 28, width: 196, height: 24))
        searchField.placeholderString = "Filter apps…"
        searchField.font = NSFont.systemFont(ofSize: 11)
        searchField.bezelStyle = .roundedBezel
        searchField.focusRingType = .none
        searchField.target = self
        searchField.action = #selector(searchChanged)
        if let cell = searchField.cell as? NSTextFieldCell {
            cell.sendsActionOnEndEditing = false
        }
        // Also update live
        NotificationCenter.default.addObserver(self, selector: #selector(searchLiveChanged(_:)),
                                               name: NSControl.textDidChangeNotification, object: searchField)
        addSubview(searchField)

        // Scroll view
        scrollView = NSScrollView(frame: NSRect(x: 16, y: 16, width: bounds.width - 32, height: bounds.height - 48))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        addSubview(scrollView)

        docView = FlippedView(frame: NSRect(x: 0, y: 0, width: scrollView.frame.width, height: 0))
        scrollView.documentView = docView

        reloadRows()
    }

    @objc private func searchChanged(_ sender: NSTextField) {
        searchText = sender.stringValue
        reloadRows()
    }
    @objc private func searchLiveChanged(_ note: Notification) {
        searchText = searchField.stringValue
        reloadRows()
    }

    /// Rebuild the rows. Shows: apps in config + running apps not in config. Sorted: assigned (by workspace order), then running unassigned, then inactive.
    func reloadRows() {
        for r in rows { r.removeFromSuperview() }
        rows.removeAll()

        // Build combined list
        let running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let runningByBundleId: [String: NSRunningApplication] = Dictionary(
            uniqueKeysWithValues: running.compactMap { app in
                guard let bid = app.bundleIdentifier else { return nil }
                return (bid, app)
            }
        )

        var combined: [(assignment: AppAssignment, isRunning: Bool, icon: NSImage?)] = []
        var seen = Set<String>()
        for a in config.apps {
            seen.insert(a.app_id)
            let run = runningByBundleId[a.app_id]
            combined.append((a, run != nil, run?.icon))
        }
        for app in running {
            guard let bid = app.bundleIdentifier, !seen.contains(bid) else { continue }
            let a = AppAssignment(app_id: bid, app_name: app.localizedName ?? bid, workspace: "")
            combined.append((a, true, app.icon))
        }

        // Filter
        if !searchText.isEmpty {
            let needle = searchText.lowercased()
            combined = combined.filter {
                $0.assignment.app_name.lowercased().contains(needle) ||
                $0.assignment.app_id.lowercased().contains(needle)
            }
        }

        // Sort
        let wsOrder: [String: Int] = Dictionary(uniqueKeysWithValues: config.workspaces.enumerated().map { ($1.id, $0) })
        combined.sort { a, b in
            let aWs = wsOrder[a.assignment.workspace] ?? Int.max
            let bWs = wsOrder[b.assignment.workspace] ?? Int.max
            if aWs != bWs { return aWs < bWs }
            if a.isRunning != b.isRunning { return a.isRunning && !b.isRunning }
            return a.assignment.app_name.lowercased() < b.assignment.app_name.lowercased()
        }

        let rowH: CGFloat = 56, gap: CGFloat = 6
        let contentHeight = CGFloat(combined.count) * (rowH + gap) + 8
        docView.frame = NSRect(x: 0, y: 0, width: scrollView.frame.width, height: contentHeight)

        for (i, entry) in combined.enumerated() {
            let y = CGFloat(i) * (rowH + gap) + 4
            let row = AppRowView(
                frame: NSRect(x: 4, y: y, width: docView.frame.width - 8, height: rowH),
                assignment: entry.assignment,
                isRunning: entry.isRunning,
                icon: entry.icon,
                appsTab: self
            )
            docView.addSubview(row)
            rows.append(row)
        }
    }

    /// Show a popup menu to pick a workspace for the given app row.
    func showWorkspacePicker(for row: AppRowView) {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for ws in config.workspaces {
            let item = NSMenuItem(title: "\(ws.id)  —  \(ws.label ?? "")",
                                  action: #selector(pickWorkspace(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = ["row": row, "ws": ws.id] as [String: Any]
            menu.addItem(item)
        }
        menu.addItem(NSMenuItem.separator())
        let none = NSMenuItem(title: "None (unassigned)",
                              action: #selector(pickWorkspace(_:)), keyEquivalent: "")
        none.target = self
        none.representedObject = ["row": row, "ws": ""] as [String: Any]
        menu.addItem(none)

        // Show the menu below the chip
        let chipFrameInSelf = row.convert(row.workspaceChip.frame, to: self)
        let pt = NSPoint(x: chipFrameInSelf.origin.x, y: chipFrameInSelf.origin.y)
        menu.popUp(positioning: nil, at: pt, in: self)
    }

    @objc private func pickWorkspace(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let row = info["row"] as? AppRowView,
              let ws = info["ws"] as? String else { return }
        // Update the config
        if let idx = config.apps.firstIndex(where: { $0.app_id == row.assignment.app_id }) {
            if ws.isEmpty {
                config.apps.remove(at: idx)
            } else {
                config.apps[idx].workspace = ws
            }
        } else if !ws.isEmpty {
            config.apps.append(AppAssignment(
                app_id: row.assignment.app_id,
                app_name: row.assignment.app_name,
                workspace: ws
            ))
        }
        rootView?.configChanged(config)
        reloadRows()
    }
}

/// NSView that flips its coordinate system — useful for top-down lists in NSScrollView.
class FlippedView: NSView {
    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
}

// MARK: - Workspaces Tab

/// A single row in the Workspaces tab: colored letter badge + label input +
/// color picker + reorder buttons + delete button.
class WorkspaceRowView: NSView {
    var workspace: WorkspaceConfig
    weak var tab: WorkspacesTabView?
    private var badge: NSView!
    private var badgeLabel: NSTextField!
    private var idField: NSTextField!
    private var labelField: NSTextField!
    private var colorButton: NSButton!
    private var colorSwatch: NSView!

    override var mouseDownCanMoveWindow: Bool { false }

    init(frame: NSRect, workspace: WorkspaceConfig, tab: WorkspacesTabView) {
        self.workspace = workspace
        self.tab = tab
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = Colors.mantle.withAlphaComponent(0.5).cgColor

        let color = Colors.byName(workspace.color)

        // Reorder buttons (leftmost)
        let upBtn = makeIconButton(glyph: "▲", target: self, action: #selector(moveRowUp))
        upBtn.frame.origin = NSPoint(x: 8, y: bounds.height - upBtn.frame.height - 6)
        addSubview(upBtn)
        let dnBtn = makeIconButton(glyph: "▼", target: self, action: #selector(moveRowDown))
        dnBtn.frame.origin = NSPoint(x: 8, y: 6)
        addSubview(dnBtn)

        // Colored letter badge
        let badgeSize: CGFloat = 40
        badge = NSView(frame: NSRect(x: 40, y: (bounds.height - badgeSize) / 2, width: badgeSize, height: badgeSize))
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 10
        badge.layer?.backgroundColor = color.withAlphaComponent(0.2).cgColor
        badge.layer?.borderWidth = 1.5
        badge.layer?.borderColor = color.withAlphaComponent(0.7).cgColor
        addSubview(badge)

        badgeLabel = NSTextField(labelWithString: workspace.id)
        badgeLabel.font = NSFont.monospacedSystemFont(ofSize: 18, weight: .bold)
        badgeLabel.textColor = color
        badgeLabel.alignment = .center
        badgeLabel.backgroundColor = .clear
        badgeLabel.isBezeled = false
        badgeLabel.isEditable = false
        badgeLabel.sizeToFit()
        badgeLabel.frame = NSRect(
            x: (badgeSize - badgeLabel.frame.width) / 2,
            y: (badgeSize - badgeLabel.frame.height) / 2,
            width: badgeLabel.frame.width, height: badgeLabel.frame.height
        )
        badge.addSubview(badgeLabel)

        // Letter input
        idField = makeTextField(string: workspace.id, placeholder: "Key",
                                frame: NSRect(x: 92, y: (bounds.height - 26) / 2, width: 44, height: 26))
        idField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .bold)
        idField.alignment = .center
        idField.target = self
        idField.action = #selector(idChanged)
        idField.delegate = self
        addSubview(idField)

        // Label input
        labelField = makeTextField(string: workspace.label ?? "", placeholder: "Label",
                                   frame: NSRect(x: 144, y: (bounds.height - 26) / 2, width: 160, height: 26))
        labelField.font = NSFont.systemFont(ofSize: 12)
        labelField.target = self
        labelField.action = #selector(labelChanged)
        labelField.delegate = self
        addSubview(labelField)

        // Color picker
        colorButton = NSButton(frame: NSRect(x: 316, y: (bounds.height - 26) / 2, width: 110, height: 26))
        colorButton.bezelStyle = .regularSquare
        colorButton.isBordered = false
        colorButton.wantsLayer = true
        colorButton.layer?.cornerRadius = 8
        colorButton.layer?.backgroundColor = Colors.surface0.cgColor
        colorButton.layer?.borderWidth = 1
        colorButton.layer?.borderColor = Colors.surface1.cgColor
        colorButton.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        colorButton.contentTintColor = Colors.subtext1
        colorButton.title = "   \(workspace.color) ▼"
        colorButton.alignment = .left
        colorButton.target = self
        colorButton.action = #selector(pickColor)
        addSubview(colorButton)

        colorSwatch = NSView(frame: NSRect(x: 324, y: (bounds.height - 26) / 2 + 7, width: 12, height: 12))
        colorSwatch.wantsLayer = true
        colorSwatch.layer?.cornerRadius = 6
        colorSwatch.layer?.backgroundColor = color.cgColor
        addSubview(colorSwatch)

        // Delete button (right)
        let delBtn = NSButton(frame: NSRect(x: bounds.width - 40, y: (bounds.height - 26) / 2, width: 28, height: 26))
        delBtn.title = "🗑"
        delBtn.font = NSFont.systemFont(ofSize: 14)
        delBtn.bezelStyle = .regularSquare
        delBtn.isBordered = false
        delBtn.wantsLayer = true
        delBtn.layer?.cornerRadius = 8
        delBtn.layer?.backgroundColor = Colors.red.withAlphaComponent(0.15).cgColor
        delBtn.layer?.borderWidth = 1
        delBtn.layer?.borderColor = Colors.red.withAlphaComponent(0.5).cgColor
        delBtn.target = self
        delBtn.action = #selector(deleteWorkspace)
        addSubview(delBtn)
    }

    private func makeIconButton(glyph: String, target: AnyObject, action: Selector) -> NSButton {
        let btn = NSButton(frame: NSRect(x: 0, y: 0, width: 22, height: 18))
        btn.title = glyph
        btn.font = NSFont.systemFont(ofSize: 9)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 5
        btn.layer?.backgroundColor = Colors.surface0.cgColor
        btn.contentTintColor = Colors.subtext0
        btn.target = target
        btn.action = action
        return btn
    }

    private func makeTextField(string: String, placeholder: String, frame: NSRect) -> NSTextField {
        let tf = NSTextField(frame: frame)
        tf.stringValue = string
        tf.placeholderString = placeholder
        tf.bezelStyle = .roundedBezel
        tf.focusRingType = .none
        tf.drawsBackground = true
        tf.backgroundColor = Colors.surface0
        tf.textColor = Colors.text
        return tf
    }

    @objc private func moveRowUp()   { tab?.moveRow(self, delta: -1) }
    @objc private func moveRowDown() { tab?.moveRow(self, delta: +1) }
    @objc private func deleteWorkspace() { tab?.deleteRow(self) }

    @objc private func idChanged() {
        commitIdField()
    }
    @objc private func labelChanged() {
        workspace.label = labelField.stringValue.isEmpty ? nil : labelField.stringValue
        tab?.rowChanged(self)
    }

    @objc private func pickColor() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for name in ALL_COLOR_NAMES {
            let item = NSMenuItem(title: name, action: #selector(colorPicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = name
            item.image = colorSwatchImage(Colors.byName(name))
            menu.addItem(item)
        }
        let pt = NSPoint(x: colorButton.frame.origin.x, y: colorButton.frame.origin.y)
        menu.popUp(positioning: nil, at: pt, in: self)
    }

    @objc private func colorPicked(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        workspace.color = name
        refreshAppearance()
        tab?.rowChanged(self)
    }

    private func colorSwatchImage(_ color: NSColor) -> NSImage {
        let img = NSImage(size: NSSize(width: 14, height: 14))
        img.lockFocus()
        color.setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 14, height: 14), xRadius: 7, yRadius: 7).fill()
        img.unlockFocus()
        return img
    }

    private func refreshAppearance() {
        let color = Colors.byName(workspace.color)
        badge.layer?.backgroundColor = color.withAlphaComponent(0.2).cgColor
        badge.layer?.borderColor = color.withAlphaComponent(0.7).cgColor
        badgeLabel.textColor = color
        badgeLabel.stringValue = workspace.id
        badgeLabel.sizeToFit()
        badgeLabel.frame.origin = NSPoint(
            x: (badge.frame.width - badgeLabel.frame.width) / 2,
            y: (badge.frame.height - badgeLabel.frame.height) / 2
        )
        colorSwatch.layer?.backgroundColor = color.cgColor
        colorButton.title = "   \(workspace.color) ▼"
    }

    /// Commit the letter field after validating uniqueness and format.
    func commitIdField() {
        let raw = idField.stringValue.uppercased().prefix(1)
        let newId = String(raw)
        guard !newId.isEmpty, newId != workspace.id else {
            idField.stringValue = workspace.id
            return
        }
        if tab?.hasWorkspace(id: newId, excluding: workspace.id) == true {
            idField.stringValue = workspace.id
            tab?.flashMessage("Workspace \(newId) already exists")
            return
        }
        let oldId = workspace.id
        workspace.id = newId
        refreshAppearance()
        tab?.workspaceRenamed(oldId: oldId, newId: newId, row: self)
    }
}

extension WorkspaceRowView: NSTextFieldDelegate {
    func controlTextDidEndEditing(_ obj: Notification) {
        if obj.object as? NSTextField == idField {
            commitIdField()
        } else if obj.object as? NSTextField == labelField {
            workspace.label = labelField.stringValue.isEmpty ? nil : labelField.stringValue
            tab?.rowChanged(self)
        }
    }
}

class WorkspacesTabView: NSView {
    var config: AppConfig
    weak var rootView: RootView?
    private var scrollView: NSScrollView!
    private var docView: NSView!
    private var rows: [WorkspaceRowView] = []
    private var addButton: NSButton!

    override var mouseDownCanMoveWindow: Bool { false }

    init(frame: NSRect, config: AppConfig) {
        self.config = config
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true

        let subtitle = NSTextField(labelWithString: "Create, reorder, rename, recolor, or delete workspaces")
        subtitle.font = NSFont.systemFont(ofSize: 11)
        subtitle.textColor = Colors.subtext0
        subtitle.backgroundColor = .clear
        subtitle.isBezeled = false
        subtitle.isEditable = false
        subtitle.sizeToFit()
        subtitle.frame.origin = NSPoint(x: 24, y: bounds.height - 20)
        addSubview(subtitle)

        addButton = makeButton(title: "+  Add workspace", width: 140, height: 26,
                               color: Colors.green, accent: true,
                               target: self, action: #selector(addWorkspace))
        addButton.frame.origin = NSPoint(x: bounds.width - addButton.frame.width - 24, y: bounds.height - 30)
        addSubview(addButton)

        scrollView = NSScrollView(frame: NSRect(x: 16, y: 16, width: bounds.width - 32, height: bounds.height - 48))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        addSubview(scrollView)

        docView = FlippedView(frame: NSRect(x: 0, y: 0, width: scrollView.frame.width, height: 0))
        scrollView.documentView = docView

        rebuild()
    }

    private func rebuild() {
        for r in rows { r.removeFromSuperview() }
        rows.removeAll()

        let rowH: CGFloat = 54, gap: CGFloat = 6
        let total = CGFloat(config.workspaces.count) * (rowH + gap) + 8
        docView.frame = NSRect(x: 0, y: 0, width: scrollView.frame.width, height: total)

        for (i, ws) in config.workspaces.enumerated() {
            let y = CGFloat(i) * (rowH + gap) + 4
            let row = WorkspaceRowView(
                frame: NSRect(x: 4, y: y, width: docView.frame.width - 8, height: rowH),
                workspace: ws, tab: self
            )
            docView.addSubview(row)
            rows.append(row)
        }
    }

    func hasWorkspace(id: String, excluding: String) -> Bool {
        return config.workspaces.contains { $0.id == id && $0.id != excluding }
    }

    func rowChanged(_ row: WorkspaceRowView) {
        if let idx = config.workspaces.firstIndex(where: { $0.id == row.workspace.id }) {
            config.workspaces[idx] = row.workspace
        }
        rootView?.configChanged(config)
    }

    func workspaceRenamed(oldId: String, newId: String, row: WorkspaceRowView) {
        // Update config: workspace id AND any app assignments that reference it
        if let idx = config.workspaces.firstIndex(where: { $0.id == oldId }) {
            config.workspaces[idx].id = newId
        }
        for i in config.apps.indices where config.apps[i].workspace == oldId {
            config.apps[i].workspace = newId
        }
        rootView?.configChanged(config)
    }

    func moveRow(_ row: WorkspaceRowView, delta: Int) {
        guard let cur = config.workspaces.firstIndex(where: { $0.id == row.workspace.id }) else { return }
        let new = cur + delta
        guard new >= 0, new < config.workspaces.count else { return }
        config.workspaces.swapAt(cur, new)
        rootView?.configChanged(config)
        rebuild()
    }

    func deleteRow(_ row: WorkspaceRowView) {
        let id = row.workspace.id
        let affectedApps = config.apps.filter { $0.workspace == id }

        let alert = NSAlert()
        alert.messageText = "Delete workspace \(id)?"
        if affectedApps.isEmpty {
            alert.informativeText = "This will remove the workspace from your config."
        } else {
            let names = affectedApps.map { $0.app_name }.prefix(5).joined(separator: ", ")
            let more = affectedApps.count > 5 ? ", and \(affectedApps.count - 5) more" : ""
            alert.informativeText = "\(affectedApps.count) app(s) will become unassigned: \(names)\(more)"
        }
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            config.workspaces.removeAll { $0.id == id }
            for i in config.apps.indices where config.apps[i].workspace == id {
                config.apps[i].workspace = ""
            }
            rootView?.configChanged(config)
            rebuild()
        }
    }

    @objc func addWorkspace() {
        // Pick first unused uppercase letter A..Z
        let used = Set(config.workspaces.map { $0.id })
        let candidate = (UnicodeScalar("A").value...UnicodeScalar("Z").value)
            .compactMap { UnicodeScalar($0).map { String($0) } }
            .first { !used.contains($0) } ?? "X"
        // Pick first unused color
        let usedColors = Set(config.workspaces.map { $0.color })
        let color = ALL_COLOR_NAMES.first { !usedColors.contains($0) } ?? "mauve"
        let new = WorkspaceConfig(id: candidate, color: color, label: nil)
        config.workspaces.append(new)
        rootView?.configChanged(config)
        rebuild()
        // Scroll to the bottom so the new row is visible
        if let doc = scrollView.documentView {
            doc.scroll(NSPoint(x: 0, y: doc.frame.height))
        }
    }

    private var messageLabel: NSTextField?
    func flashMessage(_ text: String) {
        messageLabel?.removeFromSuperview()
        let lbl = NSTextField(labelWithString: text)
        lbl.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        lbl.textColor = Colors.red
        lbl.backgroundColor = .clear
        lbl.isBezeled = false
        lbl.isEditable = false
        lbl.sizeToFit()
        lbl.frame.origin = NSPoint(x: (bounds.width - lbl.frame.width) / 2, y: bounds.height - 40)
        addSubview(lbl)
        messageLabel = lbl
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.messageLabel == lbl { lbl.removeFromSuperview() }
        }
    }
}

// MARK: - Root View (tab bar + current tab + apply/cancel)
class RootView: NSView, TabBarDelegate {
    var config: AppConfig
    let monitors: [MonitorInfo]
    private var tabBar: TabBarView!
    private var monitorsTab: MonitorsTabView!
    private var appsTab: AppsTabView!
    private var workspacesTab: WorkspacesTabView!
    private var tabContainer: NSView!

    override var mouseDownCanMoveWindow: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    init(frame: NSRect, config: AppConfig, monitors: [MonitorInfo]) {
        self.config = config
        self.monitors = monitors
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 20
        layer?.backgroundColor = Colors.base.cgColor
        layer?.borderWidth = 2
        layer?.borderColor = Colors.mauve.withAlphaComponent(0.5).cgColor

        let glow = CAGradientLayer()
        glow.frame = NSRect(x: 0, y: bounds.height - 80, width: bounds.width, height: 80)
        glow.cornerRadius = 20
        glow.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        glow.colors = [Colors.mauve.withAlphaComponent(0.08).cgColor, NSColor.clear.cgColor]
        glow.startPoint = CGPoint(x: 0.5, y: 1)
        glow.endPoint = CGPoint(x: 0.5, y: 0)
        layer?.addSublayer(glow)

        // Title
        let title = NSTextField(labelWithString: "AeroSpace Control")
        title.font = NSFont.systemFont(ofSize: 16, weight: .bold)
        title.textColor = Colors.text
        title.backgroundColor = .clear
        title.isBezeled = false
        title.isEditable = false
        title.sizeToFit()
        title.frame.origin = NSPoint(x: 24, y: bounds.height - 34)
        addSubview(title)

        // Tab bar (centered below title)
        tabBar = TabBarView(tabs: ["Monitors", "Apps", "Workspaces"],
                            frame: NSRect(x: 0, y: bounds.height - 76, width: bounds.width, height: 36))
        tabBar.delegate = self
        addSubview(tabBar)

        // Tab container
        let topY: CGFloat = 64      // space reserved for buttons+hint at bottom
        let containerH = bounds.height - 76 - topY
        tabContainer = NSView(frame: NSRect(x: 0, y: topY, width: bounds.width, height: containerH))
        addSubview(tabContainer)

        let innerFrame = NSRect(x: 0, y: 0, width: bounds.width, height: containerH)
        monitorsTab = MonitorsTabView(frame: innerFrame, config: config)
        appsTab = AppsTabView(frame: innerFrame, config: config)
        workspacesTab = WorkspacesTabView(frame: innerFrame, config: config)
        appsTab.rootView = self
        workspacesTab.rootView = self

        // Prefer the saved layout for this exact monitor signature; fall back to
        // whatever AeroSpace currently has assigned.
        let assignments = config.savedAssignments(for: monitors)
            ?? detectCurrentAssignments(workspaces: config.workspaces.map { $0.id })
        monitorsTab.setup(monitors: monitors, assignments: assignments)

        tabContainer.addSubview(monitorsTab)

        // Apply + Cancel buttons
        let applyBtn = makeButton(title: "Apply ⏎", width: 88, height: 30, color: Colors.green, accent: true, target: self, action: #selector(apply))
        applyBtn.frame.origin = NSPoint(x: bounds.width - applyBtn.frame.width - 24, y: 16)
        addSubview(applyBtn)

        let cancelBtn = makeButton(title: "Cancel ⎋", width: 80, height: 30, color: Colors.overlay0, target: self, action: #selector(cancel))
        cancelBtn.frame.origin = NSPoint(x: applyBtn.frame.origin.x - cancelBtn.frame.width - 8, y: 16)
        addSubview(cancelBtn)

        let hints = NSTextField(labelWithString: "⏎ Apply · ⎋ Cancel · ⌘1/⌘2/⌘3 Switch tabs")
        hints.font = NSFont.systemFont(ofSize: 10)
        hints.textColor = Colors.overlay0
        hints.backgroundColor = .clear
        hints.isBezeled = false
        hints.isEditable = false
        hints.sizeToFit()
        hints.frame.origin = NSPoint(x: 24, y: 24)
        addSubview(hints)
    }

    func configChanged(_ newConfig: AppConfig) {
        self.config = newConfig
        monitorsTab.config = newConfig
        appsTab.config = newConfig
        workspacesTab.config = newConfig

        // Rebuild monitors tab so chips reflect any added/removed/renamed/recolored workspaces.
        // Preserve current in-memory monitor assignments where possible so the user's drag-drop state survives.
        var assignments: [String: Int] = [:]
        for chip in monitorsTab.chips where newConfig.hasWorkspace(chip.workspace) {
            assignments[chip.workspace] = chip.monitorId
        }
        // New workspaces (not yet assigned) default to the current monitor-tab fallback (first monitor).
        monitorsTab.setup(monitors: monitors, assignments: assignments)

        // Apps tab is rebuilt lazily on tab switch, but if it's currently visible, reload now.
        if tabContainer.subviews.contains(appsTab) { appsTab.reloadRows() }
    }

    func tabBar(_ bar: TabBarView, didSelectTab index: Int) {
        for sub in tabContainer.subviews { sub.removeFromSuperview() }
        let tab: NSView
        switch index {
        case 0: tab = monitorsTab
        case 1: tab = appsTab; appsTab.reloadRows()
        case 2: tab = workspacesTab
        default: tab = monitorsTab
        }
        tabContainer.addSubview(tab)
    }

    @objc func apply() {
        // Move workspaces between monitors first so we can capture the layout (workspace→monitor-name)
        let layout = monitorsTab.applyMonitorLayout()
        // Persist the layout under the current monitor signature so it auto-restores next time
        let sig = monitorSignature(monitors)
        if config.monitor_layouts == nil { config.monitor_layouts = [:] }
        config.monitor_layouts![sig] = layout
        // Save config to disk (source of truth)
        ConfigManager.save(config)
        // Regenerate marker-wrapped sections in every consuming file
        Generators.regenerateAll(config)
        // Reload aerospace so the new on-window-detected rules are live
        Generators.reloadAerospace()
        // Move existing windows to their (possibly new) assigned workspaces
        Generators.runResetWindows()
        // Hard-restart sketchybar if enabled (reload leaves duplicate items behind)
        Generators.reloadSketchybar(config)
        _ = shell("osascript -e 'display notification \"Configuration applied\" with title \"AeroSpace Control\"'")
        // Use exit(0) instead of NSApp.terminate so we don't depend on the run-loop
        // delivering an applicationShouldTerminate cycle (which can hang under
        // exec-and-forget). atexit handler still removes the PID file.
        exit(0)
    }

    @objc func cancel() {
        exit(0)
    }

    override func keyDown(with event: NSEvent) {
        let cmd = event.modifierFlags.contains(.command)
        switch event.keyCode {
        case 36, 76: apply()
        case 53:     cancel()
        case 18 where cmd: tabBar.select(index: 0)
        case 19 where cmd: tabBar.select(index: 1)
        case 20 where cmd: tabBar.select(index: 2)
        default:     super.keyDown(with: event)
        }
    }
}

// MARK: - Window
class MapperWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - Headless layout application
/// Apply a workspace→monitor-name layout via aerospace and regenerate the
/// per-workspace sketchybar display map. Used by --auto and the screen watcher.
func applyLayoutHeadless(layout: [String: String], monitors: [MonitorInfo]) {
    var skbCases = ""
    for (ws, monName) in layout {
        if let mon = monitors.first(where: { $0.name == monName }) {
            _ = shell("aerospace move-workspace-to-monitor --workspace \(ws) \(mon.aerospaceId) 2>/dev/null")
            skbCases += "        \(ws)) echo \(mon.sketchybarIndex) ;;\n"
        }
    }
    let content = """
    #!/bin/bash
    # Auto-generated by aerospace-control --auto — do not edit manually.
    ws_to_sketchybar_display() {
        case "$1" in
    \(skbCases)        *) echo 1 ;;
        esac
    }
    """
    try? content.write(toFile: Paths.sketchybarMap, atomically: true, encoding: .utf8)
    _ = shell("chmod +x \(Paths.sketchybarMap)")
}

/// Compute a sensible default layout when no saved layout exists for the current monitor signature.
/// Matches the GUI's preset logic: 2/3/rest split for 3+ monitors, 2..4 split for 2 monitors, all-on-builtin for 1.
func defaultLayoutFor(workspaces: [WorkspaceConfig], monitors: [MonitorInfo]) -> [String: String] {
    var layout: [String: String] = [:]
    guard !monitors.isEmpty, !workspaces.isEmpty else { return layout }
    let builtIn = monitors.first { $0.name.contains("Built-in") } ?? monitors[0]
    let externals = monitors.filter { $0.aerospaceId != builtIn.aerospaceId }

    for (i, ws) in workspaces.enumerated() {
        let target: MonitorInfo
        if externals.count >= 2 {
            if i < 2                    { target = builtIn }
            else if i < 5               { target = externals[0] }
            else                        { target = externals[1] }
        } else if externals.count == 1 {
            target = (i >= 2 && i <= 4) ? externals[0] : builtIn
        } else {
            target = builtIn
        }
        layout[ws.id] = target.name
    }
    return layout
}

/// Run a single auto-restore cycle: detect monitors, restore saved layout (or apply+save default).
func runAutoRestore() {
    var cfg = ConfigManager.load()
    let mons = detectMonitors()
    guard !mons.isEmpty else { return }
    let sig = monitorSignature(mons)

    let layout: [String: String]
    if let saved = cfg.monitor_layouts?[sig] {
        layout = saved
    } else {
        layout = defaultLayoutFor(workspaces: cfg.workspaces, monitors: mons)
        if cfg.monitor_layouts == nil { cfg.monitor_layouts = [:] }
        cfg.monitor_layouts![sig] = layout
        ConfigManager.save(cfg)
    }
    applyLayoutHeadless(layout: layout, monitors: mons)
}

// MARK: - Main
let args = CommandLine.arguments

// --version: print version and exit (used by package managers).
if args.contains("--version") || args.contains("-v") {
    print("aerospace-control \(AC_VERSION)")
    exit(0)
}

// --setup: idempotent first-run setup. Creates config dir, default config,
// inserts marker blocks into aerospace.toml. Safe to run repeatedly.
if args.contains("--setup") {
    _ = ConfigManager.load()           // creates default config if missing
    Bootstrap.ensureAerospaceMarkers() // inserts markers if missing
    let cfg = ConfigManager.load()
    Generators.regenerateAll(cfg)      // writes initial generated files
    print("aerospace-control: setup complete.")
    print("  config: \(Paths.configFile)")
    print("  markers ensured in: \(Paths.aerospaceToml)")
    exit(0)
}

// --auto: headless one-shot. Restore saved layout for the current monitor combination
// (or apply a default + save it). Exits without showing UI.
if args.contains("--auto") {
    runAutoRestore()
    exit(0)
}

// --watch: long-running daemon. Listens for screen changes and re-applies whenever
// the monitor combination changes. Used as a launch-agent or a background process.
if args.contains("--watch") {
    let watcherApp = NSApplication.shared
    watcherApp.setActivationPolicy(.accessory)
    runAutoRestore()  // initial pass
    var lastSignature = monitorSignature(detectMonitors())
    NotificationCenter.default.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification,
        object: nil, queue: .main
    ) { _ in
        // Debounce: macOS fires this multiple times during connect/disconnect.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            let sig = monitorSignature(detectMonitors())
            guard sig != lastSignature else { return }
            lastSignature = sig
            runAutoRestore()
        }
    }
    watcherApp.run()
    exit(0)
}

// MARK: - Singleton (one GUI window at a time)
// Each `ctrl-alt-r` press spawns a new process via aerospace's `exec-and-forget`,
// so without this check multiple windows stack and steal each other's events.
let GUI_PID_FILE = "/tmp/aerospace-control-gui.pid"

func anotherGuiInstanceRunning() -> Bool {
    guard let content = try? String(contentsOfFile: GUI_PID_FILE, encoding: .utf8),
          let pid = pid_t(content.trimmingCharacters(in: .whitespacesAndNewlines)),
          pid != ProcessInfo.processInfo.processIdentifier,
          kill(pid, 0) == 0 else { return false }
    return true
}

func writeGuiPidFile() {
    let pid = "\(ProcessInfo.processInfo.processIdentifier)"
    try? pid.write(toFile: GUI_PID_FILE, atomically: true, encoding: .utf8)
}

@_cdecl("ac_remove_gui_pid_file")
func ac_remove_gui_pid_file() {
    try? FileManager.default.removeItem(atPath: GUI_PID_FILE)
}

if anotherGuiInstanceRunning() {
    NSLog("aerospace-control: another GUI instance is already running, exiting.")
    exit(0)
}
writeGuiPidFile()
atexit(ac_remove_gui_pid_file)
// Also clean up on Ctrl-C / SIGTERM
signal(SIGINT)  { _ in ac_remove_gui_pid_file(); exit(0) }
signal(SIGTERM) { _ in ac_remove_gui_pid_file(); exit(0) }

let app = NSApplication.shared
app.setActivationPolicy(.regular)

// Idempotent bootstrap on every GUI launch — cheap, and handles the case where
// the user installed via package manager and is launching for the first time.
Bootstrap.ensureAerospaceMarkers()

let config = ConfigManager.load()
let monitors = detectMonitors()

let mouseLocation = NSEvent.mouseLocation
let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main!
let screenFrame = screen.frame

let monitorCount = max(monitors.count, 1)
let width: CGFloat = min(max(CGFloat(monitorCount) * 220 + 120, 680), screenFrame.width - 40)
let height: CGFloat = 520
let x = screenFrame.origin.x + (screenFrame.width - width) / 2
let y = screenFrame.origin.y + (screenFrame.height - height) / 2

let window = MapperWindow(
    contentRect: NSRect(x: x, y: y, width: width, height: height),
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
)
// Use .screenSaver level: with .floating, sketchybar's bar (also floating-class)
// or other window-manager overlays can sit on top and absorb mouse events,
// making the GUI appear unresponsive even though the run-loop is healthy.
window.level = .screenSaver
window.isOpaque = false
window.backgroundColor = .clear
window.hasShadow = true
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
window.acceptsMouseMovedEvents = true

let root = RootView(frame: NSRect(x: 0, y: 0, width: width, height: height), config: config, monitors: monitors)
window.contentView = root
window.makeFirstResponder(root)
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)

// AeroSpace re-asserts focus right after exec-and-forget spawns us, so a single
// activate() call can get overridden. Re-activate across the first 1.5 seconds
// until the window is actually key.
let activationDeadline = Date().addingTimeInterval(1.5)
func nudgeActivation() {
    guard Date() < activationDeadline, !window.isKeyWindow else { return }
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: nudgeActivation)
}
DispatchQueue.main.async(execute: nudgeActivation)

// Only intercept keyDown when it's one of the global shortcuts AND no text field has focus.
// Otherwise let the event flow normally so NSTextFields can receive typing.
NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
    // If a text field (or its field editor) has focus, never intercept.
    if let responder = NSApp.keyWindow?.firstResponder,
       responder is NSText || responder is NSTextField {
        return event
    }
    let cmd = event.modifierFlags.contains(.command)
    let kc = event.keyCode
    let isShortcut = (kc == 36 || kc == 76 || kc == 53) ||                   // Enter / Esc
                     (cmd && (kc == 18 || kc == 19 || kc == 20))             // ⌘1 / ⌘2 / ⌘3
    if isShortcut {
        root.keyDown(with: event)
        return nil
    }
    return event
}

// Hide the Dock icon shortly after launch — the window stays floating + key.
// Note: we used to also auto-dismiss on app deactivation, but that interacted
// badly with NSAlert confirmations and `aerospace exec-and-forget`'s focus
// quirks. Esc / Cancel / Apply are enough.
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
    NSApp.setActivationPolicy(.accessory)
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}

app.run()
