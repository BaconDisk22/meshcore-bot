import AppKit
import Foundation

final class MeshCoreDesktop: NSObject, NSApplicationDelegate {
    private let pumpkin = NSColor(srgbRed: 1, green: 0.55, blue: 0.20, alpha: 1)
    private let purple = NSColor(srgbRed: 0.73, green: 0.55, blue: 0.96, alpha: 1)
    private let ink = NSColor(srgbRed: 0.065, green: 0.08, blue: 0.10, alpha: 1)
    private var window: NSWindow!
    private var status: NSTextField!
    private var output: NSTextView!
    private var process: Process?
    private var logPipe: Pipe?
    private let home = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/MeshCore Bot", isDirectory: true)

    private var config: URL { home.appendingPathComponent("config.ini") }
    private var botExecutable: URL {
        Bundle.main.resourceURL!.appendingPathComponent("bot/meshcore-bot-cli")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        createConfigIfNeeded()
        createWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Never block the UI thread waiting for a bot or pipe reader to exit.
        logPipe?.fileHandleForReading.readabilityHandler = nil
        if let running = process, running.isRunning {
            running.terminationHandler = nil
            running.terminate()
        }
        process = nil
        logPipe = nil
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func createConfigIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
            // Seed relative-path resources without replacing user-customized files.
            for directory in ["translations", "data"] {
                if let source = Bundle.main.resourceURL?.appendingPathComponent("bot/_internal/" + directory),
                   let files = FileManager.default.enumerator(at: source, includingPropertiesForKeys: [.isDirectoryKey]) {
                    for case let file as URL in files {
                        let relative = String(file.path.dropFirst(source.path.count + 1))
                        let destination = home.appendingPathComponent(directory).appendingPathComponent(relative)
                        if try file.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true {
                            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                        } else if !FileManager.default.fileExists(atPath: destination.path) {
                            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                            try FileManager.default.copyItem(at: file, to: destination)
                        }
                    }
                }
            }
            guard !FileManager.default.fileExists(atPath: config.path) else { return }
            if let example = Bundle.main.resourceURL?.appendingPathComponent("config.ini.example"),
               FileManager.default.fileExists(atPath: example.path) {
                var contents = try String(contentsOf: example, encoding: .utf8)
                // Bind the dashboard to loopback; never expose an unauthenticated dashboard on LAN.
                contents = contents.replacingOccurrences(of: "host = 0.0.0.0", with: "host = 127.0.0.1")
                // Start the loopback dashboard with the bot so Open Dashboard works out of the box.
                contents = Self.editingSection("Web_Viewer", in: contents) { section in
                    section.replacingOccurrences(of: "\nenabled = false", with: "\nenabled = true")
                        .replacingOccurrences(of: "\nauto_start = false", with: "\nauto_start = true")
                }
                try contents.write(to: config, atomically: true, encoding: .utf8)
            }
        } catch {
            showError("Could not prepare configuration: \(error.localizedDescription)")
        }
    }


    private let surface = NSColor(srgbRed: 0.095, green: 0.115, blue: 0.145, alpha: 1)
    private let panel = NSColor(srgbRed: 0.13, green: 0.15, blue: 0.18, alpha: 1)
    private let muted = NSColor(srgbRed: 0.66, green: 0.71, blue: 0.77, alpha: 1)

    private func label(_ value: String, size: CGFloat, weight: NSFont.Weight = .regular,
                       color: NSColor = .white) -> NSTextField {
        let field = NSTextField(labelWithString: value)
        field.font = NSFont.systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.lineBreakMode = .byTruncatingTail
        return field
    }

    private func card(_ frame: NSRect, in parent: NSView, color: NSColor? = nil) -> NSView {
        let view = NSView(frame: frame)
        view.wantsLayer = true
        view.layer?.backgroundColor = (color ?? panel).cgColor
        view.layer?.cornerRadius = 14
        parent.addSubview(view)
        return view
    }

    private func actionButton(_ title: String, selector: Selector, frame: NSRect,
                              parent: NSView, primary: Bool = false) {
        let button = NSButton(title: title, target: self, action: selector)
        button.frame = frame
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = (primary ? pumpkin : NSColor(srgbRed: 0.22, green: 0.25, blue: 0.29, alpha: 1)).cgColor
        button.layer?.cornerRadius = 9
        button.contentTintColor = primary ? NSColor.black : NSColor.white
        parent.addSubview(button)
    }

    private func createWindow() {
        let width: CGFloat = 980
        let height: CGFloat = 680
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "MeshCore Bot | Control Center"
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = ink
        window.minSize = NSSize(width: width, height: height)
        window.center()

        let root = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        root.autoresizingMask = [.width, .height]
        window.contentView = root

        let sidebar = NSView(frame: NSRect(x: 0, y: 0, width: 210, height: height))
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = surface.cgColor
        sidebar.autoresizingMask = [.height]
        root.addSubview(sidebar)

        let brand = label("MESHCORE", size: 19, weight: .bold)
        brand.frame = NSRect(x: 24, y: 611, width: 175, height: 30)
        sidebar.addSubview(brand)
        let subtitle = label("BOT CONTROL CENTER", size: 10, weight: .semibold, color: muted)
        subtitle.frame = NSRect(x: 24, y: 591, width: 170, height: 18)
        sidebar.addSubview(subtitle)

        let navigation = [("OVERVIEW", 520), ("RADIO & CONNECTION", 472),
                          ("CONFIGURATION", 424), ("ACTIVITY LOG", 376)]
        for (name, y) in navigation {
            let nav = label(name, size: 12, weight: .semibold,
                            color: name == "OVERVIEW" ? pumpkin : muted)
            nav.frame = NSRect(x: 24, y: CGFloat(y), width: 174, height: 23)
            sidebar.addSubview(nav)
        }
        let sidebarNote = label("LOCAL DESKTOP MODE", size: 10, weight: .medium, color: muted)
        sidebarNote.frame = NSRect(x: 24, y: 30, width: 175, height: 20)
        sidebar.addSubview(sidebarNote)

        let main = NSView(frame: NSRect(x: 210, y: 0, width: width - 210, height: height))
        main.autoresizingMask = [.width, .height]
        root.addSubview(main)

        let heading = label("Overview", size: 28, weight: .bold)
        heading.frame = NSRect(x: 30, y: 606, width: 450, height: 38)
        heading.autoresizingMask = [.minYMargin]
        main.addSubview(heading)
        let description = label("Manage your MeshCore bot and local radio connection.", size: 13, color: muted)
        description.frame = NSRect(x: 31, y: 581, width: 650, height: 22)
        description.autoresizingMask = [.minYMargin]
        main.addSubview(description)

        let stateCard = card(NSRect(x: 30, y: 476, width: 710, height: 88), in: main)
        stateCard.autoresizingMask = [.width, .minYMargin]
        let stateTitle = label("BOT STATUS", size: 11, weight: .bold, color: muted)
        stateTitle.frame = NSRect(x: 20, y: 57, width: 180, height: 18)
        stateCard.addSubview(stateTitle)
        status = label("Stopped  •  Configure your radio to get started", size: 17, weight: .semibold)
        status.frame = NSRect(x: 20, y: 18, width: 660, height: 30)
        status.autoresizingMask = [.width]
        stateCard.addSubview(status)

        let controlCard = card(NSRect(x: 30, y: 350, width: 710, height: 112), in: main)
        controlCard.autoresizingMask = [.width, .minYMargin]
        let controlTitle = label("QUICK ACTIONS", size: 11, weight: .bold, color: muted)
        controlTitle.frame = NSRect(x: 20, y: 83, width: 190, height: 18)
        controlCard.addSubview(controlTitle)
        actionButton("Start Bot", selector: #selector(startBot),
                     frame: NSRect(x: 20, y: 22, width: 122, height: 43), parent: controlCard, primary: true)
        actionButton("Stop Bot", selector: #selector(stopBot),
                     frame: NSRect(x: 152, y: 22, width: 112, height: 43), parent: controlCard)
        actionButton("Edit Config", selector: #selector(editConfig),
                     frame: NSRect(x: 274, y: 22, width: 126, height: 43), parent: controlCard)
        actionButton("Dashboard", selector: #selector(openDashboard),
                     frame: NSRect(x: 410, y: 22, width: 128, height: 43), parent: controlCard)
        actionButton("Bot Folder", selector: #selector(openFolder),
                     frame: NSRect(x: 548, y: 22, width: 142, height: 43), parent: controlCard)

        let logsCard = card(NSRect(x: 30, y: 24, width: 710, height: 312), in: main)
        logsCard.autoresizingMask = [.width, .height]
        let logTitle = label("LIVE ACTIVITY", size: 11, weight: .bold, color: muted)
        logTitle.frame = NSRect(x: 18, y: 278, width: 200, height: 20)
        logTitle.autoresizingMask = [.minYMargin]
        logsCard.addSubview(logTitle)
        let scroll = NSScrollView(frame: NSRect(x: 16, y: 16, width: 678, height: 252))
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = 8
        output = NSTextView(frame: scroll.bounds)
        output.isEditable = false
        output.backgroundColor = ink
        output.textColor = NSColor(srgbRed: 0.88, green: 0.92, blue: 0.95, alpha: 1)
        output.insertionPointColor = pumpkin
        output.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        output.string = "Ready. Settings and database files live in:\\n\\(home.path)\\n\\n"
        scroll.documentView = output
        logsCard.addSubview(scroll)
        window.makeKeyAndOrderFront(nil)
    }

    private func appendLog(_ s: String) {
        DispatchQueue.main.async {
            self.output.textStorage?.append(NSAttributedString(string: s, attributes: [.foregroundColor: self.output.textColor ?? NSColor.white, .font: self.output.font ?? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)]))
            self.output.scrollToEndOfDocument(nil)
        }
    }

    private func showError(_ message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "MeshCore Bot"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    @objc private func startBot() {
        guard process == nil else {
            appendLog("Bot is already running or shutting down. Wait before starting again.\n")
            return
        }
        guard FileManager.default.fileExists(atPath: config.path) else {
            showError("Configuration is missing. Restore config.ini in the Bot Folder before starting.")
            return
        }
        guard let configText = try? String(contentsOf: config, encoding: .utf8),
              !configText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("Configuration is empty or unreadable. Open the Bot Folder and repair config.ini.")
            return
        }
        guard FileManager.default.isExecutableFile(atPath: botExecutable.path) else {
            showError("Bundled bot executable is missing. Rebuild the macOS package.")
            return
        }
        let p = Process()
        p.executableURL = botExecutable
        p.arguments = ["--config", config.path]
        p.currentDirectoryURL = home
        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        logPipe = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            // Radio output may split UTF-8 code points between reads. Decode
            // with replacement instead of silently dropping an entire chunk.
            let decoded = String(decoding: data, as: UTF8.self)
            self?.appendLog(decoded)
        }
        p.terminationHandler = { [weak self] terminated in
            DispatchQueue.main.async {
                self?.status.stringValue = "Stopped (exit code \(terminated.terminationStatus))"
                self?.logPipe?.fileHandleForReading.readabilityHandler = nil
                self?.logPipe = nil
                self?.process = nil
            }
        }
        do {
            try p.run()
            process = p
            status.stringValue = "Running locally • PID \(p.processIdentifier)"
            appendLog("\n--- Starting MeshCore Bot ---\n")
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            logPipe = nil
            process = nil
            showError("Failed to start bot: \(error.localizedDescription)")
        }
    }

    @objc private func stopBot() {
        guard let p = process, p.isRunning else {
            appendLog("Bot is not running; nothing to stop.\n")
            return
        }
        p.terminate()
        status.stringValue = "Stopping…"
    }

    @objc private func editConfig() {
        let contents: String
        do {
            contents = try String(contentsOf: config, encoding: .utf8)
        } catch {
            showError("Cannot read config.ini: \(error.localizedDescription)")
            return
        }
        let alert = NSAlert()
        alert.messageText = "Edit MeshCore Bot Configuration"
        alert.informativeText = "Changes are saved to config.ini. Restart the bot to apply them."
        alert.addButton(withTitle: "Save Changes")
        alert.addButton(withTitle: "Cancel")
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 650, height: 430))
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        let editor = NSTextView(frame: scroll.bounds)
        editor.isEditable = true
        editor.isRichText = false
        editor.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        editor.string = contents
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        scroll.documentView = editor
        alert.accessoryView = scroll
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let updated = editor.string
        guard updated != contents else { return }
        guard !updated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("Configuration cannot be empty. No changes were saved.")
            return
        }
        do {
            let backup = home.appendingPathComponent("config.ini.bak")
            if FileManager.default.fileExists(atPath: backup.path) {
                try FileManager.default.removeItem(at: backup)
            }
            try FileManager.default.copyItem(at: config, to: backup)
            try updated.write(to: config, atomically: true, encoding: .utf8)
            appendLog("Configuration saved. Restart the bot to apply changes.\\n")
        } catch {
            showError("Could not save config.ini: \(error.localizedDescription)")
        }
    }

    @objc private func openFolder() {
        NSWorkspace.shared.open(home)
    }

    @objc private func openDashboard() {
        guard let p = process, p.isRunning else {
            showError("The dashboard starts with the bot. Click Start Bot first; if the radio can't connect, the bot and dashboard stop — check the log.")
            return
        }
        let contents: String
        do {
            contents = try String(contentsOf: config, encoding: .utf8)
        } catch {
            showError("Cannot read dashboard settings: \(error.localizedDescription)")
            return
        }
        guard contents.contains("[Web_Viewer]") else {
            showError("Missing [Web_Viewer] configuration section.")
            return
        }
        var section = ""
        _ = Self.editingSection("Web_Viewer", in: contents) { section = $0; return $0 }
        func value(_ key: String) -> String? {
            for line in section.split(separator: "\n") {
                let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2, parts[0] == key { return parts[1] }
            }
            return nil
        }
        if value("enabled")?.lowercased() != "true" || value("auto_start")?.lowercased() != "true" {
            showError("The dashboard is disabled. Click Edit Config and set enabled = true and auto_start = true under [Web_Viewer], then restart the bot.")
            return
        }
        let configuredHost = value("host") ?? "127.0.0.1"
        // The desktop button should never navigate to a configured remote host.
        // The local dashboard remains accessible through loopback even if it binds to all interfaces.
        let host = "127.0.0.1"
        guard let port = Int(value("port") ?? "8080"), (1...65535).contains(port) else {
            showError("Invalid dashboard port in [Web_Viewer]. Set port to a number from 1 to 65535.")
            return
        }
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        guard let url = components.url else {
            showError("Invalid dashboard host in [Web_Viewer]. Check the host setting.")
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Applies `transform` to the body of `[name]` in an INI string, up to the next section header.
    private static func editingSection(_ name: String, in contents: String, _ transform: (String) -> String) -> String {
        let marker = "[\(name)]"
        let header: Range<String.Index>?
        if contents.hasPrefix(marker) {
            header = contents.startIndex..<contents.index(contents.startIndex, offsetBy: marker.count)
        } else {
            header = contents.range(of: "\n" + marker)
        }
        guard let header else { return contents }
        let end = contents.range(of: "\n[", range: header.upperBound..<contents.endIndex)?.lowerBound ?? contents.endIndex
        var result = contents
        result.replaceSubrange(header.upperBound..<end, with: transform(String(contents[header.upperBound..<end])))
        return result
    }
}

let app = NSApplication.shared
let delegate = MeshCoreDesktop()
app.delegate = delegate
app.run()
