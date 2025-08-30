import Foundation
import KeychainAccess

struct KeychainService {
    let service: String
    let account: String

    func set(_ value: String) throws {
        let kc = Keychain(service: service)
        try kc
            .label("ClaudeCode API Key")
            .synchronizable(false)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
            .set(value, key: account)
    }

    func get() throws -> String? {
        let kc = Keychain(service: service)
        return try kc.get(account)
    }

    func remove() throws {
        let kc = Keychain(service: service)
        try kc.remove(account)
    }
}
