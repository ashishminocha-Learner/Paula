import AppIntents

// These intents run inside the widget extension process.
// They write to the shared App Group and post a Darwin notification
// which the main app (kept alive by UIBackgroundModes: audio) picks up.

struct MarkRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Moment"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetBridge.postAction(.mark)
        return .result()
    }
}

struct PauseResumeRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause / Resume Recording"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetBridge.postAction(.pause)
        return .result()
    }
}

struct StopRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Recording"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetBridge.postAction(.stop)
        return .result()
    }
}
