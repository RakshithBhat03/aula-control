import Foundation
import IOKit.hid

/// Low-level 64-byte feature-report transport. Abstracted so the protocol can
/// be exercised without hardware (see the CLI `--dry-run` mode and unit tests).
public protocol AulaTransport: AnyObject {
    func setFeature(_ report: [UInt8]) throws
    func getFeature() throws -> [UInt8]
    func close()
}

/// IOKit implementation. Opens only the vendor configuration interface
/// (usage page 0xFF13), never the keyboard input interface.
public final class IOHIDTransport: AulaTransport {
    private var device: IOHIDDevice?
    public var log: ((String) -> Void)?

    public init(device: IOHIDDevice) throws {
        self.device = device
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            self.device = nil
            throw AulaError.io("Opening the configuration interface", result)
        }
    }

    deinit {
        close()
    }

    public func setFeature(_ report: [UInt8]) throws {
        guard let device else { throw AulaError.transportClosed }
        var buffer = [UInt8](repeating: 0, count: F108.reportSize)
        buffer.replaceSubrange(0..<min(report.count, buffer.count), with: report.prefix(buffer.count))
        let result = IOHIDDeviceSetReport(
            device, kIOHIDReportTypeFeature, 0, buffer, buffer.count
        )
        guard result == kIOReturnSuccess else {
            throw AulaError.io("SET_REPORT", result)
        }
        log?("SET  " + buffer.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))
    }

    public func getFeature() throws -> [UInt8] {
        guard let device else { throw AulaError.transportClosed }
        var buffer = [UInt8](repeating: 0, count: F108.reportSize)
        var length = CFIndex(buffer.count)
        let result = IOHIDDeviceGetReport(
            device, kIOHIDReportTypeFeature, 0, &buffer, &length
        )
        guard result == kIOReturnSuccess else {
            throw AulaError.io("GET_REPORT", result)
        }
        log?("GET  " + buffer.prefix(8).map { String(format: "%02X", $0) }.joined(separator: " "))
        return buffer
    }

    public func close() {
        guard let device else { return }
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        self.device = nil
    }
}

/// A transport that records every report and fabricates acknowledgements.
/// Used by `aula --dry-run` and by the app's simulator.
public final class RecordingTransport: AulaTransport {
    public private(set) var sent: [[UInt8]] = []
    public var lastCommand: [UInt8] = []

    public init() {}

    public func setFeature(_ report: [UInt8]) throws {
        var buffer = [UInt8](repeating: 0, count: F108.reportSize)
        buffer.replaceSubrange(0..<min(report.count, buffer.count), with: report.prefix(buffer.count))
        sent.append(buffer)
        lastCommand = buffer
    }

    public func getFeature() throws -> [UInt8] {
        var ack = [UInt8](repeating: 0, count: F108.reportSize)
        if lastCommand.count >= 2 {
            ack[0] = lastCommand[0]
            ack[1] = lastCommand[1]
        }
        ack[3] = 0x01
        return ack
    }

    public func close() {}
}
