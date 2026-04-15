import AVFoundation
import Speech
import SwiftUI
import UIKit

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var page = 0
    @State private var micGranted  = false
    @State private var speechGranted = false
    @State private var isRequesting = false
    @State private var showMicDenied = false

    private let totalPages = 5

    var body: some View {
        ZStack {
            LinearGradient.paulaBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $page) {
                    welcomePage   .tag(0)
                    transcribePage.tag(1)
                    whisperPage   .tag(2)
                    summarizePage .tag(3)
                    permissionsPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Dot indicator
                pageIndicator
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                // CTA button
                ctaButton
                    .padding(.horizontal, 28)
                    .padding(.bottom, 48)
            }
        }
        .environment(\.colorScheme, .dark)
        .alert("Microphone Access Required", isPresented: $showMicDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Continue Anyway", role: .cancel) { onComplete() }
        } message: {
            Text("PAULA needs microphone access to record audio. Enable it in Settings.")
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        OnboardingPage {
            ZStack {
                Circle()
                    .fill(Color.paulaBlue.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 72, weight: .thin))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.paulaBlue, Color.paulaCyan],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            Text("Meet PAULA")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Text("Your AI-powered voice recorder.\nRecord, transcribe, and summarize\nconversations effortlessly.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.60))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Page 2: Transcription (free)

    private var transcribePage: some View {
        OnboardingPage {
            ZStack {
                Circle()
                    .fill(Color.paulaBlue.opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(Color.paulaBlue)
            }

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Text("Transcription")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Free")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.paulaBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.paulaBlue.opacity(0.18))
                        .clipShape(Capsule())
                }
            }

            Text("PAULA transcribes your recordings using Apple's on-device speech engine — completely free, no account needed, and your audio never leaves your iPhone.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.60))
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                FeatureRow(icon: "iphone",          color: .paulaBlue,
                           title: "100% on-device",
                           detail: "No internet required for basic transcription")
                FeatureRow(icon: "lock.fill",        color: .paulaBlue,
                           title: "Private by default",
                           detail: "Audio stays on your device")
                FeatureRow(icon: "indianrupeesign",  color: .paulaBlue,
                           title: "Always free",
                           detail: "No API key or subscription needed")
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Page 3: Whisper for better quality

    private var whisperPage: some View {
        OnboardingPage {
            ZStack {
                Circle()
                    .fill(Color.paulaCyan.opacity(0.10))
                    .frame(width: 140, height: 140)
                Image(systemName: "waveform.and.magnifyingglass")
                    .font(.system(size: 60, weight: .thin))
                    .foregroundStyle(Color.paulaCyan)
            }

            Text("Want Better Accuracy?")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Text("For multilingual conversations, heavy accents, or technical vocabulary — OpenAI's Whisper API delivers significantly better results.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.60))
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                FeatureRow(icon: "globe",               color: .paulaCyan,
                           title: "99 languages",
                           detail: "Including Hindi-English code-switching (Hinglish)")
                FeatureRow(icon: "ear.badge.checkmark", color: .paulaCyan,
                           title: "Higher accuracy",
                           detail: "Better with accents and technical terms")
                FeatureRow(icon: "key.fill",            color: Color(red: 1, green: 0.75, blue: 0.2),
                           title: "Requires OpenAI API key",
                           detail: "~₹0.50 per 10-min recording · Set up in Settings")
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Page 4: Summarization

    private var summarizePage: some View {
        OnboardingPage {
            ZStack {
                Circle()
                    .fill(Color(red: 0.65, green: 0.50, blue: 1.0).opacity(0.12))
                    .frame(width: 140, height: 140)
                Image(systemName: "sparkles")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(Color(red: 0.65, green: 0.50, blue: 1.0))
            }

            Text("AI Summaries")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Text("After transcribing, PAULA can generate structured summaries, action items, and key points — powered by your choice of AI.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.60))
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                FeatureRow(icon: "a.circle.fill",   color: Color.paulaBlue,
                           title: "Claude (Anthropic)",
                           detail: "Best quality · Requires Anthropic API key")
                FeatureRow(icon: "bolt.fill",        color: Color(red: 1, green: 0.75, blue: 0.2),
                           title: "Groq (Llama 3.3)",
                           detail: "Fastest · Free tier available · Groq API key")
                FeatureRow(icon: "g.circle.fill",   color: Color(red: 0.25, green: 0.85, blue: 0.60),
                           title: "Gemini · OpenAI",
                           detail: "Also supported · Set up any in Settings")
            }
            .padding(.horizontal, 4)

            Text("You can skip this now and add an API key later in Settings.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Page 5: Permissions

    private var permissionsPage: some View {
        OnboardingPage {
            ZStack {
                Circle()
                    .fill(Color.paulaRed.opacity(0.10))
                    .frame(width: 140, height: 140)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(Color.paulaRed)
            }

            Text("One Last Step")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.white)

            Text("PAULA needs permission to access your microphone and use on-device speech recognition.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.60))
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                PermissionCard(icon: "mic.fill", title: "Microphone",
                               detail: "To record your conversations",
                               granted: micGranted, required: true)
                PermissionCard(icon: "text.bubble.fill", title: "Speech Recognition",
                               detail: "For free on-device transcription",
                               granted: speechGranted, required: false)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Page indicator

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalPages, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Color.paulaBlue : Color.white.opacity(0.20))
                    .frame(width: i == page ? 22 : 7, height: 7)
                    .animation(.spring(duration: 0.3), value: page)
            }
        }
    }

    // MARK: - CTA button

    private var ctaButton: some View {
        Button {
            if page < totalPages - 1 {
                withAnimation(.easeInOut(duration: 0.25)) { page += 1 }
            } else {
                Task { await requestPermissionsAndFinish() }
            }
        } label: {
            HStack(spacing: 8) {
                if isRequesting {
                    ProgressView().tint(.white)
                }
                Text(page == totalPages - 1 ? "Allow & Get Started" : "Continue")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                if page < totalPages - 1 {
                    Image(systemName: "arrow.right")
                        .font(.subheadline.bold())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [Color.paulaBlue, Color.paulaCyan.opacity(0.8)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.paulaBlue.opacity(0.40), radius: 12, y: 4)
        }
        .disabled(isRequesting)
    }

    // MARK: - Permissions

    private func requestPermissionsAndFinish() async {
        isRequesting = true
        defer { isRequesting = false }

        micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            showMicDenied = true
            return
        }

        speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        onComplete()
    }
}

// MARK: - Page container

private struct OnboardingPage<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)
                content()
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Feature row

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.50))
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Permission card

private struct PermissionCard: View {
    let icon: String
    let title: String
    let detail: String
    let granted: Bool
    let required: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.paulaBlue.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.paulaBlue)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white)
                    if required {
                        Text("Required")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.paulaRed)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.paulaRed.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.50))
            }
            Spacer()
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(granted ? Color.green.opacity(0.40) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .animation(.spring(duration: 0.3), value: granted)
    }
}
