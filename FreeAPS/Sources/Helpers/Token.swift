//
//  Token.swift
//  FreeAPS
//
//  Created by Richard on 13.11.24.
//
import Foundation
final class Token {
    func getIdentifier() -> String {
        let keychain = BaseKeychain()
        var identfier = keychain.getValue(String.self, forKey: IAPSconfig.id) ?? ""
        guard identfier.count > 1 else {
            identfier = UUID().uuidString
            keychain.setValue(identfier, forKey: IAPSconfig.id)
            return identfier
        }
        return identfier
    }
}
