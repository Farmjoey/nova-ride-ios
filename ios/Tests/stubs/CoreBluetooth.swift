// Stand-in for Apple's CoreBluetooth, only to type-check the app on a PC. Signatures follow the real API.
import Foundation
public let CBCentralManagerScanOptionAllowDuplicatesKey = "kCBScanOptionAllowDuplicates"
public let CBAdvertisementDataLocalNameKey = "kCBAdvDataLocalName"
public struct CBUUID: Equatable { public init(string: String) {} }
public enum CBManagerState: Int { case unknown, resetting, unsupported, unauthorized, poweredOff, poweredOn }
public enum CBCharacteristicWriteType: Int { case withResponse, withoutResponse }
open class CBAttribute { public var uuid = CBUUID(string: "") }
open class CBService: CBAttribute { public var characteristics: [CBCharacteristic]? }
open class CBCharacteristic: CBAttribute { public var value: Data?; public var isNotifying = false }
public protocol CBPeripheralDelegate: AnyObject {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?)
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?)
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?)
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?)
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?)
}
open class CBPeripheral: NSObject {
    public var name: String?
    public var services: [CBService]?
    public weak var delegate: CBPeripheralDelegate?
    public var canSendWriteWithoutResponse: Bool { true }
    public func discoverServices(_ serviceUUIDs: [CBUUID]?) {}
    public func discoverCharacteristics(_ characteristicUUIDs: [CBUUID]?, for service: CBService) {}
    public func setNotifyValue(_ enabled: Bool, for characteristic: CBCharacteristic) {}
    public func writeValue(_ data: Data, for characteristic: CBCharacteristic, type: CBCharacteristicWriteType) {}
}
public protocol CBCentralManagerDelegate: AnyObject {
    func centralManagerDidUpdateState(_ central: CBCentralManager)
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber)
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral)
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?)
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?)
}
open class CBCentralManager: NSObject {
    public var state: CBManagerState { .unknown }
    public init(delegate: CBCentralManagerDelegate?, queue: DispatchQueue?) {}
    public func scanForPeripherals(withServices serviceUUIDs: [CBUUID]?, options: [String: Any]? = nil) {}
    public func stopScan() {}
    public func connect(_ peripheral: CBPeripheral, options: [String: Any]? = nil) {}
    public func cancelPeripheralConnection(_ peripheral: CBPeripheral) {}
}
