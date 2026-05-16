import Foundation
import WatchConnectivity

final class WatchKeySync: NSObject, WCSessionDelegate {
    static let shared = WatchKeySync()

    var onAPIKey: ((String) -> Void)?
    var onRelayEvent: (([String: Any]) -> Void)?
    var onStatus: ((String) -> Void)?

    private override init() {
        super.init()
    }

    func start() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()

        receiveAPIKey(from: session.receivedApplicationContext)
    }

    func requestAPIKey() {
        guard WCSession.isSupported() else {
            onStatus?("Watch sync unavailable.")
            return
        }

        let session = WCSession.default
        receiveAPIKey(from: session.receivedApplicationContext)
        guard session.isReachable else {
            onStatus?(status(prefix: "iPhone not reachable"))
            return
        }

        session.sendMessage(["type": "requestAPIKey"]) { [weak self] response in
            guard
                response["ok"] as? Bool == true,
                let key = response["apiKey"] as? String
            else {
                self?.onStatus?("iPhone answered but did not return a key.")
                return
            }
            self?.receiveAPIKey(key)
        } errorHandler: { [weak self] error in
            self?.onStatus?("iPhone request failed: \(error.localizedDescription)")
        }
    }

    func startVoiceRelay() {
        sendRelayMessage(["type": "watchRelayStart"], needsReply: true)
    }

    func sendRelayAudio(_ audio: Data) {
        sendRelayMessage(["type": "watchRelayAudio", "audio": audio], needsReply: false)
    }

    func stopVoiceRelay() {
        sendRelayMessage(["type": "watchRelayStop"], needsReply: false)
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        receiveAPIKey(from: applicationContext)
    }

    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        receiveAPIKey(from: userInfo)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        if message["type"] as? String == "watchRelayEvent" {
            onRelayEvent?(message)
        } else {
            receiveAPIKey(from: message)
        }
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if message["type"] as? String == "watchRelayEvent" {
            onRelayEvent?(message)
            replyHandler(["ok": true])
            return
        }

        if receiveAPIKey(from: message) {
            replyHandler(["ok": true])
        } else {
            replyHandler(["ok": false])
        }
    }

    private func sendRelayMessage(_ message: [String: Any], needsReply: Bool) {
        guard WCSession.isSupported() else {
            onStatus?("iPhone relay unavailable.")
            return
        }

        let session = WCSession.default
        guard session.isReachable else {
            onStatus?(status(prefix: "Open PeterAI on iPhone"))
            return
        }

        if needsReply {
            session.sendMessage(message) { [weak self] response in
                if response["ok"] as? Bool != true {
                    self?.onStatus?("iPhone relay did not start.")
                }
            } errorHandler: { [weak self] error in
                self?.onStatus?("iPhone relay failed: \(error.localizedDescription)")
            }
        } else {
            session.sendMessage(message, replyHandler: nil) { [weak self] error in
                self?.onStatus?("iPhone relay failed: \(error.localizedDescription)")
            }
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        receiveAPIKey(from: session.receivedApplicationContext)
        requestAPIKey()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        onStatus?(status(prefix: "iPhone connection changed"))
        if session.isReachable {
            requestAPIKey()
        }
    }

    func status(prefix: String = "iPhone status") -> String {
        guard WCSession.isSupported() else {
            return "\(prefix): WatchConnectivity unsupported."
        }

        let session = WCSession.default
        return "\(prefix): companion \(yesNo(session.isCompanionAppInstalled)), reachable \(yesNo(session.isReachable)), state \(activationText(session.activationState))."
    }

    @discardableResult
    private func receiveAPIKey(from applicationContext: [String: Any]) -> Bool {
        guard
            applicationContext["type"] as? String == "apiKey",
            let key = applicationContext["apiKey"] as? String
        else {
            return false
        }

        receiveAPIKey(key)
        return true
    }

    private func receiveAPIKey(_ key: String) {
        onAPIKey?(key)
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
