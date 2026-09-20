import Foundation
import IOKit.ps

final class BatteryMonitor {
    var onUpdate: ((_ level: Int, _ charging: Bool, _ changedChargingState: Bool) -> Void)?

    private var timer: Timer?
    private var lastCharging: Bool?

    func start() {
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let source = list.first,
              let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else {
            return
        }

        let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
        let maximum = max(1, description[kIOPSMaxCapacityKey] as? Int ?? 100)
        let level = max(0, min(100, Int((Double(current) / Double(maximum) * 100).rounded())))
        let charging = description[kIOPSIsChargingKey] as? Bool ?? false
        let changed = lastCharging != nil && lastCharging != charging
        lastCharging = charging

        onUpdate?(level, charging, changed)
    }
}
