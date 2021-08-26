//
//  DNSRecord.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/23/2021.
//

import Foundation

public typealias TTL = TimeInterval

public struct DNSRecord {
    public let ip: IP
    public let ttl: TTL
    public init(ip: IP, ttl: TTL) {
        self.ip = ip
        self.ttl = ttl
    }
}
