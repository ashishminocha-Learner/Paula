import SwiftData
import SwiftUI

struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = RecordingViewModel()
    @State private var breathe = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Full-bleed dark gradient
                LinearGradient.paulaBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Status badge (recording / paused)
                    statusBadge
                        .frame(height: 36)
                        .padding(.top, 4)

                    Spacer(minLength: 12)

                    // Hero waveform
                    HeroWaveformView(
                        level: viewModel.level,
                        isRecording: viewModel.isRecording
                    )
                    .frame(height: 160)
                    .padding(.horizontal, 28)

                    Spacer(minLength: 20)

                    // Timer
                    Text(viewModel.elapsed.formattedTimestamp)
                        .font(.paulaTimer)
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Spacer()

                    // Bottom controls stack
                    VStack(spacing: 18) {
                        // Template picker — only shown when idle
                        if !viewModel.isRecording && !viewModel.isPaused {
                            templateButton
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        // Cue strip — slides up during recording
                        if viewModel.isRecording {
                            cueStrip
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        recordingControls
                    }
                    .animation(.spring(duration: 0.35), value: viewModel.isRecording)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 96)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.paulaNavy, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PAULA")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.paulaBlue)
                        .kerning(1.5)
                }
            }
            .sheet(isPresented: $viewModel.showingTemplateSheet) {
                TemplatePicker(selected: $viewModel.selectedTemplate)
                    .presentationDetents([.medium])
            }
            .alert("Recording Error", isPresented: $viewModel.showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.alertMessage ?? "")
            }
            .onAppear {
                viewModel.inject(modelContext: modelContext)
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
        }
    }

    // MARK: - Status Badge

    @ViewBuilder
    private var statusBadge: some View {
        if viewModel.isRecording || viewModel.isPaused {
            let isRec = !viewModel.isPaused
            HStack(spacing: 6) {
                Circle()
                    .fill(isRec ? Color.paulaRed : Color.orange)
                    .frame(width: 6, height: 6)
                Text(isRec ? "REC" : "PAUSED")
                    .font(.paulaLabel)
                    .foregroundStyle(isRec ? Color.paulaRed : Color.orange)
                    .kerning(1.5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background {
                Capsule()
                    .fill((isRec ? Color.paulaRed : Color.orange).opacity(0.12))
                Capsule()
                    .strokeBorder((isRec ? Color.paulaRed : Color.orange).opacity(0.3), lineWidth: 1)
            }
        }
    }

    // MARK: - Template Button

    private var templateButton: some View {
        Button { viewModel.showingTemplateSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.selectedTemplate.icon)
                    .font(.caption.bold())
                Text(viewModel.selectedTemplate.displayName)
                    .font(.subheadline.weight(.medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .opacity(0.5)
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background {
                Capsule().fill(.white.opacity(0.08))
                Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1)
            }
        }
    }

    // MARK: - Mark Button

    private var cueStrip: some View {
        MarkButton(onTap: { viewModel.dropCue(.bookmark) },
                   markCount: viewModel.currentMarkCount)
    }

    // MARK: - Recording Controls

    @ViewBuilder
    private var recordingControls: some View {
        if viewModel.isRecording || viewModel.isPaused {
            // Active controls: Pause/Resume + Stop
            HStack(spacing: 60) {
                // Pause / Resume
                VStack(spacing: 8) {
                    Button {
                        if viewModel.isPaused { viewModel.resumeRecording() }
                        else { viewModel.pauseRecording() }
                    } label: {
                        Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 64, height: 64)
                            .background(.white.opacity(0.1))
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                    }
                    Text(viewModel.isPaused ? "Resume" : "Pause")
                        .font(.paulaLabel)
                        .foregroundStyle(.white.opacity(0.45))
                }

                // Stop
                VStack(spacing: 8) {
                    Button(action: viewModel.stopRecording) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white)
                            .frame(width: 84, height: 84)
                            .background(Color.paulaRed)
                            .clipShape(Circle())
                            .shadow(color: Color.paulaRed.opacity(0.55), radius: 22)
                    }
                    Text("Stop")
                        .font(.paulaLabel)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        } else {
            // Idle — hero glowing record button
            VStack(spacing: 16) {
                Button {
                    Task { await viewModel.startRecording() }
                } label: {
                    ZStack {
                        // Outer radial glow
                        RadialGradient(
                            colors: [Color.paulaRed.opacity(0.30), Color.paulaRed.opacity(0)],
                            center: .center,
                            startRadius: 44,
                            endRadius: 88
                        )
                        .frame(width: 176, height: 176)

                        // Outer ring
                        Circle()
                            .strokeBorder(Color.paulaRed.opacity(0.35), lineWidth: 2)
                            .frame(width: 114, height: 114)

                        // Main circle
                        Circle()
                            .fill(Color.paulaRed)
                            .frame(width: 88, height: 88)
                            .shadow(color: Color.paulaRed.opacity(0.60), radius: 22)

                        // Mic icon
                        Image(systemName: "mic.fill")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(breathe ? 1.045 : 1.0)
                }

                Text("Tap to Record")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.white.opacity(0.40))
            }
        }
    }
}

// MARK: - Hero Waveform View

private struct HeroWaveformView: View {
    let level: Float
    let isRecording: Bool

    @State private var bars: [CGFloat] = Array(repeating: 0.08, count: 48)

    private var waveGradient: LinearGradient { .paulaWaveform }

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(bars.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(waveGradient)
                    .opacity(barOpacity(i))
                    .frame(width: 5, height: max(6, bars[i] * 160))
            }
        }
        .animation(.easeOut(duration: 0.06), value: bars)
        .onChange(of: level) { _, newLevel in
            guard isRecording else { return }
            bars.removeFirst()
            let noise = CGFloat.random(in: 0.65...1.35)
            bars.append(max(0.05, min(1.0, CGFloat(newLevel) * noise)))
        }
        .onChange(of: isRecording) { _, active in
            if !active {
                withAnimation(.easeOut(duration: 0.6)) {
                    bars = Array(repeating: 0.06, count: 48)
                }
            }
        }
        .task(id: isRecording) {
            guard !isRecording else { return }
            var tick: Double = 0
            while !Task.isCancelled {
                for i in 0 ..< bars.count {
                    bars[i] = CGFloat(0.10 + 0.09 * sin(tick + Double(i) * 0.45))
                }
                tick += 0.14
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func barOpacity(_ index: Int) -> Double {
        let center = Double(bars.count - 1) / 2
        let dist = abs(Double(index) - center) / center
        return 0.95 - dist * 0.28
    }
}

// MARK: - Template Picker Sheet

private struct TemplatePicker: View {
    @Binding var selected: SummaryTemplate
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.paulaBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(SummaryTemplate.allCases) { template in
                            Button {
                                selected = template
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: template.icon)
                                        .foregroundStyle(Color.paulaBlue)
                                        .frame(width: 24)
                                    Text(template.displayName)
                                        .font(.system(.body, design: .rounded))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    if selected == template {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.paulaBlue)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                                .background(selected == template
                                    ? Color.paulaBlue.opacity(0.12)
                                    : Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle("Summary Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.paulaNavy, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.paulaBlue)
                }
            }
        }
    }
}

// MARK: - Mark Button

private struct MarkButton: View {
    let onTap: () -> Void
    let markCount: Int

    @State private var pulse = false

    var body: some View {
        Button {
            onTap()
            triggerPulse()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.paulaBlue.opacity(pulse ? 0.0 : 0.25))
                        .frame(width: 36, height: 36)
                        .scaleEffect(pulse ? 2.2 : 1.0)
                        .opacity(pulse ? 0 : 1)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.paulaBlue)
                }

                Text("Mark")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                if markCount > 0 {
                    Text("\(markCount) mark\(markCount == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.50))
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule().strokeBorder(Color.paulaBlue.opacity(0.40), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func triggerPulse() {
        pulse = false
        withAnimation(.easeOut(duration: 0.55)) { pulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { pulse = false }
    }
}

// MARK: - TimeInterval Formatting

extension TimeInterval {
    var formattedTimestamp: String {
        let total = Int(self)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
