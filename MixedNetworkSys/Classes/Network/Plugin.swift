//
//  Plugin.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/24/2021.
//

import Foundation

public protocol PluginType {
    
    var extraParameters: [String: Any]? { get }
    
    ///modify a request before sending.
    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest
    
    func willSend(_ request: URLRequest, target: TargetType?)
    
    func didReceive(_ result: Result<Response, NetError>, target: TargetType)
    
    func process(
        _ result: Result<Response, NetError>,
        target: TargetType
    ) -> Result<Response, NetError>
}

extension PluginType {
    public var extraParameters: [String: Any]? { return nil }
    public func prepare(_ request: URLRequest, target: TargetType) -> URLRequest { return request }
    public func willSend(_ request: URLRequest, target: TargetType?) {}
    public func didReceive(_ result: Result<Response, NetError>, target: TargetType) {}
    public func process(
        _ result: Result<Response, NetError>,
        target: TargetType
    ) -> Result<Response, NetError> {
        return result
    }
}
