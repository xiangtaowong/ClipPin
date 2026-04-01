import Foundation

enum LaunchAtLoginServiceError: LocalizedError {
    case executableNotFound
    case launchCtlCommandFailed

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            return "Unable to find current executable path."
        case .launchCtlCommandFailed:
            return "Unable to update macOS launch-at-login configuration."
        }
    }
}

final class LaunchAtLoginService {
    private let fileManager: FileManager
    private let launchAgentLabel = "com.clippin.autostart"
    private let legacyLaunchAgentLabel = "com.clippinboard.autostart"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var isEnabled: Bool {
        guard let launchAgentURL = activeLaunchAgentURL,
              let executablePath = currentExecutablePath(),
              let configuredPath = configuredExecutablePath(at: launchAgentURL)
        else {
            return false
        }

        return configuredPath == executablePath
    }

    func synchronizeConfigurationIfNeeded() {
        guard let executablePath = currentExecutablePath() else {
            return
        }

        do {
            try migrateLegacyLaunchAgentIfNeeded()

            guard fileManager.fileExists(atPath: launchAgentURL.path) else {
                return
            }

            if configuredExecutablePath(at: launchAgentURL) == executablePath {
                return
            }

            try installLaunchAgent(executablePath: executablePath)
        } catch {
            NSLog("ClipPin failed to synchronize LaunchAgent: \(error.localizedDescription)")
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard let executablePath = currentExecutablePath() else {
                throw LaunchAtLoginServiceError.executableNotFound
            }
            try migrateLegacyLaunchAgentIfNeeded()
            try installLaunchAgent(executablePath: executablePath)
        } else {
            uninstallLaunchAgent(at: launchAgentURL)
            uninstallLaunchAgent(at: legacyLaunchAgentURL)
        }
    }

    private var launchAgentURL: URL {
        launchAgentURL(for: launchAgentLabel)
    }

    private var legacyLaunchAgentURL: URL {
        launchAgentURL(for: legacyLaunchAgentLabel)
    }

    private var activeLaunchAgentURL: URL? {
        if fileManager.fileExists(atPath: launchAgentURL.path) {
            return launchAgentURL
        }
        if fileManager.fileExists(atPath: legacyLaunchAgentURL.path) {
            return legacyLaunchAgentURL
        }
        return nil
    }

    private func launchAgentURL(for label: String) -> URL {
        let home = fileManager.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist", isDirectory: false)
    }

    private func migrateLegacyLaunchAgentIfNeeded() throws {
        guard fileManager.fileExists(atPath: legacyLaunchAgentURL.path),
              !fileManager.fileExists(atPath: launchAgentURL.path)
        else {
            return
        }

        try fileManager.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        do {
            try fileManager.moveItem(at: legacyLaunchAgentURL, to: launchAgentURL)
        } catch {
            try fileManager.copyItem(at: legacyLaunchAgentURL, to: launchAgentURL)
            try? fileManager.removeItem(at: legacyLaunchAgentURL)
        }

        _ = runLaunchCtl(arguments: ["bootout", launchCtlDomain, legacyLaunchAgentURL.path])
        _ = runLaunchCtl(arguments: ["unload", legacyLaunchAgentURL.path])
    }

    private func installLaunchAgent(executablePath: String) throws {
        try fileManager.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let plist: [String: Any] = [
            "Label": launchAgentLabel,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua"
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: launchAgentURL, options: .atomic)

        try reloadLaunchAgent(at: launchAgentURL)
        uninstallLaunchAgent(at: legacyLaunchAgentURL)
    }

    private func uninstallLaunchAgent(at url: URL) {
        _ = runLaunchCtl(arguments: ["bootout", launchCtlDomain, url.path])
        _ = runLaunchCtl(arguments: ["unload", url.path])
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            NSLog("ClipPin failed to remove LaunchAgent plist: \(error.localizedDescription)")
        }
    }

    private var launchCtlDomain: String {
        "gui/\(getuid())"
    }

    private func reloadLaunchAgent(at url: URL) throws {
        _ = runLaunchCtl(arguments: ["bootout", launchCtlDomain, url.path])
        let bootstrapStatus = runLaunchCtl(arguments: ["bootstrap", launchCtlDomain, url.path])
        if bootstrapStatus == 0 {
            return
        }

        _ = runLaunchCtl(arguments: ["unload", url.path])
        let loadStatus = runLaunchCtl(arguments: ["load", url.path])
        guard loadStatus == 0 else {
            throw LaunchAtLoginServiceError.launchCtlCommandFailed
        }
    }

    private func currentExecutablePath() -> String? {
        Bundle.main.executableURL?.path
    }

    private func configuredExecutablePath(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let plistObject = try? PropertyListSerialization.propertyList(
                  from: data,
                  options: [],
                  format: nil
              ),
              let plist = plistObject as? [String: Any],
              let arguments = plist["ProgramArguments"] as? [String],
              let executablePath = arguments.first,
              !executablePath.isEmpty
        else {
            return nil
        }

        return executablePath
    }

    @discardableResult
    private func runLaunchCtl(arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            NSLog("ClipPin failed to execute launchctl: \(error.localizedDescription)")
            return -1
        }
    }
}
