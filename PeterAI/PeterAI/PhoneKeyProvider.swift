import Foundation
import WatchConnectivity

final class PhoneKeyProvider: NSObject, WCSessionDelegate {
    static let shared = PhoneKeyProvider()
    private var lastAPIKey: String?
    private let watchRelay = PhoneWatchRealtimeRelay()

    private override init() {
        super.init()
    }

    func start() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()

        if let key = KeychainStore.loadAPIKey() {
            KeychainStore.publishAPIKeyToCloud(key)
            syncAPIKey(key, completion: nil)
        }
    }

    func syncAPIKey(_ apiKey: String, completion: ((String) -> Void)? = nil) {
        guard WCSession.isSupported() else {
            completion?("Watch sync unavailable on this device.")
            return
        }

        lastAPIKey = apiKey
        let session = WCSession.default
        let payload: [String: Any] = [
            "type": "apiKey",
            "apiKey": apiKey,
            "sentAt": Date().timeIntervalSince1970
        ]

        var queueError: String?
        do {
            try session.updateApplicationContext(payload)
        } catch {
            queueError = error.localizedDescription
        }

        session.transferUserInfo(payload)

        if session.isReachable {
            session.sendMessage(payload) { reply in
                if reply["ok"] as? Bool == true {
                    completion?("Delivered API key to Apple Watch.")
                } else {
                    completion?("Watch received the message but did not save the key.")
                }
            } errorHandler: { error in
                completion?("Watch delivery failed: \(error.localizedDescription)")
            }
        } else {
            if let queueError {
                completion?("\(watchStatus(prefix: "Watch sync")) Queue failed: \(queueError)")
            } else {
                completion?(watchStatus(prefix: "Queued API key for Apple Watch"))
            }
        }
    }

    func watchStatus(prefix: String = "Apple Watch status") -> String {
        guard WCSession.isSupported() else {
            return "\(prefix): WatchConnectivity unsupported."
        }

        let session = WCSession.default
        return "\(prefix): paired \(yesNo(session.isPaired)), app \(yesNo(session.isWatchAppInstalled)), reachable \(yesNo(session.isReachable)), state \(activationText(session.activationState))."
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        switch message["type"] as? String {
        case "requestAPIKey":
            if let key = KeychainStore.loadAPIKey(), !key.isEmpty {
                replyHandler(["ok": true, "apiKey": key])
            } else {
                replyHandler(["ok": false])
            }
        case "watchRelayStart":
            watchRelay.start()
            replyHandler(["ok": true])
        case "watchRelayAudio":
            if let audio = message["audio"] as? Data {
                watchRelay.sendAudio(audio)
                replyHandler(["ok": true])
            } else {
                replyHandler(["ok": false])
            }
        case "watchRelayStop":
            watchRelay.stop()
            replyHandler(["ok": true])
        default:
            replyHandler(["ok": false])
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        switch message["type"] as? String {
        case "watchRelayStart":
            watchRelay.start()
        case "watchRelayAudio":
            if let audio = message["audio"] as? Data {
                watchRelay.sendAudio(audio)
            }
        case "watchRelayStop":
            watchRelay.stop()
        default:
            return
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let key = KeychainStore.loadAPIKey(), !key.isEmpty {
            KeychainStore.publishAPIKeyToCloud(key)
            syncAPIKey(key, completion: nil)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable, let lastAPIKey else { return }
        syncAPIKey(lastAPIKey, completion: nil)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }

    private func activationText(_ state: WCSessionActivationState) -> String {
        switch state {
        case .notActivated:
            return "not activated"
        case .inactive:
            return "inactive"
        case .activated:
            return "activated"
        @unknown default:
            return "unknown"
        }
    }
}

private final class PhoneWatchRealtimeRelay {
    private let client = RealtimeClient()
    private let webSearchClient = WebSearchClient()
    private var apiKey = ""
    private var handledToolCallIDs = Set<String>()
    private var isActive = false

    init() {
        client.onEvent = { [weak self] event in
            self?.handle(event)
        }
    }

    func start() {
        guard WCSession.isSupported(), WCSession.default.isReachable else {
            return
        }

        guard let key = KeychainStore.loadAPIKey(), !key.isEmpty else {
            send(["event": "error", "message": "Save your OpenAI API key on iPhone first."])
            return
        }

        apiKey = key
        handledToolCallIDs.removeAll()
        isActive = true
        send(["event": "status", "message": "Connecting through iPhone."])
        client.connect(apiKey: key)
    }

    func sendAudio(_ audio: Data) {
        guard isActive else { return }
        client.sendAudio(audio)
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        client.disconnect(sendEvent: false)
        send(["event": "disconnected"])
    }

    private func handle(_ event: RealtimeClientEvent) {
        switch event {
        case .connected:
            send(["event": "connected"])
        case .disconnected:
            isActive = false
            send(["event": "disconnected"])
        case .inputTranscriptDelta(let text):
            send(["event": "inputTranscriptDelta", "text": text])
        case .inputTranscriptCompleted(let text):
            send(["event": "inputTranscriptCompleted", "text": text])
        case .outputTranscriptDelta(let text):
            send(["event": "outputTranscriptDelta", "text": text])
        case .outputTranscriptCompleted(let text):
            send(["event": "outputTranscriptCompleted", "text": text])
        case .audioDelta(let data):
            send(["event": "audioDelta", "audio": data])
        case .functionCall(let name, let callID, let arguments):
            handleFunctionCall(name: name, callID: callID, arguments: arguments)
        case .error(let message):
            send(["event": "error", "message": message])
        case .info(let message):
            send(["event": "status", "message": message])
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

        send(["event": "status", "message": "Searching on iPhone."])
        Task {
            do {
                let result = try await webSearchClient.search(apiKey: apiKey, query: query)
                client.sendFunctionOutput(callID: callID, output: makeToolOutput(answer: result))
            } catch {
                client.sendFunctionOutput(callID: callID, output: makeToolOutput(error: error.localizedDescription))
                send(["event": "status", "message": "Search failed."])
            }
        }
    }

    private func send(_ payload: [String: Any]) {
        guard WCSession.isSupported(), WCSession.default.isReachable else { return }

        var message = payload
        message["type"] = "watchRelayEvent"
        WCSession.default.sendMessage(message, replyHandler: nil) { _ in }
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
}
