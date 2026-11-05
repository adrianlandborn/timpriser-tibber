// Print the CoreGraphics window id of the on-screen Connect IQ simulator window (empty if none).
// Used by scripts/device-smoke.sh so only that window is captured, never the desktop.
import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows {
    let owner = (window[kCGWindowOwnerName as String] as? String ?? "").lowercased()
    let name = window[kCGWindowName as String] as? String ?? ""
    if owner.contains("simulator") && name.hasPrefix("CIQ Simulator") {
        print(window[kCGWindowNumber as String] ?? "")
        break
    }
}
