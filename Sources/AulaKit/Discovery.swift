import Foundation
import IOKit.hid
import CoreGraphics

public enum AulaConnectionKind: String, Codable, Sendable {
    case wired
    case dongle
    case bluetooth
    case absent

    public var title: String {
        switch self {
        case .wired: return "USB wired"
        case .dongle: return "2.4 GHz"
        case .bluetooth: return "Bluetooth"
        case .absent: return "Not connected"
        }
    }

    public var supportsHardwareConfig: Bool { self == .wired }

    public var symbol: String {
        switch self {
        case .wired: return "cable.connector"
        case .dongle: return "usb"
        case .bluetooth: return "dot.radiowaves.left.and.right"
        case .absent: return "keyboard"
        }
    }
}

public struct AulaConnectionInfo: Equatable, Sendable {
    public var kind: AulaConnectionKind
    public var product: String
    public var manufacturer: String
    public var transport: String
    public var uniqueID: String?
    public var locationID: Int?
    public var vendorID: Int
    public var productID: Int

    public init(
        kind: AulaConnectionKind,
        product: String = "",
        manufacturer: String = "",
        transport: String = "",
        uniqueID: String? = nil,
        locationID: Int? = nil,
        vendorID: Int = 0,
        productID: Int = 0
    ) {
        self.kind = kind
        self.product = product
        self.manufacturer = manufacturer
        self.transport = transport
        self.uniqueID = uniqueID
        self.locationID = locationID
        self.vendorID = vendorID
        self.productID = productID
    }

    public static let absent = AulaConnectionInfo(kind: .absent)
}

public enum AulaDiscovery {
    /// Normalises vendor product strings: wired is "AULA F108Pro", Bluetooth is
    /// "AULA-F108Pro-1" and the dongle is "F108Pro Dongle".
    public static func looksLikeF108Pro(_ product: String) -> Bool {
        var normalized = product.lowercased()
        for character in [" ", "-", "_"] {
            normalized = normalized.replacingOccurrences(of: character, with: "")
        }
        return (normalized.contains("aula") && normalized.contains("f108"))
            || normalized.contains("f108pro")
    }

    private static func string(_ device: IOHIDDevice, _ key: String) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }

    /// Whether Karabiner's virtual keyboard is present. If Karabiner grabs the
    /// F108 Pro, macOS sees only the virtual keyboard and per-device matching
    /// cannot identify the physical device.
    public static func karabinerVirtualKeyboardPresent() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, nil)
        guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return false }
        return set.contains { (string($0, kIOHIDProductKey) ?? "").localizedCaseInsensitiveContains("Karabiner") }
    }

    private static func int(_ device: IOHIDDevice, _ key: String) -> Int? {
        IOHIDDeviceGetProperty(device, key as CFString) as? Int
    }

    private static func devices(vendor: Int, product: Int) -> [IOHIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: vendor,
            kIOHIDProductIDKey: product,
        ] as CFDictionary)
        guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        return Array(set)
    }

    private static func hasUsagePage(_ device: IOHIDDevice, _ page: Int) -> Bool {
        if int(device, kIOHIDPrimaryUsagePageKey) == page { return true }
        if let pairs = IOHIDDeviceGetProperty(device, kIOHIDDeviceUsagePairsKey as CFString) as? [[String: Int]] {
            return pairs.contains { $0[kIOHIDDeviceUsagePageKey] == page }
        }
        return false
    }

    /// All HID services belonging to the keyboard, for diagnostics.
    public static func allAulaDevices() -> [IOHIDDevice] {
        var result: [IOHIDDevice] = []
        result += devices(vendor: F108.vendorID, product: F108.productID)
        result += devices(vendor: F108.wirelessVendorID, product: F108.wirelessProductID)
            .filter { (string($0, kIOHIDProductKey) ?? "").lowercased().contains("f108") }
        return result
    }

    public static func detect() -> AulaConnectionInfo {
        let wired = devices(vendor: F108.vendorID, product: F108.productID)
        if let device = wired.first(where: { hasUsagePage($0, F108.configUsagePage) }) {
            return AulaConnectionInfo(
                kind: .wired,
                product: string(device, kIOHIDProductKey) ?? "AULA F108Pro",
                manufacturer: string(device, kIOHIDManufacturerKey) ?? "AULA",
                transport: string(device, kIOHIDTransportKey) ?? "USB",
                uniqueID: string(device, kIOHIDPhysicalDeviceUniqueIDKey),
                locationID: int(device, kIOHIDLocationIDKey),
                vendorID: F108.vendorID,
                productID: F108.productID
            )
        }

        let wireless = devices(vendor: F108.wirelessVendorID, product: F108.wirelessProductID)
            .filter { (string($0, kIOHIDProductKey) ?? "").lowercased().contains("f108") }
        if let device = wireless.first(where: { (string($0, kIOHIDTransportKey) ?? "").uppercased() == "USB" }) {
            return AulaConnectionInfo(
                kind: .dongle,
                product: string(device, kIOHIDProductKey) ?? "F108Pro Dongle",
                manufacturer: string(device, kIOHIDManufacturerKey) ?? "AULA",
                transport: string(device, kIOHIDTransportKey) ?? "USB",
                uniqueID: string(device, kIOHIDPhysicalDeviceUniqueIDKey),
                locationID: int(device, kIOHIDLocationIDKey),
                vendorID: F108.wirelessVendorID,
                productID: F108.wirelessProductID
            )
        }

        // Bluetooth HID over GATT. macOS reports the product name including the
        // Bluetooth slot, e.g. "AULA-F108Pro-1".
        let appleDevices = devices(vendor: F108.wirelessVendorID, product: F108.wirelessProductID)
        if let device = appleDevices.first(where: {
            looksLikeF108Pro(string($0, kIOHIDProductKey) ?? "")
        }) {
            return AulaConnectionInfo(
                kind: .bluetooth,
                product: string(device, kIOHIDProductKey) ?? "AULA-F108Pro",
                manufacturer: string(device, kIOHIDManufacturerKey) ?? "",
                transport: string(device, kIOHIDTransportKey) ?? "Bluetooth Low Energy",
                uniqueID: string(device, kIOHIDPhysicalDeviceUniqueIDKey),
                locationID: int(device, kIOHIDLocationIDKey),
                vendorID: F108.wirelessVendorID,
                productID: F108.wirelessProductID
            )
        }

        return .absent
    }

    /// The 2.4 GHz dongle's vendor interface (usage page 0xFF60), used only for the battery query.
    public static func dongleVendorDevice() -> IOHIDDevice? {
        devices(vendor: F108.wirelessVendorID, product: F108.wirelessProductID)
            .filter { (string($0, kIOHIDProductKey) ?? "").lowercased().contains("f108") }
            .filter { (string($0, kIOHIDTransportKey) ?? "").uppercased() == "USB" }
            .first { hasUsagePage($0, AulaBattery.dongleUsagePage) }
    }

    public static func wiredConfigDevice() -> IOHIDDevice? {
        let wired = devices(vendor: F108.vendorID, product: F108.productID)
        return wired.first { hasUsagePage($0, F108.configUsagePage) }
    }

    /// Opens the wired configuration interface. Throws a descriptive error when
    /// the keyboard is only available over Bluetooth/2.4 GHz.
    public static func openWired() throws -> AulaDevice {
        let connection = detect()
        guard connection.kind == .wired else {
            throw connection.kind == .bluetooth || connection.kind == .dongle
                ? AulaError.bluetoothOnly : AulaError.notFound
        }
        guard let device = wiredConfigDevice() else {
            throw AulaError.missingInterface("configuration (0xFF13)")
        }
        return AulaDevice(transport: try IOHIDTransport(device: device))
    }

    /// Resolves the IORegistry sender of a CGEvent (the undocumented field 87)
    /// to an IOHIDDevice, then checks whether it is the AULA keyboard.
    public static func eventIsFromAula(_ event: CGEvent) -> Bool {
        guard let field = CGEventField(rawValue: 87) else { return false }
        let raw = event.getIntegerValueField(field)
        let sender = UInt64(bitPattern: raw)
        guard sender != 0 else { return false }
        return isAulaRegistryID(sender)
    }

    /// Robust identity check: wired devices match by the Sonix VID/PID even if
    /// the product string is localised, while Bluetooth/dongle match by name.
    public static func isAulaRegistryID(_ sender: UInt64) -> Bool {
        guard let matching = IORegistryEntryIDMatching(sender) else { return false }
        var service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }

        var depth = 0
        while depth < 8 {
            if let device = IOHIDDeviceCreate(kCFAllocatorDefault, service) {
                let vendor = int(device, kIOHIDVendorIDKey) ?? 0
                let productID = int(device, kIOHIDProductIDKey) ?? 0
                if vendor == F108.vendorID && productID == F108.productID { return true }
                return looksLikeF108Pro(string(device, kIOHIDProductKey) ?? "")
            }
            var parent: io_registry_entry_t = 0
            guard IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent) == KERN_SUCCESS,
                  parent != 0 else { return false }
            IOObjectRelease(service)
            service = parent
            depth += 1
        }
        return false
    }

    public static func productName(forRegistryID sender: UInt64) -> String? {
        guard let matching = IORegistryEntryIDMatching(sender) else { return nil }
        var service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var depth = 0
        while depth < 8 {
            if let device = IOHIDDeviceCreate(kCFAllocatorDefault, service) {
                let product = string(device, kIOHIDProductKey)
                return product
            }
            var parent: io_registry_entry_t = 0
            guard IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent) == KERN_SUCCESS,
                  parent != 0 else { return nil }
            IOObjectRelease(service)
            service = parent
            depth += 1
        }
        return nil
    }
}
