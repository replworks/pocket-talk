import Foundation
import UIKit

/// Battery and thermal readings for session start/end (TASKS.md §6).
///
/// The simulator reports `batteryLevel == -1`, so values are optional instead of fake.
enum DeviceMetrics {
    static func startMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    static var batteryLevel: Double? {
        let level = UIDevice.current.batteryLevel
        return level < 0 ? nil : Double(level)
    }

    static var thermalState: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
    }
}
