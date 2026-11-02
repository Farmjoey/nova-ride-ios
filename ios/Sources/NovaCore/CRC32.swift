import Foundation

/// Standard CRC-32 (zlib / IEEE), same as the board verifies.
public enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
        return c
    }
    public static func checksum(_ data: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xFFFF_FFFF
        for b in data { c = table[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        return c ^ 0xFFFF_FFFF
    }
}

/// Checks a firmware file before it is sent (the board checks again).
public struct FirmwareCheck: Equatable {
    public var ok: Bool
    public var message: String
    public var crc: UInt32
    public var size: Int
}

public enum Firmware {
    public static func check(_ data: [UInt8], fileName: String = "") -> FirmwareCheck {
        let size = data.count
        let crc = CRC32.checksum(data)
        if fileName.lowercased().contains("factory") {
            return FirmwareCheck(ok: false, message: "Det her er en .factory.bin (til første flash over USB). Vælg den almindelige .bin.", crc: crc, size: size)
        }
        if size < Nova.minAppBytes || size > Nova.maxAppBytes {
            return FirmwareCheck(ok: false, message: "Filstørrelsen er forkert (64 KB til 1,9 MB).", crc: crc, size: size)
        }
        if data[0] != 0xE9 {
            return FirmwareCheck(ok: false, message: "Ikke en ESP32-firmware (.bin)", crc: crc, size: size)
        }
        if data.count > 13, data[12] != 0 || data[13] != 0 {
            return FirmwareCheck(ok: false, message: "Filen er ikke til en almindelig ESP32.", crc: crc, size: size)
        }
        return FirmwareCheck(ok: true, message: "Filen ser rigtig ud.", crc: crc, size: size)
    }
}

/// 128 x 64 boot picture: grayscale in, 1 bit per pixel out (row-major, MSB first).
public enum BootImage {
    /// `gray` holds 128*64 luminance values 0...255.
    public static func pack(gray: [UInt8], threshold: Int, invert: Bool) -> [UInt8] {
        var bits = [UInt8](repeating: 0, count: Nova.bootImageBytes)
        guard gray.count >= Nova.bootImageWidth * Nova.bootImageHeight else { return bits }
        for y in 0..<Nova.bootImageHeight {
            for x in 0..<Nova.bootImageWidth {
                let i = y * Nova.bootImageWidth + x
                var on = Int(gray[i]) > threshold
                if invert { on.toggle() }
                if on { bits[i >> 3] |= UInt8(0x80 >> (i & 7)) }
            }
        }
        return bits
    }
    public static func pixel(_ bits: [UInt8], x: Int, y: Int) -> Bool {
        guard x >= 0, y >= 0, x < Nova.bootImageWidth, y < Nova.bootImageHeight else { return false }
        let i = y * Nova.bootImageWidth + x
        return bits[i >> 3] & UInt8(0x80 >> (i & 7)) != 0
    }
}
