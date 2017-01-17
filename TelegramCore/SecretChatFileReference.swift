import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

final class SecretChatFileReference: Coding {
    let id: Int64
    let accessHash: Int64
    let size: Int32
    let datacenterId: Int32
    let keyFingerprint: Int32
    
    init(id: Int64, accessHash: Int64, size: Int32, datacenterId: Int32, keyFingerprint: Int32) {
        self.id = id
        self.accessHash = accessHash
        self.size = size
        self.datacenterId = datacenterId
        self.keyFingerprint = keyFingerprint
    }
    
    init(decoder: Decoder) {
        self.id = decoder.decodeInt64ForKey("i")
        self.accessHash = decoder.decodeInt64ForKey("a")
        self.size = decoder.decodeInt32ForKey("s")
        self.datacenterId = decoder.decodeInt32ForKey("d")
        self.keyFingerprint = decoder.decodeInt32ForKey("f")
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.id, forKey: "i")
        encoder.encodeInt64(self.accessHash, forKey: "a")
        encoder.encodeInt32(self.size, forKey: "s")
        encoder.encodeInt32(self.datacenterId, forKey: "d")
        encoder.encodeInt32(self.keyFingerprint, forKey: "f")
    }
}

extension SecretChatFileReference {
    convenience init?(_ file: Api.EncryptedFile) {
        switch file {
            case let .encryptedFile(id, accessHash, size, dcId, keyFingerprint):
                self.init(id: id, accessHash: accessHash, size: size, datacenterId: dcId, keyFingerprint: keyFingerprint)
            case .encryptedFileEmpty:
                return nil
        }
    }
}
