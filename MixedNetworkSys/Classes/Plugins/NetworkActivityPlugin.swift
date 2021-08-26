//
//  NetworkActivityPlugin.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/24/2021.
//

import Foundation

public enum NetworkActivityChangeType {
    case began, ended
}

public final class NetworkActivityPlugin: PluginType {
    public typealias NetworkActivityClosure = (
        _ change: NetworkActivityChangeType,
        _ target: TargetType?
    ) -> Void
    
    let networkActivityClosure: NetworkActivityClosure
    
    public init(networkActivityClosure: @escaping NetworkActivityClosure) {
        self.networkActivityClosure = networkActivityClosure
    }
    
    public func willSend(_ request: URLRequest, target: TargetType?) {
        networkActivityClosure(.began, target)
    }
    
    public func didReceive(_ result: Result<Response, NetError>, target: TargetType) {
        networkActivityClosure(.ended, target)
    }
}
