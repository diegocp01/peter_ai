import AVFoundation
import Foundation

@MainActor
final class WatchPeterViewModel: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var statusText = "Idle"
    @Published private(set) var notice: String?
    @Published private(set) var lines: [ConversationLine] = []
    @Published private(set) var userDraft = ""
    @Published private(set) var assistantDraft = ""

    private let client = RealtimeClient()
    private let microphone = WatchMicrophoneStreamer()
    private let playback = WatchAudioPlaybackEngine()
    private let webSearchClient = WebSearchClient()
    private let keySync = WatchKeySync.shared
    private var handledToolCallIDs = Set<String>()
    @Published private var apiKey = KeychainStore.loadAPIKey() ?? ""
    private var isStopping = false
    private var shouldStartMicrophoneAfterConnect = false
    private var keyRequestTask: Task<Void, Never>?

    init() {
        keySync.onAPIKey = { [weak self] key in
            Task { @MainActor in
                self?.receiveAPIKey(key)
            }
        }
        keySync.onRelayEvent = { [weak self] event in
            Task { @MainActor in
                self?.handleRelayEvent(event)
            }
        }
        keySync.onStatus = { [weak self] status in
            Task { @MainActor in
                self?.notice = status
            }
        }
        keySync.start()

        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notice = "Open PeterAI on iPhone to sync your API key."
            startKeyRequestLoop()
        } else {
            notice = "Ready."
        }
    }

    deinit {
        keyRequestTask?.cancel()
    }

    func toggleActive() {
        isActive ? stop() : start()
    }

    var hasAPIKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveTypedAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            notice = "Paste your API key first."
            return
        }

        receiveAPIKey(trimmed)
    }

    func syncFromIPhone() {
        notice = keySync.status(prefix: "Requesting key from iPhone")
        keySync.requestAPIKey()
        startKeyRequestLoop()
    }

    private func start() {
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notice = "Open PeterAI on iPhone to sync your API key."
            startKeyRequestLoop()
            return
        }

        Task {
            let allowed = await requestMicrophonePermission()
            guard allowed else {
                notice = "Microphone permission is required."
                return
            }

            do {
                try playback.prepare()
                handledToolCallIDs.removeAll()
                isActive = true
                statusText = "Connecting"
                notice = "Starting voice mode."
                shouldStartMicrophoneAfterConnect = true

                keySync.startVoiceRelay()
            } catch {
                stop()
                notice = "Could not start audio: \(error.localizedDescription)"
            }
        }
    }

    private func startKeyRequestLoop() {
        guard keyRequestTask == nil else { return }

        keyRequestTask = Task { [weak self] in
            for _ in 0..<20 {
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard let self else { return }
                    if self.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if let key = KeychainStore.loadAPIKey() {
                            self.receiveAPIKey(key)
                        }
                        self.keySync.requestAPIKey()
                    }
                }

                try? await Task.sleep(nanoseconds: 1_500_000_000)

                let hasKey = await MainActor.run {
                    !(self?.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                }
                if hasKey { break }
            }

            await MainActor.run {
                self?.keyRequestTask = nil
            }
        }
    }

    private func stop() {
        guard isActive else { return }

        isStopping = true
        microphone.stop()
        playback.stop()
        keySync.stopVoiceRelay()
        shouldStartMicrophoneAfterConnect = false
        isActive = false
        statusText = "Idle"
        userDraft = ""
        assistantDraft = ""
        notice = "Paused."
        isStopping = false
    }

    private func handleRelayEvent(_ event: [String: Any]) {
        switch event["event"] as? String {
        case "connected":
            startMicrophoneAfterRealtimeConnect()
        case "disconnected":
            if isActive && !isStopping {
                let previousNotice = notice
                stop()
                if let previousNotice, previousNotice.hasPrefix("Realtime connection failed") {
                    notice = previousNotice
                } else {
                    notice = "Connection ended."
                }
            }
        case "inputTranscriptDelta":
            guard let text = event["text"] as? String else { return }
            userDraft += text
        case "inputTranscriptCompleted":
            let text = event["text"] as? String ?? ""
            let final = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !final.isEmpty {
                lines.append(ConversationLine(role: .user, text: final))
            }
            userDraft = ""
        case "outputTranscriptDelta":
            guard let text = event["text"] as? String else { return }
            assistantDraft += text
        case "outputTranscriptCompleted":
            let text = event["text"] as? String ?? ""
            let final = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = assistantDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            let rendered = final.isEmpty ? fallback : final
            if !rendered.isEmpty {
                lines.append(ConversationLine(role: .assistant, text: rendered))
            }
            assistantDraft = ""
        case "audioDelta":
            guard let data = event["audio"] as? Data else { return }
            playback.play(pcm16: data)
        case "error":
            guard isActive else { return }
            let message = event["message"] as? String ?? "iPhone relay failed."
            notice = message
            statusText = "Error"
        case "status":
            guard let message = event["message"] as? String else { return }
            notice = message
        default:
            break
        }
    }

    private func startMicrophoneAfterRealtimeConnect() {
        guard isActive else { return }

        statusText = "Voice"
        guard shouldStartMicrophoneAfterConnect else {
            notice = "Talk now."
            return
        }

        shouldStartMicrophoneAfterConnect = false
        do {
            try microphone.start { [weak self] chunk in
                self?.keySync.sendRelayAudio(chunk)
            }
            notice = "Talk now."
        } catch {
            stop()
            notice = "Could not start microphone: \(error.localizedDescription)"
        }
    }

    private func handleFunctionCall(name: String, callID: String, arguments: String) {
        guard name == "search_web", !handledToolCallIDs.contains(callID) else { return }
        handledToolCallIDs.insert(callID)

        let query = extractSearchQuery(from: arguments)
        guard !query.isEmpty else {
            client.sendFunctionOutput(callID: callID, output: #"{"error":"Missing search query."}"#)
            return
        }

        notice = "Searching..."
        Task {
            do {
                let result = try await webSearchClient.search(apiKey: apiKey, query: query)
                client.sendFunctionOutput(callID: callID, output: makeToolOutput(answer: result))
                notice = nil
            } catch {
                client.sendFunctionOutput(callID: callID, output: makeToolOutput(error: error.localizedDescription))
                notice = "Search failed."
            }
        }
    }

    private func receiveAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        apiKey = trimmed
        keyRequestTask?.cancel()
        keyRequestTask = nil
        do {
            try KeychainStore.saveAPIKey(trimmed)
            if !isActive {
                notice = "Key synced. Ready."
            }
        } catch {
            notice = "Key synced. Ready."
        }
    }

    private func extractSearchQuery(from arguments: String) -> String {
        guard
            let data = arguments.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data),
            let json = object as? [String: Any]
        else {
            return ""
        }

        return (json["query"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeToolOutput(answer: String? = nil, error: String? = nil) -> String {
        var payload: [String: String] = [:]
        if let answer {
            payload["answer"] = answer
        }
        if let error {
            payload["error"] = error
        }

        guard
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let text = String(data: data, encoding: .utf8)
        else {
            return #"{"error":"Could not encode tool output."}"#
        }
        return text
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(watchOS 10.0, *) {
                AVAudioApplication.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        }
    }
}
