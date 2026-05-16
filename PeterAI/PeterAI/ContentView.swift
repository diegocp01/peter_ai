import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: PeterViewModel
    @FocusState private var keyFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                connectionPanel
                Divider().overlay(PeterTheme.border)
                transcriptView
                Divider().overlay(PeterTheme.border)
                controls
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PeterTheme.background)
            .navigationTitle("PeterAI")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(PeterTheme.accent)
            .toolbar {
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
        }
    }

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(viewModel.statusText, systemImage: viewModel.isActive ? "waveform.circle.fill" : "waveform.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(viewModel.isActive ? PeterTheme.green : PeterTheme.secondaryText)

                Spacer()

                Text("gpt-realtime-2")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PeterTheme.secondaryText)
            }

            if !viewModel.hasSavedAPIKey {
                HStack(spacing: 8) {
                    SecureField("OpenAI API key", text: $viewModel.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($keyFieldFocused)
                        .font(.callout.monospaced())
                        .foregroundStyle(PeterTheme.primaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .background(PeterTheme.card, in: RoundedRectangle(cornerRadius: 8))
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
            } else if !viewModel.isActive {
                Button {
                    viewModel.sendAPIKeyToWatch()
                } label: {
                    Label("Send API key to Apple Watch", systemImage: "applewatch")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(PeterTheme.green)
            }

            if let message = viewModel.notice {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(PeterTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PeterTheme.surface)
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
            .background(PeterTheme.background)
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
                    ContentUnavailableView("No conversation yet", systemImage: "mic", description: Text("Press play and talk to Peter."))
                        .foregroundStyle(PeterTheme.secondaryText)
                        .padding()
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Button {
                viewModel.toggleActive()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.isActive ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))

                    Text(viewModel.isActive ? "Pause" : "Play")
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
            }
            .buttonStyle(.plain)
            .background(viewModel.isActive ? PeterTheme.red : PeterTheme.accent, in: Capsule())
            .accessibilityLabel(viewModel.isActive ? "Pause Peter" : "Play Peter")

            Text(viewModel.isActive ? "Voice mode is on while this app is active." : "Paused.")
                .font(.footnote)
                .foregroundStyle(PeterTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(PeterTheme.surface)
    }
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
                .foregroundStyle(PeterTheme.secondaryText)

            Text(line.text)
                .font(.body)
                .foregroundStyle(PeterTheme.primaryText)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(line.role == .assistant ? PeterTheme.card : PeterTheme.userBubble, in: RoundedRectangle(cornerRadius: 8))
    }
}

private enum PeterTheme {
    static let background = Color(red: 0.06, green: 0.075, blue: 0.075)
    static let surface = Color(red: 0.09, green: 0.11, blue: 0.105)
    static let card = Color(red: 0.14, green: 0.16, blue: 0.15)
    static let userBubble = Color(red: 0.08, green: 0.30, blue: 0.24)
    static let primaryText = Color(red: 0.94, green: 0.96, blue: 0.93)
    static let secondaryText = Color(red: 0.62, green: 0.67, blue: 0.63)
    static let border = Color(red: 0.18, green: 0.22, blue: 0.20)
    static let accent = Color(red: 0.08, green: 0.52, blue: 0.38)
    static let green = Color(red: 0.24, green: 0.80, blue: 0.52)
    static let red = Color(red: 0.72, green: 0.18, blue: 0.16)
}
