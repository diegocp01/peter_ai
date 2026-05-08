import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var viewModel: PeterViewModel
    @FocusState private var keyFieldFocused: Bool
    @State private var showingSessions = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                connectionPanel
                Divider()
                transcriptView
                sessionReportView
                Divider()
                controls
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("PeterAI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingSessions = true
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .accessibilityLabel("Session history")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.clearTranscript()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(viewModel.lines.isEmpty && viewModel.userDraft.isEmpty && viewModel.assistantDraft.isEmpty)
                    .accessibilityLabel("Clear transcript")
                }
            }
            .sheet(isPresented: $showingSessions) {
                SessionHistoryView(sessions: viewModel.savedSessions)
            }
        }
    }

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(viewModel.statusText, systemImage: viewModel.isActive ? "waveform.circle.fill" : "waveform.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(viewModel.isActive ? .green : .secondary)

                Spacer()

                Text("gpt-realtime-2")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if !viewModel.hasSavedAPIKey {
                HStack(spacing: 8) {
                    SecureField("OpenAI API key", text: $viewModel.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($keyFieldFocused)
                        .font(.callout.monospaced())
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
                        .disabled(viewModel.isActive)

                    Button {
                        viewModel.saveAPIKey()
                        keyFieldFocused = false
                    } label: {
                        Image(systemName: "key.fill")
                            .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isActive)
                    .accessibilityLabel("Save API key")
                }
            }

            if let message = viewModel.notice {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color(uiColor: .systemBackground))
    }

    @ViewBuilder
    private var sessionReportView: some View {
        if let report = viewModel.sessionReport {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Last session")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if viewModel.isSummarizingSession {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                HStack(spacing: 12) {
                    Label(formattedDuration(report.duration), systemImage: "clock")
                    Label("\(report.statistics.userWords) heard", systemImage: "ear")
                    Label("\(report.wordCount) total", systemImage: "text.word.spacing")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(report.summary)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(Color(uiColor: .systemBackground))
        }
    }

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.lines) { line in
                        TranscriptBubble(line: line)
                            .id(line.id)
                    }

                    if !viewModel.userDraft.isEmpty {
                        TranscriptBubble(line: ConversationLine(role: .user, text: viewModel.userDraft))
                            .opacity(0.72)
                    }

                    if !viewModel.assistantDraft.isEmpty {
                        TranscriptBubble(line: ConversationLine(role: .assistant, text: viewModel.assistantDraft))
                            .opacity(0.72)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(16)
            }
            .onChange(of: viewModel.lines.count) {
                withAnimation(.snappy) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.userDraft) {
                withAnimation(.snappy) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.assistantDraft) {
                withAnimation(.snappy) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .overlay {
                if viewModel.lines.isEmpty && viewModel.userDraft.isEmpty && viewModel.assistantDraft.isEmpty {
                    ContentUnavailableView("No conversation yet", systemImage: "mic", description: Text("Tap Activate, speak naturally, then pause for Peter to respond."))
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.toggleActive()
            } label: {
                Image(systemName: viewModel.isActive ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .frame(width: 86, height: 86)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isActive ? .red : .blue)
            .clipShape(Circle())
            .accessibilityLabel(viewModel.isActive ? "Pause Peter" : "Play Peter")

            Text(viewModel.isActive ? "Listening until paused." : "Paused.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(uiColor: .systemBackground))
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

private struct SessionHistoryView: View {
    let sessions: [SessionReport]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView("No saved sessions", systemImage: "line.3.horizontal", description: Text("Pause a PeterAI session to save its summary, insights, and stats."))
                } else {
                    List(sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(session.startedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                                    .font(.headline)

                                Text(session.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)

                                HStack(spacing: 10) {
                                    Label(formattedDuration(session.duration), systemImage: "clock")
                                    Label("\(session.statistics.userWords) heard", systemImage: "ear")
                                    Label(session.statistics.sentimentLabel, systemImage: "chart.line.uptrend.xyaxis")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct SessionDetailView: View {
    let session: SessionReport

    var body: some View {
        List {
            Section("Summary and insights") {
                Text(session.summary)
                    .textSelection(.enabled)
            }

            Section("Statistics") {
                StatRow(label: "Duration", value: formattedDuration(session.duration))
                StatRow(label: "Words heard", value: "\(session.statistics.userWords)")
                StatRow(label: "Peter words", value: "\(session.statistics.assistantWords)")
                StatRow(label: "Total words", value: "\(session.statistics.totalWords)")
                StatRow(label: "User turns", value: "\(session.statistics.userTurns)")
                StatRow(label: "Peter turns", value: "\(session.statistics.assistantTurns)")
                StatRow(label: "Words per minute", value: formattedDecimal(session.statistics.wordsPerMinute))
                StatRow(label: "Avg words per turn", value: formattedDecimal(session.statistics.averageWordsPerTurn))
                StatRow(label: "Longest turn", value: "\(session.statistics.longestTurnWords) words")
                StatRow(label: "Sentiment", value: sentimentText(session.statistics))
            }

            Section("Transcript") {
                Text(session.transcript.isEmpty ? "No transcript captured." : session.transcript)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(sessionTitle(session.startedAt))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private func formattedDuration(_ duration: TimeInterval) -> String {
    let total = max(0, Int(duration.rounded()))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    if minutes > 0 {
        return "\(minutes)m \(seconds)s"
    }
    return "\(seconds)s"
}

private func formattedDecimal(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1)))
}

private func sentimentText(_ statistics: SessionStatistics) -> String {
    guard let score = statistics.sentimentScore else {
        return statistics.sentimentLabel
    }
    return "\(statistics.sentimentLabel) (\(formattedDecimal(score)))"
}

private func sessionTitle(_ date: Date) -> String {
    date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
}

private struct TranscriptBubble: View {
    let line: ConversationLine

    var body: some View {
        HStack {
            if line.role == .assistant {
                bubble
                Spacer(minLength: 44)
            } else {
                Spacer(minLength: 44)
                bubble
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(line.role.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(line.text)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(line.role == .assistant ? Color(uiColor: .secondarySystemGroupedBackground) : Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
