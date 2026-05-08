import AVFoundation
import Foundation

@MainActor
final class PeterViewModel: ObservableObject {
    @Published var apiKey: String
    @Published private(set) var hasSavedAPIKey: Bool
    @Published private(set) var isActive = false
    @Published private(set) var statusText = "Idle"
    @Published private(set) var notice: String?
    @Published private(set) var lines: [ConversationLine] = []
    @Published private(set) var userDraft = ""
    @Published private(set) var assistantDraft = ""
    @Published private(set) var sessionReport: SessionReport?
    @Published private(set) var savedSessions: [SessionReport]
    @Published private(set) var isSummarizingSession = false

    private let client = RealtimeClient()
    private let microphone = MicrophoneStreamer()
    private let playback = AudioPlaybackEngine()
    private let summaryClient = SessionSummaryClient()
    private let reminderManager = ListeningReminderManager()
    private var sessionStartedAt: Date?
    private var reminderTask: Task<Void, Never>?
    private var lastReminderLineIndex = 0

    init(apiKey: String = KeychainStore.loadAPIKey() ?? "") {
        self.apiKey = apiKey
        self.hasSavedAPIKey = !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        self.savedSessions = SessionStore.load()
        configureClient()
    }

    func toggleActive() {
        isActive ? stop(shouldSummarize: true) : start()
    }

    func saveAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            notice = "Paste your OpenAI API key first."
            return
        }

        do {
            try KeychainStore.saveAPIKey(trimmed)
            apiKey = trimmed
            hasSavedAPIKey = true
            notice = "API key saved in Keychain."
        } catch {
            notice = "Could not save API key: \(error.localizedDescription)"
        }
    }

    func clearTranscript() {
        lines.removeAll()
        userDraft = ""
        assistantDraft = ""
        sessionReport = nil
    }

    private func start() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            notice = "Paste and save your OpenAI API key before activating Peter."
            return
        }

        Task {
            let allowed = await requestMicrophonePermission()
            guard allowed else {
                notice = "Microphone permission is required."
                return
            }

            do {
                let notificationsAllowed = await reminderManager.requestAuthorization()
                try playback.prepare()
                client.connect(apiKey: trimmed)
                try microphone.start { [weak self] chunk in
                    self?.client.sendAudio(chunk)
                }
                sessionStartedAt = Date()
                sessionReport = nil
                isActive = true
                statusText = "Connecting"
                lastReminderLineIndex = lines.count
                startListeningReminders()
                notice = notificationsAllowed ? "Listening stays active until you pause." : "Listening is active. Enable notifications to get listening reminders."
            } catch {
                stop(shouldSummarize: false)
                notice = "Could not start audio: \(error.localizedDescription)"
            }
        }
    }

    private func stop(shouldSummarize: Bool) {
        let startedAt = sessionStartedAt
        let endedAt = Date()
        let duration = startedAt.map { endedAt.timeIntervalSince($0) } ?? 0
        let snapshot = SessionAnalytics.build(lines: lines, userDraft: userDraft, assistantDraft: assistantDraft, duration: duration)
        let transcript = snapshot.transcript
        let statistics = snapshot.statistics

        microphone.stop()
        playback.stop()
        client.disconnect()
        stopListeningReminders()
        isActive = false
        statusText = "Idle"
        sessionStartedAt = nil
        notice = shouldSummarize ? "Session paused." : "Session stopped."

        if shouldSummarize, let startedAt {
            summarizeSession(startedAt: startedAt, endedAt: endedAt, transcript: transcript, statistics: statistics)
        }
    }

    private func configureClient() {
        client.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: RealtimeClientEvent) {
        switch event {
        case .connected:
            statusText = "Listening"
        case .disconnected:
            if isActive {
                statusText = "Disconnected"
                isActive = false
                sessionStartedAt = nil
                stopListeningReminders()
            }
        case .inputTranscriptDelta(let text):
            userDraft += text
        case .inputTranscriptCompleted(let text):
            let final = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !final.isEmpty {
                lines.append(ConversationLine(role: .user, text: final))
            }
            userDraft = ""
        case .outputTranscriptDelta(let text):
            assistantDraft += text
        case .outputTranscriptCompleted(let text):
            let final = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = assistantDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            let rendered = final.isEmpty ? fallback : final
            if !rendered.isEmpty {
                lines.append(ConversationLine(role: .assistant, text: rendered))
            }
            assistantDraft = ""
        case .audioDelta(let data):
            playback.play(pcm16: data)
        case .error(let message):
            notice = message
            statusText = "Error"
        case .info(let message):
            notice = message
        }
    }

    private func summarizeSession(startedAt: Date, endedAt: Date, transcript: String, statistics: SessionStatistics) {
        let duration = endedAt.timeIntervalSince(startedAt)
        let reportID = UUID()
        let initialReport = SessionReport(
            id: reportID,
            startedAt: startedAt,
            endedAt: endedAt,
            duration: duration,
            wordCount: statistics.totalWords,
            transcript: transcript,
            statistics: statistics,
            summary: transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No spoken transcript was captured." : "Summarizing..."
        )
        sessionReport = initialReport
        savedSessions = SessionStore.upsert(initialReport, into: savedSessions)

        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isSummarizingSession = false
            return
        }

        isSummarizingSession = true
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let summary = try await summaryClient.summarize(apiKey: key, transcript: transcript, duration: duration, wordCount: statistics.totalWords)
                let completedReport = SessionReport(
                    id: reportID,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    duration: duration,
                    wordCount: statistics.totalWords,
                    transcript: transcript,
                    statistics: statistics,
                    summary: summary
                )
                sessionReport = completedReport
                savedSessions = SessionStore.upsert(completedReport, into: savedSessions)
            } catch {
                let failedReport = SessionReport(
                    id: reportID,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    duration: duration,
                    wordCount: statistics.totalWords,
                    transcript: transcript,
                    statistics: statistics,
                    summary: "Summary failed: \(error.localizedDescription)"
                )
                sessionReport = failedReport
                savedSessions = SessionStore.upsert(failedReport, into: savedSessions)
            }
            isSummarizingSession = false
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }

    private func startListeningReminders() {
        stopListeningReminders()
        reminderTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30 * 60 * 1_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.sendListeningReminder()
                }
            }
        }
    }

    private func stopListeningReminders() {
        reminderTask?.cancel()
        reminderTask = nil
    }

    private func sendListeningReminder() {
        guard isActive else { return }

        let recentLines = Array(lines.dropFirst(lastReminderLineIndex))
        let recentText = recentLines
            .map { "\($0.role.title): \($0.text)" }
            .joined(separator: "\n")
        let summary = TenWordSummary.make(from: recentText)
        reminderManager.sendReminder(body: summary)
        lastReminderLineIndex = lines.count
    }
}
