import SwiftData
import SwiftUI

struct RecordingDetailView: View {
    @Bindable var recording: RecordingModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RecordingDetailViewModel()
    @State private var selectedTab = 0
    @State private var showingExportSheet = false
    @State private var exportItems: [Any] = []

    private let tabLabels = ["Transcript", "Summary", "Actions"]

    var body: some View {
        ZStack {
            LinearGradient.paulaBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom dark tab strip
                darkTabStrip
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                // Content
                Group {
                    switch selectedTab {
                    case 0: transcriptTab
                    case 1: summaryTab
                    case 2: actionsTab
                    default: transcriptTab
                    }
                }
            }
        }
        .navigationTitle(recording.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.paulaNavy, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Rename") { viewModel.showRename = true }
                    Button("Export PDF") { exportAsPDF() }
                    Button("Export DOCX") { exportAsDOCX() }
                    Divider()
                    Button("Delete", role: .destructive) { viewModel.showDeleteConfirm = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Rename Recording", isPresented: $viewModel.showRename) {
            TextField("Title", text: $viewModel.renameText)
            Button("Save") {
                recording.title = viewModel.renameText
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete Recording?", isPresented: $viewModel.showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                // 1. Delete backing audio file from the device
                if FileManager.default.fileExists(atPath: recording.fileURL.path) {
                    try? FileManager.default.removeItem(at: recording.fileURL)
                }
                // 2. Delete the record from SwiftData
                modelContext.delete(recording)
                try? modelContext.save()
                
                // 3. Pop the view off the navigation stack
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete the audio file and all associated data.")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .sheet(isPresented: $showingExportSheet) {
            ActivityView(activityItems: exportItems)
        }
        .onAppear {
            viewModel.inject(recording: recording, modelContext: modelContext)
        }
    }

    // MARK: - Custom Tab Strip

    private var darkTabStrip: some View {
        HStack(spacing: 4) {
            ForEach(tabLabels.indices, id: \.self) { i in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = i }
                } label: {
                    Text(tabLabels[i])
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(selectedTab == i ? .white : .white.opacity(0.40))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selectedTab == i {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.paulaBlue)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Transcript tab

    private var transcriptTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if recording.segments.isEmpty && !recording.isTranscribed {
                    transcribePrompt
                } else if recording.segments.isEmpty && recording.isTranscribed {
                    Text("No transcript content.")
                        .foregroundStyle(.white.opacity(0.45))
                        .padding()
                } else {
                    ForEach(recording.segments.sorted { $0.startTime < $1.startTime }) { segment in
                        TranscriptSegmentView(segment: segment)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 8)
        }
    }

    private var transcribePrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.and.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(Color.paulaBlue)
            Text("Not yet transcribed")
                .font(.paulaTitle)
                .foregroundStyle(.white)
            Text("Generate a transcript from your recording.\nOn-device transcription is free.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.50))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task { await viewModel.transcribe() }
            } label: {
                Group {
                    if viewModel.isTranscribing {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("Transcribing…")
                        }
                    } else {
                        Text("Transcribe Now (Free, On-Device)")
                    }
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.paulaBlue)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .disabled(viewModel.isTranscribing)
        }
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Summary tab

    private var summaryTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let summary = recording.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.90))
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 16)
                        
                    Button {
                        Task { await viewModel.summarize() }
                    } label: {
                        Group {
                            if viewModel.isSummarizing {
                                HStack(spacing: 8) {
                                    ProgressView().tint(.white)
                                    Text("Regenerating…")
                                }
                            } else {
                                Label("Regenerate Summary", systemImage: "arrow.clockwise")
                            }
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .disabled(viewModel.isSummarizing)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                } else if !recording.isTranscribed {
                    notTranscribedNotice
                } else {
                    generateSummaryPrompt
                }
            }
            .padding(.top, 8)
        }
    }

    private var notTranscribedNotice: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.badge.xmark")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.30))
            Text("Transcribe First")
                .font(.paulaTitle)
                .foregroundStyle(.white)
            Text("Generate a transcript before creating a summary.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var generateSummaryPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(Color.paulaCyan)

            Text("Generate AI Summary")
                .font(.paulaTitle)
                .foregroundStyle(.white)

            Text("Uses Claude AI. Your transcript will be sent to Anthropic's API. Configure your API key in Settings.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.50))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let template = recording.template {
                HStack(spacing: 6) {
                    Image(systemName: template.icon)
                    Text("Template: \(template.displayName)")
                }
                .font(.caption)
                .foregroundStyle(Color.paulaBlue)
            }

            Button {
                Task { await viewModel.summarize() }
            } label: {
                Group {
                    if viewModel.isSummarizing {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("Summarizing…")
                        }
                    } else {
                        Label("Generate Summary", systemImage: "sparkles")
                    }
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.paulaBlue)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .disabled(viewModel.isSummarizing)
        }
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions tab

    private var actionsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let actionItems = recording.actionItemsJSON.map { [ActionItem].fromJSON($0) } ?? []
                let userCues = recording.cues

                if actionItems.isEmpty && userCues.isEmpty {
                    if !recording.isTranscribed {
                        notTranscribedNotice
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.30))
                            Text("No Actions Found")
                                .font(.paulaTitle)
                                .foregroundStyle(.white)
                            Text("No commitments or action language detected.\nTry dropping cues during your next recording.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.45))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                    }
                } else {
                    if !userCues.isEmpty {
                        sectionHeader("Your Cues")
                        ForEach(userCues) { cue in
                            CueRow(cue: cue)
                        }
                    }
                    if !actionItems.isEmpty {
                        sectionHeader("Action Items")
                        ForEach(actionItems) { item in
                            ActionItemRow(item: item)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.paulaLabel)
            .foregroundStyle(Color.paulaBlue)
            .kerning(0.8)
            .padding(.top, 16)
            .padding(.bottom, 6)
    }

    // MARK: - Export

    private func exportAsPDF() {
        guard let items = viewModel.buildPDFExport() else { return }
        exportItems = [items]
        showingExportSheet = true
    }

    private func exportAsDOCX() {
        guard let items = viewModel.buildDOCXExport() else { return }
        exportItems = [items]
        showingExportSheet = true
    }
}

// MARK: - Cue row

private struct CueRow: View {
    let cue: CueModel

    private var color: Color {
        switch cue.type {
        case .goodPoint:  return .green
        case .actionItem: return Color.paulaBlue
        case .question:   return .orange
        case .idea:       return .purple
        case .bookmark:   return Color(white: 0.6)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: cue.type.icon)
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(cue.type.label)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text("at \(cue.formattedTime)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
        )
        .padding(.vertical, 3)
    }
}

// MARK: - Action item row

private struct ActionItemRow: View {
    let item: ActionItem

    private var sourceColor: Color {
        switch item.source {
        case .userCue:  return Color.paulaBlue
        case .ai:       return Color.paulaCyan
        case .pattern:  return .orange
        }
    }

    private var sourceLabel: String {
        switch item.source {
        case .userCue:  return "Flagged"
        case .ai:       return "AI"
        case .pattern:  return "Auto"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.paulaBlue)
                    .frame(width: 20)
                Text(item.text)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                Text(sourceLabel)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(sourceColor.opacity(0.18))
                    .foregroundStyle(sourceColor)
                    .clipShape(Capsule())
            }
            HStack(spacing: 12) {
                if let owner = item.owner {
                    Label(owner, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.50))
                }
                if let deadline = item.deadline {
                    Label(deadline, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.leading, 28)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .padding(.vertical, 3)
    }
}

// MARK: - Transcript segment row

private struct TranscriptSegmentView: View {
    let segment: TranscriptSegmentModel

    /// Derive a stable accent from the speaker label ("Speaker 1", "Speaker 2", …)
    private var speakerColor: Color {
        let palette: [Color] = [.paulaBlue, .paulaCyan, Color(red: 1.0, green: 0.60, blue: 0.20), Color(red: 0.65, green: 0.50, blue: 1.0)]
        let index = (Int(segment.speakerLabel.filter(\.isNumber)) ?? 1) - 1
        return palette[max(0, index) % palette.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(segment.speakerLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(speakerColor)
                    .clipShape(Capsule())
                Text(segment.formattedStartTime)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
            }
            Text(segment.text)
                .font(.body)
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        Divider()
            .background(Color.white.opacity(0.08))
    }
}

// MARK: - Activity View (share sheet)

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
