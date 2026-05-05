import AppKit

let AC_VERSION = "0.1.0"

// MARK: - Theme system
/// Helper: hex literals like 0x1e1e2e + alpha → NSColor.
private func hex(_ rgb: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(red: CGFloat((rgb >> 16) & 0xff)/255,
            green: CGFloat((rgb >> 8) & 0xff)/255,
            blue: CGFloat(rgb & 0xff)/255,
            alpha: alpha)
}

/// All colors a theme provides. The neutral slots (crust..text) drive the
/// chrome; the named accents (mauve..sky) are the workspace-color palette
/// the user picks from.
struct Theme {
    let name: String
    let crust, mantle, base, surface0, surface1, surface2: NSColor
    let overlay0, subtext0, subtext1, text: NSColor
    let pink, mauve, lavender, sapphire, blue, teal, green, peach, red, yellow, sky: NSColor

    func colorByName(_ name: String) -> NSColor {
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

enum Themes {
    static let catppuccinMocha = Theme(
        name:     "catppuccin-mocha",
        crust:    hex(0x11111b),
        mantle:   hex(0x181825),
        base:     hex(0x1e1e2e, 0.97),
        surface0: hex(0x313244),
        surface1: hex(0x45475a),
        surface2: hex(0x585b70),
        overlay0: hex(0x6c7086),
        subtext0: hex(0xa6adc8),
        subtext1: hex(0xbac2de),
        text:     hex(0xcdd6f4),
        pink:     hex(0xf5c2e7),
        mauve:    hex(0xcba6f7),
        lavender: hex(0xb4befe),
        sapphire: hex(0x74c7ec),
        blue:     hex(0x89b4fa),
        teal:     hex(0x94e2d5),
        green:    hex(0xa6e3a1),
        peach:    hex(0xfab387),
        red:      hex(0xf38ba8),
        yellow:   hex(0xf9e2af),
        sky:      hex(0x89dceb)
    )

    /// Inspired by a moonlit Japanese landscape: deep midnight navy, sakura
    /// pink, torii vermillion, cool moonlight white, faint aurora cyan.
    static let midnightTorii = Theme(
        name:     "midnight-torii",
        crust:    hex(0x05071a),
        mantle:   hex(0x0a0e26),
        base:     hex(0x10153a, 0.97),
        surface0: hex(0x1c2451),
        surface1: hex(0x2c386f),
        surface2: hex(0x3f4d8c),
        overlay0: hex(0x5969a5),
        subtext0: hex(0x8c98c4),
        subtext1: hex(0xb5beda),
        text:     hex(0xe6ebff),
        pink:     hex(0xe89bc6),
        mauve:    hex(0xb39bff),
        lavender: hex(0xa1b3ff),
        sapphire: hex(0x6dabf0),
        blue:     hex(0x5b8def),
        teal:     hex(0x74d0d6),
        green:    hex(0x7be0a4),
        peach:    hex(0xefc498),
        red:      hex(0xd44a5e),
        yellow:   hex(0xf3e7a3),
        sky:      hex(0xa8d8ee)
    )

    /// Mutable runtime selection. Defaults to catppuccin-mocha; main() updates
    /// from config.json before any UI is built.
    static var current: Theme = catppuccinMocha

    static let all: [Theme] = [catppuccinMocha, midnightTorii]

    static func byName(_ name: String) -> Theme? {
        all.first { $0.name == name }
    }
}

/// Backward-compatible facade — every site that already reads `Colors.mauve`,
/// `Colors.surface1`, etc continues to work; values now resolve through the
/// active theme at access time.
enum Colors {
    static var crust:    NSColor { Themes.current.crust }
    static var mantle:   NSColor { Themes.current.mantle }
    static var base:     NSColor { Themes.current.base }
    static var surface0: NSColor { Themes.current.surface0 }
    static var surface1: NSColor { Themes.current.surface1 }
    static var surface2: NSColor { Themes.current.surface2 }
    static var overlay0: NSColor { Themes.current.overlay0 }
    static var subtext0: NSColor { Themes.current.subtext0 }
    static var subtext1: NSColor { Themes.current.subtext1 }
    static var text:     NSColor { Themes.current.text }
    static var pink:     NSColor { Themes.current.pink }
    static var mauve:    NSColor { Themes.current.mauve }
    static var lavender: NSColor { Themes.current.lavender }
    static var sapphire: NSColor { Themes.current.sapphire }
    static var blue:     NSColor { Themes.current.blue }
    static var teal:     NSColor { Themes.current.teal }
    static var green:    NSColor { Themes.current.green }
    static var peach:    NSColor { Themes.current.peach }
    static var red:      NSColor { Themes.current.red }
    static var yellow:   NSColor { Themes.current.yellow }
    static var sky:      NSColor { Themes.current.sky }

    static func byName(_ name: String) -> NSColor { Themes.current.colorByName(name) }
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
    // launchd starts our daemon with a minimal PATH that omits the homebrew
    // bin directories — without this, `aerospace` and `sketchybar` aren't
    // findable when --watch / --auto runs from a LaunchAgent.
    var env = ProcessInfo.processInfo.environment
    let extras = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
    let existing = (env["PATH"] ?? "").split(separator: ":").map(String.init)
    let merged = (extras + existing).reduce(into: [String]()) { acc, p in
        if !acc.contains(p) { acc.append(p) }
    }
    env["PATH"] = merged.joined(separator: ":")
    task.environment = env
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

/// Inner / outer gap values written into aerospace.toml's `[gaps]` section. All
/// fields are optional so a partially-configured monitor uses the default for
/// the missing sides.
struct MonitorPadding: Codable {
    var top: Int?
    var right: Int?
    var bottom: Int?
    var left: Int?
}

/// Preferences tab state. All fields are optional so older config files load
/// cleanly and missing values fall back to documented defaults.
struct PreferencesConfig: Codable {
    /// `tiles` or `accordion` (matches aerospace's `default-root-container-layout`).
    var default_layout: String?
    /// `auto`, `horizontal`, or `vertical` (matches aerospace's
    /// `default-root-container-orientation`).
    var default_orientation: String?
    /// Inner gap (between tiled windows).
    var inner_horizontal: Int?
    var inner_vertical: Int?
    /// Per-monitor outer gaps (keyed by monitor name). When set, the gaps
    /// marker block is regenerated and the user's inline `[gaps]` section
    /// (if any) is migrated into the marker.
    var monitor_padding: [String: MonitorPadding]?
    /// Default outer gap for monitors without an explicit override.
    var default_outer: MonitorPadding?
    /// Generate `alt-shift-backtick = "exec-and-forget …reset-windows.sh"`.
    var reset_windows_binding: Bool?
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
    /// GUI color theme name (one of `Themes.all`). Default: catppuccin-mocha.
    var theme: String?
    /// Optional override of the `sketchybar --bar display=N` number per monitor.
    /// Keyed by monitor signature (sorted names joined with `|`) so each unique
    /// monitor combination has its own mapping — sketchybar's display indices
    /// depend on which monitors are currently connected. If the auto-detected
    /// number routes the bar to the wrong physical screen for a given combo,
    /// add an entry here:
    ///
    ///     "sketchybar_displays": {
    ///         "Built-in Retina Display|L27h-4A|LG Ultra HD": {
    ///             "Built-in Retina Display": 1,
    ///             "L27h-4A": 2,
    ///             "LG Ultra HD": 3
    ///         }
    ///     }
    var sketchybar_displays: [String: [String: Int]]?

    /// Layout, gaps, and toggles surfaced in the Preferences tab. Optional so
    /// existing config files load without migration.
    var preferences: PreferencesConfig?

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
    /// Create a minimal valid aerospace.toml when none exists, including the
    /// `[mode.main.binding]` section, the launcher binding, and the marker
    /// blocks we manage. Without this, fresh installs (where the user hasn't
    /// run AeroSpace yet) fail with "Unknown top-level key" the moment they
    /// paste our keybinding outside any binding section.
    static func ensureAerospaceTomlExists() {
        let path = Paths.aerospaceToml
        if FileManager.default.fileExists(atPath: path) { return }
        // Resolve installed binary path (absolute, symlinks resolved) so the
        // generated keybinding works regardless of $PATH.
        let argv0 = CommandLine.arguments.first ?? "aerospace-control"
        let resolved = (try? FileManager.default
            .destinationOfSymbolicLink(atPath: argv0)) ?? argv0
        let binary = resolved.hasPrefix("/")
            ? resolved
            : URL(fileURLWithPath: argv0).standardizedFileURL.path
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir,
                                                 withIntermediateDirectories: true)
        let template = """
        # aerospace.toml — generated by aerospace-control on first install.
        # Edit freely; the BEGIN/END GENERATED blocks below are managed by
        # aerospace-control and will be rewritten on each Apply.
        #
        # See https://nikitabobko.github.io/AeroSpace/guide for full docs.

        start-at-login = true
        enable-normalization-flatten-containers = true
        enable-normalization-opposite-orientation-for-nested-containers = true

        # Restore the saved layout for the current monitor combination on login.
        # `sleep 2` lets aerospace finish starting before we ask it for monitors.
        after-startup-command = [
          "exec-and-forget sleep 2 && \(binary) --auto",
        ]

        # === BEGIN GENERATED: preferences ===
        # === END GENERATED: preferences ===

        [mode.main.binding]
        # Launch the aerospace-control GUI
        ctrl-alt-r = "exec-and-forget \(binary)"

        # === BEGIN GENERATED: workspace-bindings ===
        # === END GENERATED: workspace-bindings ===

        # === BEGIN GENERATED: app-assignments ===
        # === END GENERATED: app-assignments ===
        """
        try? template.write(toFile: path, atomically: true, encoding: .utf8)
        NSLog("[bootstrap] created default aerospace.toml at \(path)")
    }

    /// Ensure aerospace's `after-startup-command` includes our `--auto` entry,
    /// so layouts restore on login. Handles three shapes:
    ///   1. No `after-startup-command` anywhere → append a top-level entry.
    ///   2. Empty array `after-startup-command = []` → replace.
    ///   3. Existing array (single or multi-line) → insert our entry inside if
    ///      not already present. Skip silently when our line is already there.
    /// Idempotent.
    static func ensureAfterStartupCommand() -> Bool {
        let path = Paths.aerospaceToml
        guard var text = try? String(contentsOfFile: path, encoding: .utf8) else { return false }
        // Build the entry against the actual installed binary path so the user
        // doesn't have to edit it.
        let argv0 = CommandLine.arguments.first ?? "aerospace-control"
        let resolved = (try? FileManager.default
            .destinationOfSymbolicLink(atPath: argv0)) ?? argv0
        let binary = resolved.hasPrefix("/")
            ? resolved
            : URL(fileURLWithPath: argv0).standardizedFileURL.path
        let entry = "\"exec-and-forget sleep 2 && \(binary) --auto\""

        // Already wired up — no-op. Match by `aerospace-control --auto`
        // (path-agnostic) so an existing `~/.local/bin/aerospace-control --auto`
        // entry isn't duplicated when our resolved path expands the tilde.
        if text.contains("aerospace-control --auto") { return false }

        // Find a top-level `after-startup-command = [` (regex tolerates spaces).
        let pattern = #"(?m)^\s*after-startup-command\s*=\s*\["#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let nsText = text as NSString
        if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) {
            // Find matching `]` after the opening bracket.
            let openIdx = match.range.location + match.range.length - 1  // index of `[`
            var depth = 1
            var i = openIdx + 1
            while i < nsText.length && depth > 0 {
                let ch = nsText.substring(with: NSRange(location: i, length: 1))
                if ch == "[" { depth += 1 }
                if ch == "]" { depth -= 1 }
                if depth == 0 { break }
                i += 1
            }
            if depth != 0 { return false }
            let closeIdx = i
            let arrayBody = nsText.substring(with: NSRange(location: openIdx + 1,
                                                          length: closeIdx - openIdx - 1))
            let trimmed = arrayBody.trimmingCharacters(in: .whitespacesAndNewlines)
            let inserted: String
            if trimmed.isEmpty {
                inserted = "\n  \(entry),\n"
            } else if trimmed.hasSuffix(",") {
                inserted = "\(arrayBody)\n  \(entry),\n"
            } else {
                inserted = "\(arrayBody),\n  \(entry),\n"
            }
            let newRange = NSRange(location: openIdx + 1, length: closeIdx - openIdx - 1)
            text = nsText.replacingCharacters(in: newRange, with: inserted)
            try? text.write(toFile: path, atomically: true, encoding: .utf8)
            NSLog("[bootstrap] added --auto entry to existing after-startup-command")
            return true
        }
        // Not present at all — append a fresh top-level array.
        let block = """

        # Restore the saved layout for the current monitor combination on login.
        after-startup-command = [
          \(entry),
        ]

        """
        text += block
        try? text.write(toFile: path, atomically: true, encoding: .utf8)
        NSLog("[bootstrap] inserted new after-startup-command")
        return true
    }

    /// Comment out a managed binding key (e.g. `alt-shift-backtick`) when it
    /// appears OUTSIDE the workspace-bindings marker. We add the same key
    /// inside the marker on toggle-on, and TOML rejects duplicates.
    /// Idempotent — already-commented lines are skipped.
    static func migrateConflictingBinding(_ key: String) {
        let path = Paths.aerospaceToml
        guard var text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        let beginMarker = "# === BEGIN GENERATED: workspace-bindings ==="
        let endMarker   = "# === END GENERATED: workspace-bindings ==="
        var lines = text.components(separatedBy: "\n")
        var insideMarker = false
        var commented = false
        for i in 0..<lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed == beginMarker { insideMarker = true; continue }
            if trimmed == endMarker   { insideMarker = false; continue }
            if insideMarker { continue }
            if trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix(key) && trimmed.dropFirst(key.count).first.map(\.isLetter) != true {
                lines[i] = "# [aerospace-control] migrated → workspace-bindings marker:  " + lines[i]
                commented = true
            }
        }
        if commented {
            text = lines.joined(separator: "\n")
            try? text.write(toFile: path, atomically: true, encoding: .utf8)
            NSLog("[bootstrap] migrated conflicting `\(key)` binding")
        }
    }

    static func ensureAerospaceMarkers() {
        ensureAerospaceTomlExists()
        _ = ensureAfterStartupCommand()
        // Always migrate keys we generate so toggling them later in the GUI
        // doesn't produce TOML duplicates.
        migrateConflictingBinding("alt-shift-backtick")
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

        // preferences marker — top-level layout/orientation/gaps. Must land
        // BEFORE any `[section]` header in the file: TOML scopes bare keys
        // under the most recent table, so `default-root-container-layout = …`
        // placed after `[gaps]` becomes `gaps.default-root-container-layout`
        // and aerospace rejects it.
        if !text.contains("# === BEGIN GENERATED: preferences ===") {
            // First, comment out any pre-existing top-level keys we manage so
            // they don't TOML-clash with our generated equivalents on first
            // GUI Apply. Idempotent — already-commented lines are skipped.
            let managed = ["default-root-container-layout",
                          "default-root-container-orientation"]
            var lines = text.components(separatedBy: "\n")
            var commented = false
            for i in 0..<lines.count {
                let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("#") { continue }
                for key in managed where trimmed.hasPrefix(key) {
                    lines[i] = "# [aerospace-control] migrated → preferences marker:  " + lines[i]
                    commented = true
                    break
                }
            }
            if commented { text = lines.joined(separator: "\n") }

            let block = "\n# === BEGIN GENERATED: preferences ===\n# === END GENERATED: preferences ===\n\n"
            // Find the first top-level `[…]` line.
            var insertAt: String.Index = text.endIndex
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("[") && t.hasSuffix("]") {
                    if let r = text.range(of: String(line)) { insertAt = r.lowerBound }
                    break
                }
            }
            text.insert(contentsOf: block, at: insertAt)
            changed = true
        }

        if changed {
            try? text.write(toFile: path, atomically: true, encoding: .utf8)
            NSLog("[bootstrap] inserted marker blocks into aerospace.toml")
        }
    }

    /// Comment out an inline `[gaps]` table when the user enables managed
    /// padding from the Preferences tab. TOML rejects duplicate keys (our
    /// generated `gaps.outer.top = …` would clash with `[gaps]\nouter.top = …`)
    /// so we leave the user's old values commented out for reference and emit
    /// the managed equivalent inside the preferences marker block.
    static func migrateInlineGapsIfNeeded() {
        let path = Paths.aerospaceToml
        guard var text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        // Find a top-level `[gaps]` header (not `[gaps.something]` and not
        // inside a comment).
        let lines = text.components(separatedBy: "\n")
        guard let headerIdx = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "[gaps]" }) else {
            return
        }
        // Find end: next top-level `[…]` header or EOF.
        var endIdx = lines.count
        for j in (headerIdx + 1)..<lines.count {
            let t = lines[j].trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("[") && t.hasSuffix("]") { endIdx = j; break }
        }
        var migrated = lines
        let banner = "# [aerospace-control] gaps below were migrated into the managed `preferences` marker block above."
        migrated.insert(banner, at: headerIdx)
        for k in (headerIdx + 1)..<(endIdx + 1) {
            let line = migrated[k]
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            if line.hasPrefix("#") { continue }
            migrated[k] = "# " + line
        }
        text = migrated.joined(separator: "\n")
        try? text.write(toFile: path, atomically: true, encoding: .utf8)
        NSLog("[bootstrap] migrated inline [gaps] into preferences marker")
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
        // Opt-in: alt-shift-backtick → run our reset-windows script. Adds the
        // binding inside the SAME [mode.main.binding] block as the per-workspace
        // bindings so users don't have to wire it up by hand.
        if config.preferences?.reset_windows_binding == true {
            lines.append("alt-shift-backtick = 'exec-and-forget \(Paths.resetWindowsSh)'")
        }
        replaceSection(file: Paths.aerospaceToml, marker: "workspace-bindings",
                       newBody: lines.joined(separator: "\n"))
    }

    /// Default-layout / orientation / gaps. Lives at the top level of
    /// aerospace.toml, so it must be regenerated whenever the user touches
    /// Preferences. Uses dot-notation (`gaps.outer.top = …`) to avoid
    /// conflicting with any inline `[gaps]` table the user might still have.
    static func regenerateAerospacePreferences(_ config: AppConfig) {
        var lines = [GEN_HEADER]

        let p = config.preferences

        // Layout + orientation. Only emit when explicitly set so we don't fight
        // any user-edited values outside the marker.
        if let layout = p?.default_layout {
            lines.append("default-root-container-layout = '\(layout)'")
        }
        if let orient = p?.default_orientation {
            lines.append("default-root-container-orientation = '\(orient)'")
        }

        // Inner gaps.
        if let h = p?.inner_horizontal { lines.append("gaps.inner.horizontal = \(h)") }
        if let v = p?.inner_vertical   { lines.append("gaps.inner.vertical   = \(v)") }

        // Outer gaps. Each side gets a per-monitor list (`[{ monitor.X = N }, …, default]`)
        // when overrides exist; otherwise falls back to a single value.
        let perMon = p?.monitor_padding ?? [:]
        let dflt   = p?.default_outer
        for (side, defaultValue) in [
            ("top",    dflt?.top),
            ("right",  dflt?.right),
            ("bottom", dflt?.bottom),
            ("left",   dflt?.left),
        ] {
            // Collect per-monitor values for this side.
            let entries: [(String, Int)] = perMon.compactMap { (name, pad) in
                let v: Int?
                switch side {
                case "top":    v = pad.top
                case "right":  v = pad.right
                case "bottom": v = pad.bottom
                case "left":   v = pad.left
                default:       v = nil
                }
                return v.map { (name, $0) }
            }.sorted { $0.0 < $1.0 }
            // Skip the side entirely if neither default nor any override is set.
            if entries.isEmpty && defaultValue == nil { continue }
            if entries.isEmpty {
                lines.append("gaps.outer.\(side) = \(defaultValue!)")
            } else {
                let parts = entries.map { "{ monitor.\"\($0.0)\" = \($0.1) }" }
                let trailing = defaultValue.map(String.init) ?? "0"
                lines.append("gaps.outer.\(side) = [\(parts.joined(separator: ", ")), \(trailing)]")
            }
        }

        replaceSection(file: Paths.aerospaceToml, marker: "preferences",
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

    /// Convert an NSColor to sketchybar's `0xAARRGGBB` hex literal.
    static func sketchybarHex(_ color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = Int((c.redComponent   * 255).rounded())
        let g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent  * 255).rounded())
        return String(format: "0xFF%02x%02x%02x", r, g, b)
    }

    /// Bash-sourceable `ws_color` function for sketchybar integrations. Colors
    /// are sourced from the active theme so switching themes propagates.
    static func regenerateWorkspaceColorsShell(_ config: AppConfig) {
        var cases = ""
        for ws in config.workspaces {
            let code = sketchybarHex(Colors.byName(ws.color))
            cases += "        \(ws.id)) echo \(code) ;;\n"
        }
        let fallback = sketchybarHex(Colors.mauve)
        let content = """
        #!/bin/bash
        \(GEN_HEADER)
        ws_color() {
            case "$1" in
        \(cases)        *) echo \(fallback) ;;
            esac
        }
        """
        try? content.write(toFile: Paths.colorsSh, atomically: true, encoding: .utf8)
        _ = shell("chmod +x \(Paths.colorsSh)")
    }

    // ── Sketchybar (opt-in) ─────────────────────────────────────────────────

    /// Rewrite SPACE_ICONS / SPACE_COLORS in sketchybarrc, but only if the user
    /// added the marker block themselves (we never modify their file unsolicited).
    /// Emits raw hex so the active theme drives the bar colors directly,
    /// independent of whatever $MAUVE/$BLUE the user has defined elsewhere.
    static func regenerateSketchybarWorkspaces(_ config: AppConfig) {
        guard config.sketchybar?.enabled == true else { return }
        let ids = config.workspaces.map { "\"\($0.id)\"" }.joined(separator: " ")
        let colors = config.workspaces
            .map { sketchybarHex(Colors.byName($0.color)) }
            .joined(separator: " ")
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
        regenerateAerospacePreferences(config)
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

    // Pass 1: parse aerospace's monitor list and match each to an NSScreen.
    struct Raw { let aid: Int; let name: String; let screen: NSScreen? }
    var raw: [Raw] = []
    for line in output.components(separatedBy: "\n") where !line.isEmpty {
        let parts = line.components(separatedBy: " | ")
        guard parts.count >= 2,
              let aid = Int(parts[0].trimmingCharacters(in: .whitespaces)) else { continue }
        let name = parts[1].trimmingCharacters(in: .whitespaces)
        let screen = screens.first { s in
            if #available(macOS 10.15, *) { return s.localizedName == name }
            return false
        }
        raw.append(Raw(aid: aid, name: name, screen: screen))
    }

    // Look up per-signature override map (monitor name → sketchybar index)
    // for the current monitor combination, falling back to {} if absent.
    let signature = raw.map { $0.name }.sorted().joined(separator: "|")
    let cfg = try? JSONDecoder().decode(AppConfig.self,
        from: Data(contentsOf: URL(fileURLWithPath: Paths.configFile)))
    let overrides: [String: Int] = cfg?.sketchybar_displays?[signature] ?? [:]

    // Auto-detection fallback uses CGGetActiveDisplayList — its order isn't
    // guaranteed to match sketchybar's display-arrangement order (sketchybar
    // doesn't expose its order via any public API), so the user can override.
    var displayCount: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &displayCount)
    var cgDisplays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
    CGGetActiveDisplayList(displayCount, &cgDisplays, &displayCount)

    func autoSketchybarIdx(for screen: NSScreen) -> Int? {
        guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        let did = CGDirectDisplayID(num.uint32Value)
        return cgDisplays.firstIndex(of: did).map { $0 + 1 }
    }

    var result: [MonitorInfo] = []
    for r in raw {
        let sbIdx: Int = overrides[r.name]
            ?? r.screen.flatMap(autoSketchybarIdx)
            ?? screens.firstIndex(where: { $0 == r.screen }).map { $0 + 1 }
            ?? r.aid
        let px = r.screen?.frame.origin.x ?? CGFloat(r.aid) * 10000
        result.append(MonitorInfo(aerospaceId: r.aid, name: r.name, screen: r.screen,
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

    /// Hover popover (lazy). Built on first hover and reused.
    private var hoverPopover: NSPopover?
    /// Pending hover-show task; cancellable on early mouseExited.
    private var pendingHoverWork: DispatchWorkItem?

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

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for ta in trackingAreas { removeTrackingArea(ta) }
        let opts: NSTrackingArea.Options = [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect]
        addTrackingArea(NSTrackingArea(rect: bounds, options: opts, owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        // Slight delay so quick fly-bys don't pop. Cancelled by mouseExited.
        let work = DispatchWorkItem { [weak self] in self?.showHoverPopover() }
        pendingHoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    override func mouseExited(with event: NSEvent) {
        pendingHoverWork?.cancel()
        pendingHoverWork = nil
        hoverPopover?.close()
    }

    private func showHoverPopover() {
        guard let cfg = mapperView?.config else { return }
        let assigned = cfg.apps.filter { $0.workspace == workspace }
        // Build content view: header (workspace label) + each app row.
        let rowH: CGFloat = 22, pad: CGFloat = 10
        let contentW: CGFloat = 220
        let rows = max(assigned.count, 1)
        let contentH = pad * 2 + 22 /*header*/ + CGFloat(rows) * rowH
        let content = NSView(frame: NSRect(x: 0, y: 0, width: contentW, height: contentH))
        content.wantsLayer = true
        content.layer?.backgroundColor = Colors.surface0.cgColor

        // Header
        let header = NSTextField(labelWithString: cfg.workspaces.first { $0.id == workspace }?.label.flatMap { $0.isEmpty ? nil : "\(workspace) · \($0)" } ?? "Workspace \(workspace)")
        header.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        header.textColor = color
        header.backgroundColor = .clear
        header.isBezeled = false
        header.isEditable = false
        header.frame = NSRect(x: pad, y: contentH - pad - 18, width: contentW - 2 * pad, height: 18)
        content.addSubview(header)

        if assigned.isEmpty {
            let none = NSTextField(labelWithString: "No apps assigned")
            none.font = NSFont.systemFont(ofSize: 11)
            none.textColor = Colors.subtext0
            none.backgroundColor = .clear
            none.isBezeled = false
            none.isEditable = false
            none.frame = NSRect(x: pad, y: contentH - pad - 18 - rowH, width: contentW - 2 * pad, height: rowH)
            content.addSubview(none)
        } else {
            for (i, app) in assigned.enumerated() {
                let y = contentH - pad - 18 - CGFloat(i + 1) * rowH
                let iv = NSImageView(frame: NSRect(x: pad, y: y + 2, width: 18, height: 18))
                iv.image = NSWorkspace.shared.icon(forFile:
                    NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.app_id)?.path ?? "")
                iv.imageScaling = .scaleProportionallyDown
                content.addSubview(iv)

                let lbl = NSTextField(labelWithString: app.app_name)
                lbl.font = NSFont.systemFont(ofSize: 11)
                lbl.textColor = Colors.text
                lbl.backgroundColor = .clear
                lbl.isBezeled = false
                lbl.isEditable = false
                lbl.lineBreakMode = .byTruncatingTail
                lbl.frame = NSRect(x: pad + 24, y: y + 2, width: contentW - pad * 2 - 24, height: rowH - 4)
                content.addSubview(lbl)
            }
        }

        let vc = NSViewController()
        vc.view = content
        let pop = NSPopover()
        pop.behavior = .transient
        pop.contentSize = content.frame.size
        pop.contentViewController = vc
        hoverPopover = pop
        pop.show(relativeTo: bounds, of: self, preferredEdge: .minY)
    }

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

// MARK: - Preferences Tab

/// One of the six layout tiles in the layout picker. Visually represents an
/// (orientation × layout) combination — the user clicks a tile and we write
/// `default-root-container-layout` + `default-root-container-orientation`
/// into the preferences marker.
class LayoutTileView: NSView {
    let layout: String        // "tiles" | "accordion"
    let orientation: String   // "horizontal" | "vertical" | "auto"
    let title: String
    weak var prefsTab: PreferencesTabView?
    private(set) var isSelected: Bool = false

    override var mouseDownCanMoveWindow: Bool { false }

    init(frame: NSRect, layout: String, orientation: String, title: String, prefsTab: PreferencesTabView) {
        self.layout = layout
        self.orientation = orientation
        self.title = title
        self.prefsTab = prefsTab
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = Colors.surface0.cgColor
        layer?.borderWidth = 1.5
        layer?.borderColor = Colors.surface1.cgColor

        // Title underneath the preview.
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        label.textColor = Colors.subtext1
        label.backgroundColor = .clear
        label.isBezeled = false
        label.alignment = .center
        label.frame = NSRect(x: 0, y: 6, width: bounds.width, height: 14)
        label.autoresizingMask = [.width]
        addSubview(label)
    }
    required init?(coder: NSCoder) { fatalError() }

    func setSelected(_ s: Bool) {
        isSelected = s
        layer?.borderColor = s ? Colors.mauve.cgColor : Colors.surface1.cgColor
        layer?.borderWidth = s ? 2.5 : 1.5
        layer?.backgroundColor = (s ? Colors.surface1 : Colors.surface0).cgColor
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        prefsTab?.layoutTileTapped(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let canvas = NSRect(x: 14, y: 26, width: bounds.width - 28, height: bounds.height - 40)
        // Outer rounded card frame.
        let outer = NSBezierPath(roundedRect: canvas, xRadius: 8, yRadius: 8)
        Colors.base.setFill()
        outer.fill()
        Colors.surface2.setStroke()
        outer.lineWidth = 1
        outer.stroke()
        // Two "windows" rendered per the layout × orientation combination.
        let pad: CGFloat = 6
        let inset = canvas.insetBy(dx: pad, dy: pad)
        let pinkFill = Colors.pink.withAlphaComponent(0.7)
        let blueFill = Colors.sapphire.withAlphaComponent(0.7)
        switch (layout, orientation) {
        case ("tiles", "horizontal"):
            let half = (inset.width - pad) / 2
            drawWindow(rect: NSRect(x: inset.minX, y: inset.minY, width: half, height: inset.height), fill: pinkFill)
            drawWindow(rect: NSRect(x: inset.minX + half + pad, y: inset.minY, width: half, height: inset.height), fill: blueFill)
        case ("tiles", "vertical"):
            let half = (inset.height - pad) / 2
            drawWindow(rect: NSRect(x: inset.minX, y: inset.minY + half + pad, width: inset.width, height: half), fill: pinkFill)
            drawWindow(rect: NSRect(x: inset.minX, y: inset.minY, width: inset.width, height: half), fill: blueFill)
        case ("tiles", "auto"):
            // Wider canvas → horizontal split (matches aerospace's auto rule).
            let half = (inset.width - pad) / 2
            drawWindow(rect: NSRect(x: inset.minX, y: inset.minY, width: half, height: inset.height), fill: pinkFill)
            drawWindow(rect: NSRect(x: inset.minX + half + pad, y: inset.minY, width: half, height: inset.height), fill: blueFill)
        case ("accordion", "horizontal"):
            // Stack: front blue covering most width, pink peeking from left.
            drawWindow(rect: NSRect(x: inset.minX, y: inset.minY, width: 8, height: inset.height), fill: pinkFill)
            drawWindow(rect: NSRect(x: inset.minX + 14, y: inset.minY, width: inset.width - 14, height: inset.height), fill: blueFill)
        case ("accordion", "vertical"):
            // Stack: blue covers most height, pink peeking from bottom.
            drawWindow(rect: NSRect(x: inset.minX, y: inset.minY, width: inset.width, height: 8), fill: pinkFill)
            drawWindow(rect: NSRect(x: inset.minX, y: inset.minY + 14, width: inset.width, height: inset.height - 14), fill: blueFill)
        default: // accordion auto → vertical for tall, horizontal for wide; we draw horizontal stack
            drawWindow(rect: NSRect(x: inset.minX, y: inset.minY, width: 8, height: inset.height), fill: pinkFill)
            drawWindow(rect: NSRect(x: inset.minX + 14, y: inset.minY, width: inset.width - 14, height: inset.height), fill: blueFill)
        }
    }

    private func drawWindow(rect: NSRect, fill: NSColor) {
        let p = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        fill.setFill()
        p.fill()
    }
}

class PreferencesTabView: NSView {
    var config: AppConfig
    weak var rootView: RootView?
    let monitors: [MonitorInfo]
    private var layoutTiles: [LayoutTileView] = []
    private var resetToggle: NSButton!
    private var paddingFields: [String: [String: NSTextField]] = [:]  // [monitorName][side] → field
    private var defaultPaddingFields: [String: NSTextField] = [:]      // side → field

    override var mouseDownCanMoveWindow: Bool { false }

    init(frame: NSRect, config: AppConfig, monitors: [MonitorInfo]) {
        self.config = config
        self.monitors = monitors
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true

        let subtitle = NSTextField(labelWithString: "Layout, padding, and other tweaks. Changes save and reload AeroSpace immediately.")
        subtitle.font = NSFont.systemFont(ofSize: 11)
        subtitle.textColor = Colors.subtext0
        subtitle.backgroundColor = .clear
        subtitle.isBezeled = false
        subtitle.isEditable = false
        subtitle.sizeToFit()
        subtitle.frame.origin = NSPoint(x: 24, y: bounds.height - 20)
        addSubview(subtitle)

        let scroll = NSScrollView(frame: NSRect(x: 16, y: 16, width: bounds.width - 32, height: bounds.height - 48))
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        addSubview(scroll)

        let docView = FlippedView(frame: NSRect(x: 0, y: 0, width: scroll.frame.width, height: 0))
        scroll.documentView = docView

        var y: CGFloat = 8

        // ── Section: Default layout ──────────────────────────────────────
        y = addSectionHeader("Default layout", in: docView, y: y)

        let combos: [(String, String, String)] = [
            ("tiles",     "horizontal", "Tiles · ⇋"),
            ("tiles",     "vertical",   "Tiles · ⇅"),
            ("tiles",     "auto",       "Tiles · auto"),
            ("accordion", "horizontal", "Accordion · ⇋"),
            ("accordion", "vertical",   "Accordion · ⇅"),
            ("accordion", "auto",       "Accordion · auto"),
        ]
        let cols = 3
        let cardW: CGFloat = 140, cardH: CGFloat = 110, gap: CGFloat = 12
        let totalW = CGFloat(cols) * cardW + CGFloat(cols - 1) * gap
        let originX = (docView.frame.width - totalW) / 2
        let curLayout = config.preferences?.default_layout ?? "tiles"
        let curOrient = config.preferences?.default_orientation ?? "auto"
        for (idx, combo) in combos.enumerated() {
            let row = idx / cols
            let col = idx % cols
            let frame = NSRect(x: originX + CGFloat(col) * (cardW + gap),
                               y: y + CGFloat(row) * (cardH + gap),
                               width: cardW, height: cardH)
            let tile = LayoutTileView(frame: frame, layout: combo.0,
                                      orientation: combo.1, title: combo.2,
                                      prefsTab: self)
            tile.setSelected(combo.0 == curLayout && combo.1 == curOrient)
            docView.addSubview(tile)
            layoutTiles.append(tile)
        }
        y += CGFloat((combos.count + cols - 1) / cols) * (cardH + gap) + 16

        // ── Section: Toggles ─────────────────────────────────────────────
        y = addSectionHeader("Keybindings", in: docView, y: y)
        resetToggle = NSButton(checkboxWithTitle: "  alt+shift+`  →  reset all windows to assigned workspaces",
                               target: self, action: #selector(resetToggleChanged(_:)))
        resetToggle.state = (config.preferences?.reset_windows_binding == true) ? .on : .off
        // contentTintColor doesn't paint the checkbox label — use attributedTitle
        // so the text actually renders against the dark background.
        resetToggle.attributedTitle = NSAttributedString(
            string: resetToggle.title,
            attributes: [
                .foregroundColor: Colors.text,
                .font: NSFont.systemFont(ofSize: 12),
            ])
        resetToggle.frame = NSRect(x: 24, y: y, width: docView.frame.width - 48, height: 22)
        docView.addSubview(resetToggle)
        y += 30

        // ── Section: Padding (per monitor) ───────────────────────────────
        y = addSectionHeader("Window padding", in: docView, y: y)
        let helpLabel = NSTextField(labelWithString: "Outer gaps in pixels. Each monitor can override the default. Hot-reloads on edit.")
        helpLabel.font = NSFont.systemFont(ofSize: 10)
        helpLabel.textColor = Colors.subtext0
        helpLabel.backgroundColor = .clear
        helpLabel.isBezeled = false
        helpLabel.isEditable = false
        helpLabel.sizeToFit()
        helpLabel.frame.origin = NSPoint(x: 24, y: y)
        docView.addSubview(helpLabel)
        y += 22

        // Default row first.
        y = addPaddingRow(name: "Default (all monitors)", monitorName: nil,
                         padding: config.preferences?.default_outer ?? MonitorPadding(top: 30, right: 30, bottom: 30, left: 30),
                         in: docView, y: y)

        for mon in monitors {
            let pad = config.preferences?.monitor_padding?[mon.name]
            y = addPaddingRow(name: mon.name, monitorName: mon.name,
                             padding: pad ?? MonitorPadding(top: nil, right: nil, bottom: nil, left: nil),
                             in: docView, y: y)
        }

        y += 16
        docView.frame.size.height = y
    }

    private func addSectionHeader(_ text: String, in docView: NSView, y: CGFloat) -> CGFloat {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = Colors.text
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.sizeToFit()
        label.frame.origin = NSPoint(x: 24, y: y)
        docView.addSubview(label)
        return y + 26
    }

    private func addPaddingRow(name: String, monitorName: String?, padding: MonitorPadding,
                               in docView: NSView, y: CGFloat) -> CGFloat {
        let labelWidth: CGFloat = 220
        let label = NSTextField(labelWithString: name)
        label.font = NSFont.systemFont(ofSize: 11, weight: monitorName == nil ? .semibold : .regular)
        label.textColor = monitorName == nil ? Colors.subtext1 : Colors.text
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.frame = NSRect(x: 24, y: y + 2, width: labelWidth, height: 18)
        docView.addSubview(label)

        var x: CGFloat = 24 + labelWidth
        var fields: [String: NSTextField] = [:]
        for (side, value) in [
            ("top",    padding.top),
            ("right",  padding.right),
            ("bottom", padding.bottom),
            ("left",   padding.left),
        ] {
            let cap = NSTextField(labelWithString: side)
            cap.font = NSFont.systemFont(ofSize: 9)
            cap.textColor = Colors.subtext0
            cap.backgroundColor = .clear
            cap.isBezeled = false
            cap.isEditable = false
            cap.frame = NSRect(x: x, y: y + 22, width: 50, height: 12)
            docView.addSubview(cap)

            let f = NSTextField(frame: NSRect(x: x, y: y, width: 56, height: 22))
            f.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            f.alignment = .center
            f.bezelStyle = .roundedBezel
            f.focusRingType = .none
            f.placeholderString = monitorName == nil ? "30" : "—"
            f.stringValue = value.map(String.init) ?? ""
            f.target = self
            f.action = #selector(paddingChanged(_:))
            f.identifier = NSUserInterfaceItemIdentifier("padding|\(monitorName ?? "")|\(side)")
            NotificationCenter.default.addObserver(self, selector: #selector(paddingLiveChanged(_:)),
                                                   name: NSControl.textDidEndEditingNotification, object: f)
            docView.addSubview(f)
            fields[side] = f
            x += 64
        }

        if let mn = monitorName {
            paddingFields[mn] = fields
        } else {
            defaultPaddingFields = fields
        }
        return y + 44
    }

    func layoutTileTapped(_ tile: LayoutTileView) {
        for t in layoutTiles { t.setSelected(t === tile) }
        ensurePrefs()
        config.preferences?.default_layout = tile.layout
        config.preferences?.default_orientation = tile.orientation
        commit()
        // aerospace's `default-root-container-layout` only applies to NEW
        // workspaces — existing ones stay on whatever layout they were created
        // with. Re-tile every workspace right now so the user sees the change
        // they just clicked.
        retileAllWorkspaces(layout: tile.layout, orientation: tile.orientation)
    }

    private func retileAllWorkspaces(layout: String, orientation: String) {
        // aerospace's `layout` command operates on the focused container. To
        // hit every workspace we briefly switch focus to each in turn, run the
        // layout command, then return to the originally focused workspace.
        // Single-argument orientations only — "auto" maps to "horizontal" for
        // the live reflow (the actual auto behavior continues to apply to new
        // workspaces via the marker block we just wrote).
        let liveOrient = (orientation == "auto") ? "horizontal" : orientation
        let originalWS = shell("aerospace list-workspaces --focused 2>&1")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let allOut = shell("aerospace list-workspaces --all 2>&1")
        let workspaces = allOut
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for ws in workspaces {
            _ = shell("aerospace workspace \(ws) 2>&1")
            _ = shell("aerospace flatten-workspace-tree 2>&1")
            _ = shell("aerospace layout \(layout) \(liveOrient) 2>&1")
        }
        if !originalWS.isEmpty {
            _ = shell("aerospace workspace \(originalWS) 2>&1")
        }
    }

    @objc func resetToggleChanged(_ sender: NSButton) {
        ensurePrefs()
        config.preferences?.reset_windows_binding = (sender.state == .on)
        // If the user already has an `alt-shift-backtick` binding outside our
        // marker (eg. pointing at the legacy reset_windows.sh path), comment
        // it out so our generated copy doesn't TOML-clash.
        if sender.state == .on {
            Bootstrap.migrateConflictingBinding("alt-shift-backtick")
        }
        commit()
    }

    @objc func paddingChanged(_ sender: NSTextField) { applyPaddingFromFields() }
    @objc func paddingLiveChanged(_ note: Notification) { applyPaddingFromFields() }

    private func applyPaddingFromFields() {
        ensurePrefs()
        // Default outer gaps.
        var d = config.preferences?.default_outer ?? MonitorPadding()
        d.top    = parsePad(defaultPaddingFields["top"])    ?? d.top
        d.right  = parsePad(defaultPaddingFields["right"])  ?? d.right
        d.bottom = parsePad(defaultPaddingFields["bottom"]) ?? d.bottom
        d.left   = parsePad(defaultPaddingFields["left"])   ?? d.left
        config.preferences?.default_outer = d

        // Per-monitor overrides. Empty string clears the override.
        var perMon = config.preferences?.monitor_padding ?? [:]
        for (mon, fields) in paddingFields {
            var p = perMon[mon] ?? MonitorPadding()
            p.top    = parsePad(fields["top"])
            p.right  = parsePad(fields["right"])
            p.bottom = parsePad(fields["bottom"])
            p.left   = parsePad(fields["left"])
            // Drop entry entirely if all sides are nil.
            if p.top == nil && p.right == nil && p.bottom == nil && p.left == nil {
                perMon.removeValue(forKey: mon)
            } else {
                perMon[mon] = p
            }
        }
        config.preferences?.monitor_padding = perMon
        // First-time padding adoption: migrate any inline `[gaps]` table out
        // of the way so our generated `gaps.outer.top = …` doesn't TOML-clash.
        Bootstrap.migrateInlineGapsIfNeeded()
        commit()
    }

    private func parsePad(_ field: NSTextField?) -> Int? {
        let s = field?.stringValue.trimmingCharacters(in: .whitespaces) ?? ""
        if s.isEmpty { return nil }
        return Int(s)
    }

    private func ensurePrefs() {
        if config.preferences == nil {
            config.preferences = PreferencesConfig()
        }
    }

    /// Save + regenerate + reload — the "hot reload" the Preferences tab
    /// promises. Stays local to this tab so toggling a checkbox doesn't have
    /// to wait for the user to press Apply.
    private func commit() {
        ConfigManager.save(config)
        Generators.regenerateAll(config)
        Generators.reloadAerospace()
        rootView?.preferencesChanged(config)
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
    private var preferencesTab: PreferencesTabView!
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

        // Theme picker (top-right of header). Click to pop a menu of available
        // themes; selecting one saves to config and re-launches with the new
        // theme applied.
        let themeBtn = NSButton(frame: NSRect(x: 0, y: 0, width: 0, height: 26))
        themeBtn.title = "🎨 \(Themes.current.name)  ▾"
        themeBtn.bezelStyle = .regularSquare
        themeBtn.isBordered = false
        themeBtn.wantsLayer = true
        themeBtn.layer?.cornerRadius = 8
        themeBtn.layer?.backgroundColor = Colors.surface0.cgColor
        themeBtn.layer?.borderWidth = 1
        themeBtn.layer?.borderColor = Colors.surface1.cgColor
        themeBtn.contentTintColor = Colors.subtext1
        themeBtn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        themeBtn.target = self
        themeBtn.action = #selector(showThemeMenu(_:))
        themeBtn.sizeToFit()
        themeBtn.frame.size.width += 16
        themeBtn.frame.size.height = 26
        themeBtn.frame.origin = NSPoint(x: bounds.width - themeBtn.frame.width - 24,
                                        y: bounds.height - 32)
        addSubview(themeBtn)

        // Tab bar (centered below title)
        tabBar = TabBarView(tabs: ["Monitors", "Apps", "Workspaces", "Preferences"],
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
        preferencesTab = PreferencesTabView(frame: innerFrame, config: config, monitors: monitors)
        appsTab.rootView = self
        workspacesTab.rootView = self
        preferencesTab.rootView = self

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

        let hints = NSTextField(labelWithString: "⏎ Apply · ⎋ Cancel · ⌘1/⌘2/⌘3/⌘4 Switch tabs")
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
        preferencesTab.config = newConfig

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

    /// Hot-reload from the Preferences tab — config is already saved to disk
    /// and aerospace.toml regenerated; we just need to update in-memory state
    /// and rebuild any visible tab whose state derives from preferences.
    func preferencesChanged(_ newConfig: AppConfig) {
        self.config = newConfig
        monitorsTab.config = newConfig
        appsTab.config = newConfig
        workspacesTab.config = newConfig
    }

    func tabBar(_ bar: TabBarView, didSelectTab index: Int) {
        for sub in tabContainer.subviews { sub.removeFromSuperview() }
        let tab: NSView
        switch index {
        case 0: tab = monitorsTab
        case 1: tab = appsTab; appsTab.reloadRows()
        case 2: tab = workspacesTab
        case 3: tab = preferencesTab
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

    @objc func showThemeMenu(_ sender: NSButton) {
        let menu = NSMenu()
        for theme in Themes.all {
            let item = NSMenuItem(title: theme.name,
                                  action: #selector(pickTheme(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = theme.name
            if theme.name == Themes.current.name { item.state = .on }
            menu.addItem(item)
        }
        let origin = NSPoint(x: 0, y: sender.bounds.height + 4)
        menu.popUp(positioning: nil, at: origin, in: sender)
    }

    @objc func pickTheme(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              name != Themes.current.name else { return }
        var cfg = config
        cfg.theme = name
        ConfigManager.save(cfg)
        // Regenerate so theme-derived files (sketchybarrc, workspace-colors.sh)
        // pick up the new palette right away. Then re-launch so the GUI itself
        // re-renders with the new theme.
        Generators.regenerateAll(cfg)
        Generators.reloadSketchybar(cfg)
        relaunchSelf()
    }

    private func relaunchSelf() {
        let path = ProcessInfo.processInfo.arguments.first ?? ""
        if !path.isEmpty {
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", "sleep 0.2 && \"\(path)\" >/dev/null 2>&1 &"]
            try? task.run()
        }
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
        case 21 where cmd: tabBar.select(index: 3)
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
            // Capture stderr too so we can see when aerospace rejects a move
            // (e.g. monitor not yet visible). The output goes into the watcher
            // log so failures surface in /tmp/aerospace-control-watcher.{log,err}.
            let out = shell("aerospace move-workspace-to-monitor --workspace \(ws) \(mon.aerospaceId) 2>&1")
            let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                NSLog("aerospace-control: move-workspace-to-monitor \(ws) → \(mon.aerospaceId) (\(monName)): \(trimmed)")
            }
            skbCases += "        \(ws)) echo \(mon.sketchybarIndex) ;;\n"
        } else {
            NSLog("aerospace-control: WARN saved layout references monitor '\(monName)' not in current set — skipping ws \(ws)")
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
    guard !mons.isEmpty else {
        NSLog("aerospace-control: runAutoRestore — no monitors detected, skipping")
        return
    }
    let sig = monitorSignature(mons)
    NSLog("aerospace-control: runAutoRestore — sig=\(sig), \(mons.count) monitors")

    let layout: [String: String]
    if let saved = cfg.monitor_layouts?[sig] {
        layout = saved
        NSLog("aerospace-control: using saved layout (\(saved.count) workspaces)")
    } else {
        layout = defaultLayoutFor(workspaces: cfg.workspaces, monitors: mons)
        if cfg.monitor_layouts == nil { cfg.monitor_layouts = [:] }
        cfg.monitor_layouts![sig] = layout
        ConfigManager.save(cfg)
        NSLog("aerospace-control: no saved layout for this combo — applied default and saved")
    }
    applyLayoutHeadless(layout: layout, monitors: mons)
    NSLog("aerospace-control: applyLayoutHeadless done")
}

// MARK: - Main
let args = CommandLine.arguments

// Resolve theme from config early so any generator (workspace-colors.sh,
// sketchybarrc SPACE_COLORS) emits the correct hex values for the active theme.
if let cfgName = (try? JSONDecoder().decode(AppConfig.self,
        from: Data(contentsOf: URL(fileURLWithPath: Paths.configFile))))?.theme,
   let t = Themes.byName(cfgName) {
    Themes.current = t
}

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
    NSLog("aerospace-control --watch: starting")

    var lastSignature = ""

    /// Re-detect signature and run auto-restore if it changed. Used by both
    /// the screen-parameters notification and the periodic poll. The empty
    /// signature short-circuits — when aerospace hasn't reported monitors yet
    /// (eg. just after our launch-agent started), we don't want to overwrite
    /// the cached state with an empty layout.
    func checkAndApply(reason: String) {
        let mons = detectMonitors()
        guard !mons.isEmpty else {
            if reason != "poll" { NSLog("aerospace-control --watch: \(reason) — no monitors yet, deferring") }
            return
        }
        let sig = monitorSignature(mons)
        if sig != lastSignature {
            NSLog("aerospace-control --watch: signature changed (\(reason)): \(lastSignature) → \(sig)")
            lastSignature = sig
            runAutoRestore()
        }
    }

    // Notification: 1.5s debounce — aerospace can take a moment to settle on
    // its new monitor list after connect/disconnect; reading too soon gives
    // stale state.
    NotificationCenter.default.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification,
        object: nil, queue: .main
    ) { _ in
        NSLog("aerospace-control --watch: didChangeScreenParameters fired")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            checkAndApply(reason: "notification")
        }
    }

    // Periodic fallback. macOS sometimes drops the notification (lid events,
    // DisplayLink / USB-C hub flapping). Use Timer with .common mode so it
    // fires under NSApplication's run loop (the default-init Timer doesn't).
    let pollTimer = Timer(timeInterval: 3.0, repeats: true) { _ in
        checkAndApply(reason: "poll")
    }
    RunLoop.main.add(pollTimer, forMode: .common)

    // First pass: try once now, then schedule another attempt at +2s in case
    // aerospace's CLI isn't responsive yet at launch.
    checkAndApply(reason: "init")
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        checkAndApply(reason: "init+2s")
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

// Resolve theme from config BEFORE building any view so all colors render
// against the active theme.
if let name = config.theme, let t = Themes.byName(name) {
    Themes.current = t
}

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
