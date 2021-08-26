//
//  URL+NetExt.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/23/2021.
//

import Foundation

extension URL {
    func network_replacingHost(_ host: String, with newHost: String) -> URL? {
        guard let range = absoluteString.range(of: host) else { return nil }
        let newURLString = absoluteString.replacingCharacters(in: range, with: newHost)
        return URL(string: newURLString)
    }
}
