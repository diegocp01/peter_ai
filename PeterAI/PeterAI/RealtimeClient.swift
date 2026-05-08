import Foundation

enum RealtimeClientEvent {
    case connected
    case disconnected
    case inputTranscriptDelta(String)
    case inputTranscriptCompleted(String)
    case outputTranscriptDelta(String)
    case outputTranscriptCompleted(String)
    case audioDelta(Data)
    case error(String)
    case info(String)
}

final class RealtimeClient {
    var onEvent: ((RealtimeClientEvent) -> Void)?

    private let model = "gpt-realtime-2"
    private var socket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let sendQueue = DispatchQueue(label: "PeterAI.RealtimeClient.send")

    func connect(apiKey: String) {
        disconnect()

        guard let url = URL(string: "wss://api.openai.com/v1/realtime?model=\(model)") else {
            onEvent?(.error("Invalid Realtime URL."))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)
        urlSession = session
        socket = task
        task.resume()

        receiveLoop()
    }

    func disconnect() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        onEvent?(.disconnected)
    }

    func sendAudio(_ pcm16: Data) {
        guard !pcm16.isEmpty else { return }
        sendJSON([
            "type": "input_audio_buffer.append",
            "audio": pcm16.base64EncodedString()
        ])
    }

    private func sendSessionUpdate() {
        sendJSON([
            "type": "session.update",
            "session": [
                "type": "realtime",
                "instructions": """
                # Role
                - You are Peter, a warm, practical voice companion for the owner of this iPhone.
                - The main interface is voice. Speak naturally in short, useful turns.

                # Active listening session
                - When the user taps play, this is an active listening session that continues until the user taps pause or iOS stops the app.
                - Do not say you are secretly listening. Be clear that listening happens only during the active PeterAI session.

                # Wake word
                - ONLY respond when the user's latest spoken turn clearly addresses you by name, such as "Peter", "hey Peter", or "PeterAI".
                - If the latest user turn does not address Peter by name, stay silent. Do not answer, comment, or acknowledge it.
                - Once the user has addressed Peter, answer only that request. Then return to waiting for the next Peter-addressed turn.

                # Response style
                - Keep most replies to one or two spoken sentences.
                - Match the user's tone: calm when they are focused, upbeat when they are excited, direct when they ask for help.
                - DO NOT repeat the same phrasing over and over. Vary acknowledgements naturally.
                - If the user gives a harder request, use a short preamble first, like "Let me think that through" or "I'll work through it."

                # Conversation behavior
                - Handle interruptions gracefully and continue from the user's latest correction.
                - If speech is unintelligible, ask for a quick repeat instead of guessing.
                - If something fails, say briefly what went wrong and what the user can try next.
                - For names, numbers, dates, and important details, repeat them clearly when confirmation matters.
                """,
                "modalities": ["audio"],
                "max_response_output_tokens": 900,
                "audio": [
                    "input": [
                        "format": [
                            "type": "audio/pcm",
                            "rate": 24000
                        ],
                        "transcription": [
                            "model": "gpt-4o-transcribe"
                        ],
                        "noise_reduction": [
                            "type": "near_field"
                        ],
                        "turn_detection": [
                            "type": "semantic_vad",
                            "eagerness": "auto",
                            "create_response": true,
                            "interrupt_response": true
                        ]
                    ],
                    "output": [
                        "format": [
                            "type": "audio/pcm",
                            "rate": 24000
                        ],
                        "voice": "marin",
                        "speed": 1.0
                    ]
                ]
            ]
        ])
    }

    private func receiveLoop() {
        socket?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                self.handle(message)
                self.receiveLoop()
            case .failure(let error):
                self.onEvent?(.error("Realtime connection failed: \(error.localizedDescription)"))
                self.onEvent?(.disconnected)
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .data(let payload):
            data = payload
        case .string(let text):
            data = Data(text.utf8)
        @unknown default:
            return
        }

        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let json = object as? [String: Any],
            let type = json["type"] as? String
        else {
            return
        }

        switch type {
        case "session.created":
            sendSessionUpdate()
        case "session.updated":
            onEvent?(.connected)
        case "conversation.item.input_audio_transcription.delta":
            if let delta = json["delta"] as? String {
                onEvent?(.inputTranscriptDelta(delta))
            }
        case "conversation.item.input_audio_transcription.completed":
            if let transcript = json["transcript"] as? String {
                onEvent?(.inputTranscriptCompleted(transcript))
            }
        case "response.output_audio_transcript.delta", "response.audio_transcript.delta":
            if let delta = json["delta"] as? String {
                onEvent?(.outputTranscriptDelta(delta))
            }
        case "response.output_audio_transcript.done", "response.audio_transcript.done":
            onEvent?(.outputTranscriptCompleted(json["transcript"] as? String ?? ""))
        case "response.output_audio.delta", "response.audio.delta":
            if let encoded = json["delta"] as? String, let audio = Data(base64Encoded: encoded) {
                onEvent?(.audioDelta(audio))
            }
        case "response.done":
            break
        case "error":
            let errorObject = json["error"] as? [String: Any]
            let message = errorObject?["message"] as? String ?? "Unknown Realtime API error."
            onEvent?(.error(message))
        default:
            break
        }
    }

    private func sendJSON(_ payload: [String: Any]) {
        sendQueue.async { [weak self] in
            guard
                let self,
                let socket = self.socket,
                JSONSerialization.isValidJSONObject(payload),
                let data = try? JSONSerialization.data(withJSONObject: payload),
                let text = String(data: data, encoding: .utf8)
            else {
                return
            }

            socket.send(.string(text)) { [weak self] error in
                if let error {
                    self?.onEvent?(.error("Could not send Realtime event: \(error.localizedDescription)"))
                }
            }
        }
    }
}
