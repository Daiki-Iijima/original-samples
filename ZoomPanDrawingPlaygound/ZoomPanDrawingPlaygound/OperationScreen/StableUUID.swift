import Foundation
import CryptoKit

enum StableUUID {
    /// 同じ input なら必ず同じ UUID を返す（SHA256の先頭16バイトを利用）
    static func make(_ input: String) -> UUID {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        let bytes = Array(hash) // 32 bytes

        let uuidBytes: [UInt8] = Array(bytes.prefix(16))
        let tuple: uuid_t = (
            uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
            uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
            uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
            uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]
        )
        return UUID(uuid: tuple)
    }
}
