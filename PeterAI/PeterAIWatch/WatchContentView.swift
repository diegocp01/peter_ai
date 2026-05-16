import SwiftUI
import WatchKit

struct WatchContentView: View {
    @EnvironmentObject private var viewModel: WatchPeterViewModel
    @State private var showingKeyEntry = false
    @State private var typedAPIKey = ""
    private let conversationBottomID = "conversation-bottom"

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(viewModel.statusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(viewModel.isActive ? .green : .secondary)
                Spacer()
                Text("Peter")
                    .font(.caption2.weight(.bold))
            }

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.lines.suffix(8)) { line in
                            ConversationBubble(line: line)
                        }

                        if !viewModel.userDraft.isEmpty {
                            LiveTranscriptBubble(title: "You", text: viewModel.userDraft, tint: .green)
                        }

                        if !viewModel.assistantDraft.isEmpty {
                            LiveTranscriptBubble(title: "Peter", text: viewModel.assistantDraft, tint: .white)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(conversationBottomID)
                    }
                }
                .onAppear {
                    scrollToLatest(proxy)
                }
                .onChange(of: viewModel.lines.count) {
                    scrollToLatest(proxy)
                }
                .onChange(of: viewModel.userDraft) {
                    scrollToLatest(proxy)
                }
                .onChange(of: viewModel.assistantDraft) {
                    scrollToLatest(proxy)
                }
                .onChange(of: viewModel.isActive) {
                    scrollToLatest(proxy)
                }
            }

            if let notice = viewModel.notice {
                Text(notice)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !viewModel.isActive {
                Button(viewModel.hasAPIKey ? "Sync key" : "Sync from iPhone") {
                    viewModel.syncFromIPhone()
                }
                .font(.caption2.weight(.semibold))

                Button(viewModel.hasAPIKey ? "Change key" : "Enter API key") {
                    typedAPIKey = ""
                    showingKeyEntry = true
                }
                .font(.caption2.weight(.semibold))
            }

            if viewModel.isActive {
                Button {
                    viewModel.toggleActive()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.red, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pause")
            } else {
                Button {
                    viewModel.toggleActive()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!viewModel.hasAPIKey)
            }
        }
        .padding(.horizontal, 4)
        .sheet(isPresented: $showingKeyEntry) {
            APIKeyEntryView(
                apiKey: $typedAPIKey,
                onSave: {
                    viewModel.saveTypedAPIKey(typedAPIKey)
                    if viewModel.hasAPIKey {
                        showingKeyEntry = false
                    }
                }
            )
        }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(conversationBottomID, anchor: .bottom)
            }
        }
    }
}

private struct ConversationBubble: View {
    let line: ConversationLine

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(line.role.title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(line.role == .assistant ? .white.opacity(0.82) : .green.opacity(0.9))
            Text(line.text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 9)
        .background(
            line.role == .assistant ? Color.white.opacity(0.18) : Color.green.opacity(0.28),
            in: RoundedRectangle(cornerRadius: 9)
        )
    }
}

private struct LiveTranscriptBubble: View {
    let title: String
    let text: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint.opacity(0.9))
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 9)
        .background(tint.opacity(0.2), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct APIKeyEntryView: View {
    @Binding var apiKey: String
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("OpenAI API key")
                .font(.caption.weight(.semibold))

            TextField("sk-...", text: $apiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.caption2.monospaced())
                .onSubmit(onSave)

            Button("Save") {
                onSave()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Text("Paste from the iPhone keyboard, then tap Save here.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
