import Foundation
import WidgetKit

// Notification posted by ContentView when a paula:// URL opens the app
extension Notification.Name {
    static let paulaWidgetAction = Notification.Name("com.paula.widgetAction")
}

/// Shared state bridge between the main app and the widget extension.
/// Uses an App Group UserDefaults store + Darwin notifications.
public struct WidgetBridge {

    public static let appGroupID      = "group.com.paula.app"
    public static let darwinNotifName = "com.paula.app.widgetAction"

    public static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // MARK: - Keys

    enum Key: String {
        case isRecording    = "wb_isRecording"
        case isPaused       = "wb_isPaused"
        case startDate      = "wb_startDate"       // Date when current segment started
        case pausedElapsed  = "wb_pausedElapsed"   // Accumulated seconds before pause
        case markCount      = "wb_markCount"
        case pendingAction  = "wb_pendingAction"
    }

    // MARK: - Actions (widget → app)

    public enum Action: String {
        case mark   = "mark"
        case pause  = "pause"
        case stop   = "stop"
    }

    // MARK: - Write (called by main app)

    public static func updateState(
        isRecording: Bool,
        isPaused: Bool,
        startDate: Date?,
        pausedElapsed: TimeInterval,
        markCount: Int
    ) {
        let d = defaults
        d.set(isRecording,    forKey: Key.isRecording.rawValue)
        d.set(isPaused,       forKey: Key.isPaused.rawValue)
        d.set(startDate,      forKey: Key.startDate.rawValue)
        d.set(pausedElapsed,  forKey: Key.pausedElapsed.rawValue)
        d.set(markCount,      forKey: Key.markCount.rawValue)
        WidgetCenter.shared.reloadAllTimelines()
    }

    public static func clearState() {
        let d = defaults
        d.set(false, forKey: Key.isRecording.rawValue)
        d.set(false, forKey: Key.isPaused.rawValue)
        d.removeObject(forKey: Key.startDate.rawValue)
        d.set(0,     forKey: Key.pausedElapsed.rawValue)
        d.set(0,     forKey: Key.markCount.rawValue)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Read (called by widget)

    public static var isRecording:   Bool          { defaults.bool(forKey: Key.isRecording.rawValue) }
    public static var isPaused:      Bool          { defaults.bool(forKey: Key.isPaused.rawValue) }
    public static var startDate:     Date?         { defaults.object(forKey: Key.startDate.rawValue) as? Date }
    public static var pausedElapsed: TimeInterval  { defaults.double(forKey: Key.pausedElapsed.rawValue) }
    public static var markCount:     Int           { defaults.integer(forKey: Key.markCount.rawValue) }

    // MARK: - Action dispatch (called by widget intents)

    public static func postAction(_ action: Action) {
        defaults.set(action.rawValue, forKey: Key.pendingAction.rawValue)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(darwinNotifName as CFString),
            nil, nil, true
        )
    }

    // MARK: - Action consume (called by main app)

    public static func consumePendingAction() -> Action? {
        guard let raw = defaults.string(forKey: Key.pendingAction.rawValue),
              let action = Action(rawValue: raw) else { return nil }
        defaults.removeObject(forKey: Key.pendingAction.rawValue)
        return action
    }
}
