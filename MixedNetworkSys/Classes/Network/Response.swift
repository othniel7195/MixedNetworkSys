//
//  Response.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/26/2021.
//

import Foundation

public final class Response: CustomDebugStringConvertible, Equatable {
    public let statusCode: Int
    public let data: Data
    public let request: URLRequest?
    public let response: HTTPURLResponse?
    
    public init(statusCode: Int?, data: Data?, request: URLRequest? = nil, response: HTTPURLResponse? = nil) {
        //400 == client error with the case about response is nil
        self.statusCode = statusCode ?? 400
        self.data = data ?? Data()
        self.request = request
        self.response = response
    }
    
    public var description: String {
        var result = "Status Code: \(statusCode), Data Length: \(data.count)"
        if let dataString = String(data: data, encoding: .utf8) {
            result += ", Data String: \n\(dataString)"
        }
        return result
    }
    
    public var debugDescription: String {
        return description
    }
    
    public static func == (lhs: Response, rhs: Response) -> Bool {
        return lhs.statusCode == rhs.statusCode
            && lhs.data == rhs.data
            && lhs.response == rhs.response
    }
}


extension Response {
    
    public func filter(statusCodes: ClosedRange<Int>) throws -> Response {
        guard statusCodes.contains(statusCode) else {
            throw NetError.statusCode(self)
        }
        return self
    }
    
    public func filter(statusCode: Int) throws -> Response {
        return try filter(statusCodes: statusCode...statusCode)
    }
    
    public func filterSuccessfulStatusCodes() throws -> Response {
        return try filter(statusCodes: 200...299)
    }
    
    public func filterSuccessfulStatusAndRedirectCodes() throws -> Response {
        return try filter(statusCodes: 200...399)
    }
    
    public func mapString(atKeyPath keyPath: String? = nil) throws -> String {
        if let keyPath = keyPath {
            guard let jsonDictionary = try mapJSON() as? NSDictionary,
                  let string = jsonDictionary.value(forKey: keyPath) as? String
            else {
                throw NetError.stringMapping(self)
            }
            return string
        } else {
            guard let string = String(data: data, encoding: .utf8) else {
                throw NetError.stringMapping(self)
            }
            return string
        }
    }
    
    public func mapJSON(failsOnEmptyData: Bool = true) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        } catch {
            if data.count < 1 && !failsOnEmptyData {
                return NSNull()
            }
            throw NetError.jsonMapping(self)
        }
    }
    
    public func map<D: Decodable>(_ type: D.Type, atKeyPath keyPath: String? = nil, using decoder: JSONDecoder = JSONDecoder(), failsOnEmptyData: Bool = true) throws -> D {
        let serializeToData: (Any) throws -> Data? = { (jsonObject) in
            guard JSONSerialization.isValidJSONObject(jsonObject) else {
                return nil
            }
            do {
                return try JSONSerialization.data(withJSONObject: jsonObject)
            } catch {
                throw NetError.jsonMapping(self)
            }
        }
        
        let jsonData: Data
        keyPathCheck: if let keyPath = keyPath {
            let _jsonObject = (try mapJSON(failsOnEmptyData: failsOnEmptyData) as? NSDictionary)?.value(
                forKeyPath: keyPath
            )
            guard let jsonObject = _jsonObject else {
                if failsOnEmptyData {
                    throw NetError.jsonMapping(self)
                } else {
                    jsonData = data
                    break keyPathCheck
                }
            }
            
            if let data = try serializeToData(jsonObject) {
                jsonData = data
            } else {
                let wrappedJsonObject = ["value": jsonObject]
                let wrappedJsonData: Data
                if let data = try serializeToData(wrappedJsonObject) {
                    wrappedJsonData = data
                } else {
                    throw NetError.jsonMapping(self)
                }
                do {
                    return try decoder.decode(DecodableWrapper<D>.self, from: wrappedJsonData).value
                } catch let error {
                    throw NetError.objectMapping(error, self)
                }
            }
        } else {
            jsonData = data
        }
        
        do {
            if jsonData.count < 1 && !failsOnEmptyData {
                if let emptyJSONObjectData = "{}".data(using: .utf8),
                   let emptyDecodableValue = try? decoder.decode(D.self, from: emptyJSONObjectData)
                {
                    return emptyDecodableValue
                }
                else if let emptyJSONArrayData = "[{}]".data(using: .utf8),
                        let emptyDecodableValue = try? decoder.decode(D.self, from: emptyJSONArrayData)
                {
                    return emptyDecodableValue
                }
            }
            return try decoder.decode(D.self, from: jsonData)
        } catch let error {
            debugPrint(error)
            throw NetError.objectMapping(error, self)
        }
    }
}

private struct DecodableWrapper<T: Decodable>: Decodable {
    let value: T
}
