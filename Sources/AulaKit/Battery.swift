import Foundation
import IOKit.hid

/// Battery level of the wireless links. The wired USB-C interface has no battery report, so the
/// level is only known over the 2.4 GHz dongle (vendor query) and Bluetooth (GATT Battery Service,
/// read in the app with CoreBluetooth).
///
/// Dongle protocol, from bacoinz/aula-studio `docs/protocol.md` ("2.4 GHz dongle"): the dongle's
/// vendor interface (usage page 0xFF60) takes 32-byte output reports `cmd len index data…` whose
/// last byte is the low byte of the sum of the others; the keyboard answers with an input report
/// starting with the same `cmd len index`. Battery is command 0x20, length 1, and the reply carries
/// the percentage in byte 3. A 0 means the keyboard is off, asleep or on another link.
public enum AulaBattery {
    public static let dongleUsagePage = 0xFF60
    static let reportSize = 32
    static let batteryCommand: UInt8 = 0x20

    /// The read-only battery query, checksum included.
    public static func dongleQuery() -> [UInt8] {
        var report = [UInt8](repeating: 0, count: reportSize)
        report[0] = batteryCommand
        report[1] = 0x01
        report[reportSize - 1] = checksum(report[0..<(reportSize - 1)])
        return report
    }

    static func checksum(_ bytes: ArraySlice<UInt8>) -> UInt8 {
        UInt8(truncatingIfNeeded: bytes.reduce(0) { $0 + Int($1) })
    }

    /// The percentage in a dongle reply, or nil when the reply isn't a battery answer or the
    /// keyboard didn't report a level.
    public static func level(fromDongleReply reply: [UInt8]) -> Int? {
        var bytes = reply
        // Tolerate a leading report ID 0, as Windows delivers it.
        if bytes.count == reportSize + 1, bytes.first == 0 { bytes.removeFirst() }
        guard bytes.count > 3, bytes[0] == batteryCommand, bytes[1] == 0x01, bytes[2] == 0x00 else { return nil }
        let level = Int(bytes[3])
        return level == 0 ? nil : min(level, 100)
    }

    /// Asks the dongle for the keyboard's battery level. Blocks for up to `timeout`; call it off the
    /// main thread. Returns nil when there is no dongle, it can't be opened, or the keyboard doesn't
    /// answer. Sends only the battery query, never a configuration command.
    public static func readFromDongle(timeout: TimeInterval = 0.5) -> Int? {
        guard let device = AulaDiscovery.dongleVendorDevice() else { return nil }
        guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { return nil }
        defer { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }

        final class Box { var level: Int? ; var done = false }
        let box = Box()
        let capacity = 64
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { buffer.deallocate() }

        let context = Unmanaged.passUnretained(box).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(device, buffer, capacity, { context, result, _, _, _, report, length in
            guard let context, result == kIOReturnSuccess else { return }
            let box = Unmanaged<Box>.fromOpaque(context).takeUnretainedValue()
            let bytes = Array(UnsafeBufferPointer(start: report, count: length))
            if let level = AulaBattery.level(fromDongleReply: bytes) {
                box.level = level
                box.done = true
            } else if bytes.count > 2, bytes[0] == AulaBattery.batteryCommand {
                box.done = true // A battery reply without a level: the keyboard is asleep or away.
            }
        }, context)

        guard let runLoop = CFRunLoopGetCurrent() else { return nil }
        IOHIDDeviceScheduleWithRunLoop(device, runLoop, CFRunLoopMode.defaultMode.rawValue)
        defer {
            IOHIDDeviceRegisterInputReportCallback(device, buffer, capacity, nil, nil)
            IOHIDDeviceUnscheduleFromRunLoop(device, runLoop, CFRunLoopMode.defaultMode.rawValue)
        }

        let query = dongleQuery()
        guard IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0, query, query.count) == kIOReturnSuccess else {
            return nil
        }
        let deadline = Date().addingTimeInterval(timeout)
        while !box.done, Date() < deadline {
            CFRunLoopRunInMode(.defaultMode, 0.05, true)
        }
        return box.level
    }
}
