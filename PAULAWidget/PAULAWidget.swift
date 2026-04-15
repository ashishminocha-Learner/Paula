import AppIntents
import SwiftUI
import WidgetKit

// MARK: - URL scheme constants

enum PAULAAction {
    static var open: URL { URL(string: "paula://open")! }
}

// MARK: - Timeline Entry

struct RecordingEntry: TimelineEntry {
    let date: Date
    let isRecording: Bool
    let isPaused: Bool
    let startDate: Date?
    let pausedElapsed: TimeInterval
    let markCount: Int
}

// MARK: - Timeline Provider

struct RecordingProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecordingEntry {
        RecordingEntry(date: .now, isRecording: true, isPaused: false,
                       startDate: Date(timeIntervalSinceNow: -73), pausedElapsed: 0, markCount: 2)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecordingEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecordingEntry>) -> Void) {
        let entry = currentEntry()
        let refresh = Calendar.current.date(byAdding: .second, value: 30, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func currentEntry() -> RecordingEntry {
        RecordingEntry(
            date: .now,
            isRecording:   WidgetBridge.isRecording,
            isPaused:      WidgetBridge.isPaused,
            startDate:     WidgetBridge.startDate,
            pausedElapsed: WidgetBridge.pausedElapsed,
            markCount:     WidgetBridge.markCount
        )
    }
}

// MARK: - Widget Definition

@main
struct PAULAWidget: Widget {
    let kind = "PAULAWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecordingProvider()) { entry in
            PAULAWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("PAULA Recording")
        .description("Monitor and control your recording from the lock screen or home screen.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

// MARK: - Entry View Router

struct PAULAWidgetEntryView: View {
    let entry: RecordingEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular: RectangularView(entry: entry)
        case .accessoryCircular:    CircularView(entry: entry)
        default:                    InlineView(entry: entry)
        }
    }
}

// MARK: - Rectangular (primary lock-screen widget)

private struct RectangularView: View {
    let entry: RecordingEntry

    var body: some View {
        if entry.isRecording {
            activeView
        } else {
            idleView
        }
    }

    // Active recording: status row + 3 control links
    private var activeView: some View {
        VStack(alignment: .leading, spacing: 5) {
            // ── Status row ──────────────────────────────────────────
            HStack(spacing: 5) {
                Circle()
                    .fill(entry.isPaused ? Color.orange : Color.red)
                    .frame(width: 6, height: 6)
                Text(entry.isPaused ? "PAUSED" : "● REC")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.isPaused ? .orange : .red)
                Spacer()
                elapsedText
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
            }

            // ── Controls row ─────────────────────────────────────────
            HStack(spacing: 0) {
                // Mark
                Button(intent: MarkRecordingIntent()) {
                    VStack(spacing: 2) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Mark")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                        if entry.markCount > 0 {
                            Text("\(entry.markCount)")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.50))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 28)
                    .foregroundStyle(.white.opacity(0.20))

                // Pause / Resume
                Button(intent: PauseResumeRecordingIntent()) {
                    VStack(spacing: 2) {
                        Image(systemName: entry.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(entry.isPaused ? "Resume" : "Pause")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 28)
                    .foregroundStyle(.white.opacity(0.20))

                // Stop
                Button(intent: StopRecordingIntent()) {
                    VStack(spacing: 2) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Stop")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var elapsedText: some View {
        if entry.isPaused {
            // Static accumulated time when paused
            Text(Duration.seconds(entry.pausedElapsed),
                 format: .time(pattern: .minuteSecond))
        } else if let start = entry.startDate {
            // Self-updating live timer — no timeline refresh needed
            Text(timerInterval: start...(start + 86400),
                 countsDown: false,
                 showsHours: false)
        } else {
            Text("0:00")
        }
    }

    // Idle state
    private var idleView: some View {
        Link(destination: PAULAAction.open) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PAULA")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("No active recording")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                Image(systemName: "waveform.circle")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.white.opacity(0.30))
            }
        }
    }
}

// MARK: - Circular

private struct CircularView: View {
    let entry: RecordingEntry

    var body: some View {
        ZStack {
            if entry.isRecording {
                Button(intent: PauseResumeRecordingIntent()) {
                    ZStack {
                        Circle()
                            .fill(entry.isPaused ? Color.orange.opacity(0.20) : Color.red.opacity(0.18))
                        Image(systemName: entry.isPaused ? "pause.circle.fill" : "waveform.circle.fill")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(entry.isPaused ? .orange : .red)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Link(destination: PAULAAction.open) {
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }
}

// MARK: - Inline

private struct InlineView: View {
    let entry: RecordingEntry

    var body: some View {
        Link(destination: PAULAAction.open) {
            if entry.isRecording {
                Label(entry.isPaused ? "Paused" : "Recording", systemImage: "waveform")
            } else {
                Label("PAULA – tap to record", systemImage: "waveform.circle")
            }
        }
    }
}
