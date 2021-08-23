//
//  NetRequestInterceptor.swift
//  MixedNetworkSys
//
//  Created by jimmy on 2021/8/23.
//

import Foundation
import Alamofire

public final class NetRequestInterceptor: RequestInterceptor {
    private let plugins: [PluginType]
    var targetType: TargetType?
    init(_ plugins: [PluginType]) {
        self.plugins = plugins
    }
    public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        plugins.forEach {
            $0.willSend(urlRequest, target: self.targetType)
        }
        completion(.success(urlRequest))
    }
}
