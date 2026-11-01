import CoreBluetooth
import AulaKit

/// Reads the keyboard's battery level over Bluetooth from the standard GATT Battery Service
/// (0x180F, Battery Level 0x2A19). macOS doesn't publish a battery level for this keyboard itself,
/// because it isn't an Apple accessory, so the app reads it from the already-connected peripheral.
/// Read-only: it only reads the Battery Level characteristic (no notification subscription, which
/// would write the descriptor), and never disconnects the keyboard.
///
/// Started only while the keyboard is connected over Bluetooth, so USB users never see the
/// Bluetooth permission prompt.
final class BluetoothBatteryMonitor: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var onChange: ((Int?) -> Void)?

    private static let batteryService = CBUUID(string: "180F")
    private static let batteryLevel = CBUUID(string: "2A19")

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var refreshTimer: Timer?

    func start() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: .main)
        // Battery moves slowly; a read a minute keeps it current without subscribing.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        peripheral?.delegate = nil
        peripheral = nil
        characteristic = nil
        central?.delegate = nil
        central = nil
        onChange?(nil)
    }

    private func refresh() {
        if let peripheral, let characteristic, peripheral.state == .connected {
            peripheral.readValue(for: characteristic)
        } else {
            findKeyboard()
        }
    }

    private func findKeyboard() {
        guard let central, central.state == .poweredOn else { return }
        let match = central.retrieveConnectedPeripherals(withServices: [Self.batteryService])
            .first { AulaDiscovery.looksLikeF108Pro($0.name ?? "") }
        guard let match else { return }
        peripheral = match
        match.delegate = self
        // The keyboard is already connected to the Mac; this only opens the app's GATT session.
        central.connect(match)
    }

    // MARK: CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            findKeyboard()
        } else {
            peripheral = nil
            characteristic = nil
            onChange?(nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.batteryService])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        characteristic = nil
        self.peripheral = nil
        onChange?(nil)
        // The keyboard may come straight back (sleep, slot switch); look again shortly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.findKeyboard() }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.peripheral = nil
    }

    // MARK: CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.batteryService }) else { return }
        peripheral.discoverCharacteristics([Self.batteryLevel], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let level = service.characteristics?.first(where: { $0.uuid == Self.batteryLevel }) else { return }
        characteristic = level
        peripheral.readValue(for: level)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.uuid == Self.batteryLevel, let byte = characteristic.value?.first else { return }
        onChange?(min(Int(byte), 100))
    }
}
