import SwiftUI
import WatchKit

struct WatchContentView: View {
    @EnvironmentObject private var viewModel: WatchPeterViewModel
    @State private var showingKeyEntry = false
    @State private var typedAPIKey = ""

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

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.lines.suffix(8)) { line in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.role.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(line.text)
                                .font(.caption)
                                .lineLimit(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(line.role == .assistant ? Color.white.opacity(0.12) : Color.green.opacity(0.22), in: RoundedRectangle(cornerRadius: 8))
                    }

                    if !viewModel.userDraft.isEmpty {
                        Text(viewModel.userDraft)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !viewModel.assistantDraft.isEmpty {
                        Text(viewModel.assistantDraft)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

            Button {
                viewModel.toggleActive()
            } label: {
                Image(systemName: viewModel.isActive ? "pause.fill" : "play.fill")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isActive ? .red : .green)
            .disabled(!viewModel.hasAPIKey)
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
