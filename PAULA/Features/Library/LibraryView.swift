import SwiftData
import SwiftUI

struct LibraryView: View {
    @Query(sort: \RecordingModel.date, order: .reverse)
    private var recordings: [RecordingModel]
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedRecording: RecordingModel?

    private var filtered: [RecordingModel] {
        guard !searchText.isEmpty else { return recordings }
        return recordings.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sections: [(header: String, items: [RecordingModel])] {
        let cal = Calendar.current
        var today: [RecordingModel] = []
        var yesterday: [RecordingModel] = []
        var thisWeek: [RecordingModel] = []
        var earlier: [RecordingModel] = []

        for r in filtered {
            if cal.isDateInToday(r.date)          { today.append(r) }
            else if cal.isDateInYesterday(r.date) { yesterday.append(r) }
            else if let ago = cal.date(byAdding: .day, value: -7, to: Date()),
                    r.date >= ago                 { thisWeek.append(r) }
            else                                  { earlier.append(r) }
        }

        var result: [(String, [RecordingModel])] = []
        if !today.isEmpty     { result.append(("Today", today)) }
        if !yesterday.isEmpty { result.append(("Yesterday", yesterday)) }
        if !thisWeek.isEmpty  { result.append(("This Week", thisWeek)) }
        if !earlier.isEmpty   { result.append(("Earlier", earlier)) }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.paulaBackground.ignoresSafeArea()

                Group {
                    if recordings.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(sections, id: \.header) { section in
                                Section {
                                    ForEach(section.items) { recording in
                                        Button {
                                            selectedRecording = recording
                                        } label: {
                                            RecordingRow(recording: recording)
                                        }
                                        .buttonStyle(.plain)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                delete(recording)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    }
                                } header: {
                                    Text(section.header.uppercased())
                                        .font(.paulaLabel)
                                        .foregroundStyle(Color.paulaBlue)
                                        .kerning(0.8)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .contentMargins(.bottom, 96, for: .scrollContent)
                    }
                }
            }
            .navigationTitle("Library")
            .toolbarBackground(Color.paulaNavy, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search recordings")
            .navigationDestination(item: $selectedRecording) { recording in
                RecordingDetailView(recording: recording)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.paulaBlue.opacity(0.10))
                    .frame(width: 120, height: 120)
                VStack(spacing: 4) {
                    HStack(spacing: 3) {
                        ForEach(0..<9, id: \.self) { i in
                            let heights: [CGFloat] = [0.35, 0.55, 0.80, 0.65, 1.0, 0.65, 0.80, 0.55, 0.35]
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(
                                    colors: [Color.paulaBlue, Color.paulaCyan],
                                    startPoint: .bottom, endPoint: .top
                                ))
                                .frame(width: 6, height: heights[i] * 36)
                        }
                    }
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.paulaBlue)
                        .padding(.top, 6)
                }
            }

            VStack(spacing: 8) {
                Text("No recordings yet")
                    .font(.paulaTitle)
                    .foregroundStyle(.white)
                Text("Tap the Record tab to capture\nyour first conversation.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    // MARK: - Delete

    private func delete(_ recording: RecordingModel) {
        do {
            try FileManager.default.removeItem(at: recording.fileURL)
        } catch {
            print("Warning: could not delete audio file: \(error.localizedDescription)")
        }
        modelContext.delete(recording)
    }
}

// MARK: - Recording Row

private struct RecordingRow: View {
    let recording: RecordingModel

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(templateColor(recording.template))
                .frame(width: 3)
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 6) {
                // Title + duration
                HStack(alignment: .center) {
                    Text(recording.title)
                        .font(.paulaHeadline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(recording.formattedDuration)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.paulaBlue)
                        .clipShape(Capsule())
                }

                // Date + status chips
                HStack(spacing: 6) {
                    Text(recording.date, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.45))
                        .fixedSize()
                    Spacer(minLength: 8)
                    if recording.isTranscribed {
                        statusChip("Transcript", icon: "text.quote", color: Color.paulaBlue)
                    }
                    if recording.isSummarized {
                        statusChip("Summary", icon: "sparkles", color: Color.paulaCyan)
                    }
                    if let template = recording.template {
                        statusChip(template.displayName, icon: template.icon, color: templateColor(template))
                    }
                }
                .lineLimit(1)
            }
            .padding(.leading, 12)
            .padding(.vertical, 12)
        }
        .padding(.trailing, 12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
        }
    }

    private func statusChip(_ label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.18))
        .clipShape(Capsule())
        .fixedSize()
    }

    private func templateColor(_ template: SummaryTemplate?) -> Color {
        switch template {
        case .meeting:    return Color.paulaBlue
        case .interview:  return Color(red: 0.65, green: 0.50, blue: 1.0)   // soft violet
        case .lecture:    return Color(red: 0.25, green: 0.85, blue: 0.60)  // mint green
        case .brainstorm: return Color(red: 1.00, green: 0.75, blue: 0.20)  // warm amber
        case .salesCall:  return Color(red: 1.00, green: 0.55, blue: 0.20)  // tangerine
        case .oneOnOne:   return Color.paulaCyan
        case .general:    return Color.white.opacity(0.50)
        case nil:         return Color.paulaBlue
        }
    }
}
