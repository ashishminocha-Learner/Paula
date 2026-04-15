import SwiftUI

struct ContentView: View {
    @State private var selectedTabIndex: Int = 0

    enum Tab: Int, CaseIterable {
        case record = 0, library = 1, settings = 2

        var label: String {
            switch self { case .record: "Record"; case .library: "Library"; case .settings: "Settings" }
        }
        var icon: String {
            switch self { case .record: "waveform.circle.fill"; case .library: "square.stack.fill"; case .settings: "gearshape.fill" }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Screen content — full bleed, sits behind the custom tab bar
            Group {
                switch Tab(rawValue: selectedTabIndex) ?? .record {
                case .record:   RecordingView()
                case .library:  LibraryView()
                case .settings: SettingsView()
                }
            }

            // Custom floating tab bar
            FloatingTabBar(selected: $selectedTabIndex)
        }
        .environment(\.colorScheme, .dark)
        .onOpenURL { url in
            guard url.scheme == "paula" else { return }
            NotificationCenter.default.post(name: .paulaWidgetAction, object: url.host)
        }
    }
}

// MARK: - Floating Tab Bar

private struct FloatingTabBar: View {
    @Binding var selected: Int

    private let tabs = ContentView.Tab.allCases

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.rawValue) { tab in
                TabBarItem(tab: tab, isSelected: selected == tab.rawValue)
                    .onTapGesture {
                        withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                            selected = tab.rawValue
                        }
                    }
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.06))
            Capsule()
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
    }
}

// MARK: - Tab Bar Item

private struct TabBarItem: View {
    let tab: ContentView.Tab
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: tab.icon)
                .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.paulaBlue : Color.white.opacity(0.45))
                .frame(width: 36, height: 28)
                .background {
                    if isSelected {
                        Circle()
                            .fill(Color.paulaBlue.opacity(0.15))
                            .frame(width: 36, height: 36)
                    }
                }
                .scaleEffect(isSelected ? 1.06 : 1.0)
                .animation(.spring(duration: 0.3, bounce: 0.3), value: isSelected)

            Text(tab.label)
                .font(.system(size: 9, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isSelected ? Color.paulaBlue : Color.white.opacity(0.40))
        }
    }
}
