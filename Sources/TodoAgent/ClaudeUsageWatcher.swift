import Foundation
import Security

@MainActor
final class ClaudeUsageWatcher: ObservableObject {
    // Local JSONL stats
    @Published var todayInputTokens: Int = 0
    @Published var todayOutputTokens: Int = 0
    @Published var todayCacheReadTokens: Int = 0
    @Published var todayCacheWriteTokens: Int = 0
    @Published var todayMessages: Int = 0
    @Published var todaySessions: Int = 0

    // API quota
    @Published var fiveHourUtil: Double = 0
    @Published var fiveHourReset: String = ""
    @Published var sevenDayUtil: Double = 0
    @Published var sevenDayReset: String = ""

    private let projectsDir: String
    private nonisolated(unsafe) var eventStream: FSEventStreamRef?
    private nonisolated(unsafe) var quotaTimer: Timer?
    private var cachedToken: String?

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.projectsDir = "\(home)/.claude/projects"
        self.cachedToken = Self.getOAuthToken()
        loadStats()
        startWatching()
        fetchQuota()
        // Refresh quota every 60 seconds
        quotaTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchQuota()
            }
        }
    }

    // MARK: - Local JSONL parsing

    func loadStats() {
        let fm = FileManager.default
        let today = Self.todayString()

        var inputTokens = 0
        var outputTokens = 0
        var cacheRead = 0
        var cacheWrite = 0
        var messages = 0
        var sessions = 0

        guard let projectDirs = try? fm.contentsOfDirectory(atPath: projectsDir) else { return }

        for projectDir in projectDirs {
            let projectPath = "\(projectsDir)/\(projectDir)"
            guard let files = try? fm.contentsOfDirectory(atPath: projectPath) else { continue }

            let jsonlFiles = files.filter { $0.hasSuffix(".jsonl") }
            for jsonlFile in jsonlFiles {
                let filePath = "\(projectPath)/\(jsonlFile)"

                guard let attrs = try? fm.attributesOfItem(atPath: filePath),
                      let modDate = attrs[.modificationDate] as? Date else { continue }

                let modDay = Self.dateString(from: modDate)
                guard modDay == today else { continue }

                var sessionCounted = false
                guard let data = fm.contents(atPath: filePath),
                      let content = String(data: data, encoding: .utf8) else { continue }

                for line in content.components(separatedBy: "\n") {
                    guard !line.isEmpty,
                          let lineData = line.data(using: .utf8),
                          let entry = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                        continue
                    }

                    guard let timestamp = entry["timestamp"] as? String,
                          timestamp.hasPrefix(today) else { continue }

                    let entryType = entry["type"] as? String

                    if entryType == "assistant" || entryType == "agent_progress" {
                        if let msg = entry["message"] as? [String: Any],
                           let usage = msg["usage"] as? [String: Any] {
                            inputTokens += usage["input_tokens"] as? Int ?? 0
                            outputTokens += usage["output_tokens"] as? Int ?? 0
                            cacheRead += usage["cache_read_input_tokens"] as? Int ?? 0
                            cacheWrite += usage["cache_creation_input_tokens"] as? Int ?? 0
                        }
                        messages += 1
                        if !sessionCounted {
                            sessions += 1
                            sessionCounted = true
                        }
                    }
                }
            }
        }

        todayInputTokens = inputTokens
        todayOutputTokens = outputTokens
        todayCacheReadTokens = cacheRead
        todayCacheWriteTokens = cacheWrite
        todayMessages = messages
        todaySessions = sessions
    }

    // MARK: - API quota fetch

    func fetchQuota() {
        guard let token = cachedToken else { return }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        Task { @MainActor [weak self] in
            guard let (data, response) = try? await URLSession.shared.data(for: request) else {
                return
            }

            let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard let self else { return }

            // Token expired or invalid - refresh from keychain once
            if httpStatus == 401 {
                self.cachedToken = Self.getOAuthToken()
                return
            }

            guard httpStatus == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }

            if let fiveHour = json["five_hour"] as? [String: Any] {
                self.fiveHourUtil = fiveHour["utilization"] as? Double ?? 0
                self.fiveHourReset = Self.formatReset(fiveHour["resets_at"] as? String)
            }
            if let sevenDay = json["seven_day"] as? [String: Any] {
                self.sevenDayUtil = sevenDay["utilization"] as? Double ?? 0
                self.sevenDayReset = Self.formatReset(sevenDay["resets_at"] as? String)
            }
        }
    }

    // MARK: - Keychain

    private static func getOAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            return nil
        }
        return token
    }

    // MARK: - Helpers

    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }

    private static func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    private static func formatReset(_ isoString: String?) -> String {
        guard let isoString else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoString) else { return "" }

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - FSEvents

    private func startWatching() {
        let dir = projectsDir as CFString
        var context = FSEventStreamContext()
        let unmanagedSelf = Unmanaged.passRetained(self)
        context.info = unmanagedSelf.toOpaque()

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info = info else { return }
            let watcher = Unmanaged<ClaudeUsageWatcher>.fromOpaque(info).takeUnretainedValue()
            Task { @MainActor in
                watcher.loadStats()
            }
        }

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [dir] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else { return }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        eventStream = stream
    }

    deinit {
        quotaTimer?.invalidate()
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}
