//
//  MixedNetworkProvider.swift
//  MixedNetworkSys
//
//  Created by jimmy on 2021/8/25.
//

import Foundation

public final class MixedNetworkProvider {
    ///降级策略
    public enum FallbackStrategy {
        /// Normal -> HTTPDNS->CDN
        case `default`
        
        /// HTTPDNS -> Normal/CDN
        case httpDNSFirst
        // CDN -> Normal
        case CDNFirst
        
    }
    
    private let fallbackStrategy: FallbackStrategy
    private let normalStage: NetworkProvider
    private let dnsStage: NetworkProvider
    private let cdnStage: NetworkProvider
    
    public init(configuration: NetworkURLSessionConfiguration,
                plugins: [PluginType] = [],
                hosts: [String],
                callbackQueue: DispatchQueue = .main,
                cdnHostOfOriginalHost: ((String) -> String?)? = nil) {
        self.fallbackStrategy = .default
        
    }
}
