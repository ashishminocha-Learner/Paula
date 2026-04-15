import SwiftData
import SwiftUI

struct SettingsView: View {
    @AppStorage("useWhisperAPI") private var useWhisperAPI = false
    @AppStorage("llmProvider") private var llmProvider: LLMProvider = .claude
    @Environment(\.modelContext) private var modelContext
    @Query private var allRecordings: [RecordingModel]

    @State private var claudeAPIKey  = ""
    @State private var whisperAPIKey = ""
    @State private var geminiAPIKey  = ""
    @State private var groqAPIKey    = ""

    @State private var showDeleteAllConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.paulaBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        aiConfigCard
                            .padding(.top, 8)
                        privacyCard
                        aboutCard
                        Spacer(minLength: 96)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Settings")
            .toolbarBackground(Color.paulaNavy, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear(perform: loadKeys)
        }
    }

    // MARK: - AI Configuration Card

    private var aiConfigCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Summarization AI", icon: "brain")

            VStack(spacing: 0) {
                HStack {
                    Text("Provider")
                        .foregroundStyle(.white)
                    Spacer()
                    Picker("Provider", selection: $llmProvider) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .tint(Color.paulaBlue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                darkDivider

                if llmProvider == .claude {
                    APIKeyField(label: "Claude API Key", hint: "sk-ant-…",
                                value: $claudeAPIKey,
                                onSave: { saveKey($0, for: .claudeAPIKey) })
                } else if llmProvider == .gemini {
                    APIKeyField(label: "Gemini API Key", hint: "AIzaSy…",
                                value: $geminiAPIKey,
                                onSave: { saveKey($0, for: .geminiAPIKey) })
                } else if llmProvider == .openai {
                    Text("OpenAI uses the transcription key set below.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.40))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                } else if llmProvider == .groq {
                    APIKeyField(label: "Groq API Key", hint: "gsk_…",
                                value: $groqAPIKey,
                                onSave: { saveKey($0, for: .groqAPIKey) })
                }
            }
            .darkCard()

            sectionHeader("Transcription AI", icon: "waveform")
                .padding(.top, 24)

            VStack(spacing: 0) {
                Toggle("Use Whisper API", isOn: $useWhisperAPI)
                    .tint(Color.paulaBlue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                if useWhisperAPI {
                    darkDivider
                    APIKeyField(label: "OpenAI API Key", hint: "sk-…",
                                value: $whisperAPIKey,
                                onSave: { saveKey($0, for: .whisperAPIKey) })
                    darkDivider
                    Text("Audio will be sent to OpenAI for transcription.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.40))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
            }
            .darkCard()

            Text("Keys are stored securely on your device keychain.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
                .padding(.horizontal, 4)
                .padding(.top, 8)
        }
    }

    // MARK: - Privacy Card

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Privacy", icon: "hand.raised")

            VStack(spacing: 0) {
                linkRow("Privacy Policy", icon: "doc.text",           url: "https://ashishminocha-learner.github.io/Paula/#privacy")
                darkDivider
                linkRow("Terms of Use",   icon: "doc.badge.gearshape", url: "https://ashishminocha-learner.github.io/Paula/#terms")
                darkDivider

                Button {
                    showDeleteAllConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.paulaRed)
                            .frame(width: 22)
                        Text("Delete All Recordings")
                            .foregroundStyle(Color.paulaRed)
                        Spacer()
                        if !allRecordings.isEmpty {
                            Text("\(allRecordings.count)")
                                .font(.caption.bold())
                                .foregroundStyle(Color.paulaRed.opacity(0.60))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .confirmationDialog(
                    "Delete all \(allRecordings.count) recording\(allRecordings.count == 1 ? "" : "s")?",
                    isPresented: $showDeleteAllConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Delete All", role: .destructive) { deleteAllRecordings() }
                } message: {
                    Text("This permanently deletes all audio files and transcripts. This cannot be undone.")
                }
            }
            .darkCard()
        }
    }

    // MARK: - About Card

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("About", icon: "info.circle")

            VStack(spacing: 0) {
                HStack {
                    Text("Version")
                        .foregroundStyle(.white)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .darkCard()
        }
    }

    // MARK: - Sub-components

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(Color.paulaBlue)
            Text(title.uppercased())
                .font(.paulaLabel)
                .foregroundStyle(.white.opacity(0.45))
                .kerning(0.8)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    private var darkDivider: some View {
        Divider()
            .background(Color.white.opacity(0.10))
            .padding(.leading, 16)
    }

    private func linkRow(_ title: String, icon: String, url: String) -> some View {
        let destination = URL(string: url) ?? URL(string: "https://paula.app")!
        return Link(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(Color.paulaBlue)
                    .frame(width: 22)
                Text(title)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // MARK: - Persistence

    private func loadKeys() {
        claudeAPIKey  = KeychainService.get(.claudeAPIKey)
        whisperAPIKey = KeychainService.get(.whisperAPIKey)
        geminiAPIKey  = KeychainService.get(.geminiAPIKey)
        groqAPIKey    = KeychainService.get(.groqAPIKey)
    }

    private func deleteAllRecordings() {
        for recording in allRecordings {
            try? FileManager.default.removeItem(at: recording.fileURL)
            modelContext.delete(recording)
        }
        try? modelContext.save()
    }

    private func saveKey(_ value: String, for key: KeychainService.Key) {
        KeychainService.set(value, for: key)
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
}

// MARK: - API Key Field

private struct APIKeyField: View {
    let label: String
    let hint: String
    @Binding var value: String
    let onSave: (String) -> Void

    @State private var isEditing  = false
    @State private var draft      = ""
    @State private var isRevealed = false

    private var hasKey: Bool { !value.isEmpty }

    /// Shows first 7 chars + bullets + last 4, e.g. "sk-ant-••••••3f2a"
    private var maskedDisplay: String {
        guard value.count > 12 else {
            return String(repeating: "•", count: min(value.count, 12))
        }
        return "\(value.prefix(7))••••••\(value.suffix(4))"
    }

    var body: some View {
        Group {
            if hasKey && !isEditing {
                savedView
            } else {
                editView
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isEditing)
        .animation(.easeInOut(duration: 0.18), value: hasKey)
    }

    // MARK: Saved view — compact, masked

    private var savedView: some View {
        HStack(spacing: 12) {
            // Lock icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.paulaBlue.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.paulaBlue)
            }

            // Label + masked key
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text(maskedDisplay)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
            }

            Spacer()

            // Status + edit button
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)

                Button {
                    draft      = ""
                    isEditing  = true
                    isRevealed = false
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.paulaBlue)
                        .frame(width: 28, height: 28)
                        .background(Color.paulaBlue.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: Edit view — input + actions

    private var editView: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 32, height: 32)
                    Image(systemName: "lock.open")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                }
                Text(label)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if hasKey {
                    Button("Cancel") {
                        draft      = ""
                        isEditing  = false
                        isRevealed = false
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.40))
                    .buttonStyle(.plain)
                }
            }

            // Input row — SecureField / TextField + eye toggle
            HStack(spacing: 8) {
                Group {
                    if isRevealed {
                        TextField(hint, text: $draft)
                    } else {
                        SecureField(hint, text: $draft)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { commitIfReady() }
                .foregroundStyle(.white)

                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(isRevealed ? 0.60 : 0.35))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        draft.isEmpty ? Color.white.opacity(0.08) : Color.paulaBlue.opacity(0.45),
                        lineWidth: 0.75
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: draft.isEmpty)

            // Bottom action row
            HStack {
                // Remove key (only when a key is already stored)
                if hasKey {
                    Button(role: .destructive) {
                        value     = ""
                        onSave("")
                        isEditing = false
                        draft     = ""
                    } label: {
                        Label("Remove Key", systemImage: "trash")
                            .font(.caption.bold())
                            .foregroundStyle(Color.paulaRed.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Save button — appears when draft is non-empty
                if !draft.isEmpty {
                    Button { commitIfReady() } label: {
                        Text("Save Key")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.paulaBlue)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func commitIfReady() {
        guard !draft.isEmpty else { return }
        value      = draft
        onSave(draft)
        isEditing  = false
        isRevealed = false
        draft      = ""
    }
}

// MARK: - Dark card modifier

private extension View {
    func darkCard() -> some View {
        self
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            )
    }
}
