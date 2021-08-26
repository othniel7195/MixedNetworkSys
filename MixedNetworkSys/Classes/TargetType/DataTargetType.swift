//
//  DataTargetType.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/24/2021.
//

import Foundation

public protocol DataTargetType: TargetType {
    var baseURL: URL { get }
    var path: String { get }
}

extension DataTargetType {
    
    public var validation: ValidationType {
        return .successCodes
    }
    
    public var parameters: [String: Any]? {
        return nil
    }
    
    public var headers: [String: String]? {
        return nil
    }
    
    public var fullRequestURL: URL {
        return makeFullRequestURL(withBaseURL: baseURL)
    }
    
    public var priority: Float {
        return 0.5
    }
    
    public var timeoutInterval: TimeInterval? {
        return nil
    }
    
    public func makeFullRequestURL(withBaseURL baseURL: URL) -> URL {
        var finalBaseURL = baseURL
        if finalBaseURL.path.count > 0 && !finalBaseURL.absoluteString.hasSuffix("/") {
            finalBaseURL = finalBaseURL.appendingPathComponent("")
        }
        if let url = URL(string: path, relativeTo: finalBaseURL) {
            return url
        } else {
            fatalError("\(baseURL) relative \(path) failed, please double check.")
        }
    }
}
