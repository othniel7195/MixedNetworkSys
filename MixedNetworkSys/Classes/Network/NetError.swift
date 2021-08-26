//
//  NetError.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/25/2021.
//

import Foundation

public enum NetError: Error {
    case underlying(Error, Response?)
    case requestMapping(TargetType)
    case statusCode(Response)
    case jsonMapping(Response)
    case stringMapping(Response)
    case objectMapping(Error, Response)
}

extension NetError {
    public var response: Response? {
        switch self {
        case .jsonMapping(let response):
            return response
        case .stringMapping(let response):
            return response
        case .objectMapping(_, let response):
            return response
        case .statusCode(let response):
            return response
        case .underlying(_, let response):
            return response
        case .requestMapping:
            return nil
        }
    }
}


extension NetError: CustomStringConvertible, CustomDebugStringConvertible {
    public var debugDescription: String {
        return description
    }
    
    public var description: String {
        switch self {
        case .jsonMapping(let response):
            return "Failed to map data to JSON. \nAnd with response \(response)"
        case .stringMapping(let response):
            return "Failed to map data to a String. \nAnd with response \(response)"
        case .objectMapping(let error, let response):
            return """
      Failed to map data to a Decodable object with error \(error.localizedDescription).
      And with response \(response)
      """
        case .statusCode(let response):
            return "Status code didn't fall within the given range. \nAnd with response \(response)"
        case .requestMapping(let target):
            return "Failed to map Endpoint to a URLRequest. \nAnd with target \(target)"
        case .underlying(let error, let response):
            if let response = response {
                return """
        Indicates a response failed with error \(error.localizedDescription).
        And with response \(response)
        """
            } else {
                return "Indicates a response failed with error \(error.localizedDescription)"
            }
        }
    }
}

extension NetError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .jsonMapping:
            return "Failed to map data to JSON."
        case .stringMapping:
            return "Failed to map data to a String."
        case .objectMapping(let error, _):
            return "Failed to map data to a Decodable object with error \(error.localizedDescription)"
        case .statusCode:
            return "Status code didn't fall within the given range."
        case .requestMapping:
            return "Failed to map Endpoint to a URLRequest."
        case .underlying(let error, _):
            return error.localizedDescription
        }
    }
}
