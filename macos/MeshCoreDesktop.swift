import AppKit
import Foundation

final class MeshCoreDesktop: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var status: NSTextField!
    private var output: NSTextView!
    private var editorWindow: NSWindow?
    private var editor: NSTextView?
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
        NSApp.appearance = NSAppearance(named: .aqua)
        createWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if let running = process, running.isRunning {
            running.terminate()
        }
        return .terminateNow
    }

    private func createConfigIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
            guard !FileManager.default.fileExists(atPath: config.path) else { return }
            if let example = Bundle.main.resourceURL?.appendingPathComponent("config.ini.example"),
               FileManager.default.fileExists(atPath: example.path) {
                var contents = try String(contentsOf: example, encoding: .utf8)
                // Bind the dashboard to loopback; never expose an unauthenticated dashboard on LAN.
                contents = contents.replacingOccurrences(of: "host = 0.0.0.0", with: "host = 127.0.0.1")
                if let start = contents.range(of: "\n[Web_Viewer]\n"),
                   let end = contents[start.upperBound...].range(of: "\n[") {
                    let range = start.lowerBound..<end.lowerBound
                    let viewer = String(contents[range]).replacingOccurrences(of: "\nenabled = false", with: "\nenabled = true").replacingOccurrences(of: "auto_start = false", with: "auto_start = true")
                    contents.replaceSubrange(range, with: viewer)
                }
                contents = contents.replacingOccurrences(of: "serial_port = /dev/ttyUSB0", with: "serial_port = /dev/cu.usbmodemREPLACE_ME")
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
        return button
    }

    private func createWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "MeshCore Bot • Intel Mac"
        window.center()
        window.minSize = NSSize(width: 760, height: 560)
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 560))
        root.autoresizingMask = [.width, .height]
        window.contentView = root

        let heading = NSTextField(labelWithString: "MeshCore Bot")
        heading.font = NSFont.boldSystemFont(ofSize: 24)
        heading.frame = NSRect(x: 22, y: 523, width: 300, height: 30)
        root.addSubview(heading)

        status = NSTextField(labelWithString: "Stopped • Configure your radio, then click Start Bot")
        status.frame = NSRect(x: 22, y: 460, width: 700, height: 24)
        status.autoresizingMask = [.width]
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
        output.drawsBackground = true
        output.backgroundColor = NSColor.textBackgroundColor
        output.textColor = NSColor.textColor
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor.textBackgroundColor
        output.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        output.string = "Ready. Settings and database files live in:\n\(home.path)\n\n"
        scroll.documentView = output
        root.addSubview(scroll)
        window.makeKeyAndOrderFront(nil)
    }

    private func appendLog(_ s: String) {
        DispatchQueue.main.async {
            self.output.textStorage?.append(NSAttributedString(string: s, attributes: [.foregroundColor: NSColor.textColor, .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)]))
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
        guard process?.isRunning != true else { return }
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
        if let existing = editorWindow { existing.makeKeyAndOrderFront(nil); return }
        do {
            let text = try String(contentsOf: config, encoding: .utf8)
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
                styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.title = "Configuration — save, then restart the bot"
            let scroll = NSScrollView(frame: NSRect(x: 12, y: 54, width: 736, height: 534))
            scroll.autoresizingMask = [.width, .height]
            scroll.hasVerticalScroller = true
            let t = NSTextView(frame: scroll.bounds)
            t.isRichText = false
            t.isAutomaticQuoteSubstitutionEnabled = false
            t.isAutomaticDashSubstitutionEnabled = false
            t.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            t.textColor = .textColor
            t.backgroundColor = .textBackgroundColor
            t.string = text
            scroll.documentView = t
            w.contentView!.addSubview(scroll)
            let save = NSButton(title: "Save Configuration", target: self, action: #selector(saveConfig))
            save.frame = NSRect(x: 12, y: 12, width: 190, height: 32)
            w.contentView!.addSubview(save)
            editor = t
            editorWindow = w
            w.center()
            w.makeKeyAndOrderFront(nil)
        } catch { showError(error.localizedDescription) }
    }

    @objc private func saveConfig() {
        guard let text = editor?.string else { return }
        do {
            try text.write(to: config, atomically: true, encoding: .utf8)
            appendLog("Configuration saved. Restart the bot to apply changes.\n")
            editorWindow?.close()
        } catch { showError("Could not save configuration: \(error.localizedDescription)") }
    }

    @objc private func openFolder() {
        NSWorkspace.shared.open(home)
    }

    @objc private func openDashboard() {
        guard process?.isRunning == true else {
            showError("The bot is stopped. Start the bot and check the log for errors before opening the dashboard.")
            return
        }
        var section = ""
        var port = "8080"
        if let text = try? String(contentsOf: config, encoding: .utf8) {
            for raw in text.components(separatedBy: .newlines) {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("[") { section = line }
                if section == "[Web_Viewer]", !line.hasPrefix("#"), !line.hasPrefix(";") {
                    let parts = line.components(separatedBy: "=")
                    if parts.count == 2 && parts[0].trimmingCharacters(in: .whitespaces) == "port" {
                        port = parts[1].components(separatedBy: "#")[0].trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
        guard let number = Int(port), (1...65535).contains(number),
              let url = URL(string: "http://127.0.0.1:\(number)") else {
            showError("Invalid dashboard port in [Web_Viewer]."); return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode < 500 {
                    NSWorkspace.shared.open(url)
                } else {
                    self?.showError("No dashboard is responding at \(url.absoluteString). Check that the web viewer is enabled in config.ini and verify its configured port. \(error?.localizedDescription ?? "")")
                }
            }
        }.resume()
    }
}

let app = NSApplication.shared
let delegate = MeshCoreDesktop()
app.delegate = delegate
app.run()
