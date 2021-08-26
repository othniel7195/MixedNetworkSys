//
//  DNSResult.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/23/2021.
//

import Foundation

public struct HTTPDNSResult: Hashable {
    
    public let dnsRecord: DNSRecord
    
    ///识别是否缓存的数据, 当失败时 去标记缓存失效
    public internal(set) var fromCached: Bool
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(dnsRecord.ip.address)
    }
    
    public static func == (lhs: HTTPDNSResult, rhs: HTTPDNSResult) -> Bool {
        return lhs.dnsRecord.ip.address == rhs.dnsRecord.ip.address
    }
    
    public var ip: IP {
        return dnsRecord.ip
    }
    
    public var ipAddress: String {
        return dnsRecord.ip.address
    }
    
    let timeout: TimeInterval
}
