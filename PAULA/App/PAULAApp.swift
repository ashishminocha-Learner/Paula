import SwiftData
import SwiftUI

@main
struct PAULAApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var containerError: String?

    init() {
        // Fully transparent tab bar — each screen's ignoresSafeArea() gradient shows through
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private let modelContainer: ModelContainer? = {
        let schema = Schema([RecordingModel.self, TranscriptSegmentModel.self])
        // Try persistent storage first
        if let container = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]
        ) { return container }
        // Fallback: in-memory (data won't persist across launches, but app won't crash)
        return try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }()

    var body: some Scene {
        WindowGroup {
            if let container = modelContainer {
                Group {
                    if hasCompletedOnboarding {
                        ContentView()
                    } else {
                        OnboardingView(onComplete: { hasCompletedOnboarding = true })
                    }
                }
                .modelContainer(container)
            } else {
                // Extremely rare — show a recoverable error instead of crashing
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("Unable to load storage")
                        .font(.headline)
                    Text("Please restart the app. If this persists, reinstalling PAULA may resolve it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
    }
}
