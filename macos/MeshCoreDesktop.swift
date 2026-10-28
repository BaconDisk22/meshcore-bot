import AppKit
import Foundation

final class MeshCoreDesktop: NSObject, NSApplicationDelegate {
    private let pumpkin = NSColor(srgbRed: 1, green: 0.55, blue: 0.20, alpha: 1)
    private let purple = NSColor(srgbRed: 0.73, green: 0.55, blue: 0.96, alpha: 1)
    private let ink = NSColor(srgbRed: 0.055, green: 0.045, blue: 0.075, alpha: 1)
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
        if let running = process, running.isRunning {
            running.terminate()
        }
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

    private func makeButton(_ title: String, _ selector: Selector, x: CGFloat, width: CGFloat) -> NSButton {
        let button = NSButton(title: title, target: self, action: selector)
        button.frame = NSRect(x: x, y: 490, width: width, height: 33)
        button.bezelStyle = .rounded
        button.contentTintColor = title == "Start Bot" ? pumpkin : purple
        button.autoresizingMask = [.minYMargin]
        return button
    }

    private func createWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "MeshCore Bot • Halloween Edition"
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = ink
        window.center()
        window.minSize = NSSize(width: 760, height: 560)
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 560))
        root.autoresizingMask = [.width, .height]
        window.contentView = root

        let heading = NSTextField(labelWithString: "MeshCore • After Dark")
        heading.font = NSFont.boldSystemFont(ofSize: 24)
        heading.textColor = pumpkin
        heading.autoresizingMask = [.minYMargin]
        heading.frame = NSRect(x: 22, y: 523, width: 300, height: 30)
        root.addSubview(heading)

        status = NSTextField(labelWithString: "Stopped • Configure your radio, then click Start Bot")
        status.frame = NSRect(x: 22, y: 460, width: 700, height: 24)
        status.autoresizingMask = [.width, .minYMargin]
        status.textColor = purple
        root.addSubview(status)

        root.addSubview(makeButton("Start Bot", #selector(startBot), x: 20, width: 116))
        root.addSubview(makeButton("Stop Bot", #selector(stopBot), x: 143, width: 110))
        root.addSubview(makeButton("Edit Config", #selector(editConfig), x: 260, width: 126))
        root.addSubview(makeButton("Open Dashboard", #selector(openDashboard), x: 393, width: 145))
        root.addSubview(makeButton("Open Bot Folder", #selector(openFolder), x: 545, width: 153))

        let scroll = NSScrollView(frame: NSRect(x: 20, y: 20, width: 720, height: 430))
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        output = NSTextView(frame: scroll.bounds)
        output.isEditable = false
        output.backgroundColor = ink
        output.textColor = NSColor(srgbRed: 0.91, green: 0.88, blue: 0.95, alpha: 1)
        output.insertionPointColor = pumpkin
        output.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        output.string = "Ready. Settings and database files live in:\n\(home.path)\n\n"
        scroll.documentView = output
        root.addSubview(scroll)
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
        guard process == nil else { return }
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
            if !data.isEmpty, let s = String(data: data, encoding: .utf8) {
                self?.appendLog(s)
            }
        }
        p.terminationHandler = { [weak self] terminated in
            DispatchQueue.main.async {
                self?.status.stringValue = "Stopped (exit code \(terminated.terminationStatus))"
                self?.logPipe?.fileHandleForReading.readabilityHandler = nil
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
            showError("Failed to start bot: \(error.localizedDescription)")
        }
    }

    @objc private func stopBot() {
        if let p = process, p.isRunning {
            p.terminate()
            status.stringValue = "Stopping…"
        }
    }

    @objc private func editConfig() {
        NSWorkspace.shared.open(config)
    }

    @objc private func openFolder() {
        NSWorkspace.shared.open(home)
    }

    @objc private func openDashboard() {
        guard let p = process, p.isRunning else {
            showError("The dashboard starts with the bot. Click Start Bot first; if the radio can't connect, the bot and dashboard stop — check the log.")
            return
        }
        let contents = (try? String(contentsOf: config, encoding: .utf8)) ?? ""
        var section = ""
        _ = Self.editingSection("Web_Viewer", in: contents) { section = $0; return $0 }
        func value(_ key: String) -> String? {
            for line in section.split(separator: "\n") {
                let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2, parts[0] == key { return parts[1] }
            }
            return nil
        }
        if value("enabled")?.lowercased() != "true" {
            showError("The dashboard is disabled. Click Edit Config and set enabled = true and auto_start = true under [Web_Viewer], then restart the bot.")
            return
        }
        var host = value("host") ?? "127.0.0.1"
        if host == "0.0.0.0" { host = "127.0.0.1" }
        let port = Int(value("port") ?? "") ?? 8080
        NSWorkspace.shared.open(URL(string: "http://\(host):\(port)")!)
    }

    /// Applies `transform` to the body of `[name]` in an INI string, up to the next section header.
    private static func editingSection(_ name: String, in contents: String, _ transform: (String) -> String) -> String {
        guard let header = contents.range(of: "\n[\(name)]") else { return contents }
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
