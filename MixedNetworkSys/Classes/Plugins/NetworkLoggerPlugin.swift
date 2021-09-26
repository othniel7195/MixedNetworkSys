//
//  NetworkLoggerPlugin.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/24/2021.
//

import Foundation

public final class NetworkLoggerPlugin: PluginType {
    
    fileprivate let requestDataFormatter: ((Data) -> (String))?
    fileprivate let responseDataFormatter: ((Data) -> (Data))?
    fileprivate let output: (_ logOutString: String) -> Void
    fileprivate let dateFormatString = "yyyy-MM-dd HH:mm:ss.SSS"
    fileprivate let dateFormatter = DateFormatter()
    fileprivate let loggerId = "Network"
    
    public let cURL: Bool
    
    public init(cURL: Bool = false,
                output: ((_ logOutString: String) -> Void)? = nil,
                requestDataFormatter: ((Data) -> (String))? = nil,
                responseDataFormatter: ((Data) -> (Data))? = nil) {
        self.cURL = cURL
        self.output = output ?? NetworkLoggerPlugin.reversePrint
        self.requestDataFormatter = requestDataFormatter
        self.responseDataFormatter = responseDataFormatter
    }
    
    public func willSend(_ request: URLRequest, target: TargetType?) {
        if cURL {
            output(request.cURLRepresentation())
        } else {
            output(logNetworkRequest(request))
        }
    }
    
    public func didReceive(_ result: Result<Response, NetError>, target: TargetType) {
        switch result {
        case .success(let response):
            output(logNetworkResponse(response.response, data: response.data, error: nil, target: target))
        case .failure(let error):
            output(logNetworkResponse(nil, data: nil, error: error, target: target))
        }
    }
    
}


extension NetworkLoggerPlugin {
    
    fileprivate var date: String {
        dateFormatter.dateFormat = dateFormatString
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        return dateFormatter.string(from: Date())
    }
    
    fileprivate func logNetworkRequest(_ request: URLRequest?) -> String {
        var logString = "\(loggerId): [\(date)] Request: \(request?.description ?? "(invalid request)")"
        
        if let headers = request?.allHTTPHeaderFields {
            logString += "\nRequest Headers: \(headers)"
        }
        
        if let bodyStream = request?.httpBodyStream {
            logString += "\nRequest Body Stream: \(bodyStream.description)"
        }
        
        if let httpMethod = request?.httpMethod {
            logString += "\nHTTP Request Method: \(httpMethod)"
        }
        
        if let body = request?.httpBody,
           let stringOutput = requestDataFormatter?(body) ?? String(data: body, encoding: .utf8) {
            logString += "\nHTTP Request Body: \(stringOutput)"
        }
        
        return logString
    }
    
    fileprivate func logNetworkResponse(_ response: HTTPURLResponse?,
                                        data: Data?,
                                        error: NetError?,
                                        target: TargetType) -> String {
        var logString = error.flatMap {
            "\(loggerId): [\(date)] Response: Received error for \(target). Error is \($0).\nResponse:\(error?.response?.response?.description ?? "NULL")"
        } ?? "\(loggerId): [\(date)] Response: \(response?.description ?? "mock data")"
        
        let logData: Data? = data ?? error?.response?.data
        logData.flatMap { responseDataFormatter?($0) ?? $0 }
            .flatMap { String(data: $0, encoding: .utf8) }
            .map { logString += "\nHTTP Response Data: \($0)" }
        
        return logString
    }
    
    fileprivate static func reversePrint(_ logOutString: String) {
        print(logOutString)
    }
    
}

extension URLRequest {
    fileprivate func cURLRepresentation() -> String {
        var components = ["$ curl -v"]
        
        guard let url = url else {
            return "$ curl command could not be created"
        }
        
        if let httpMethod = httpMethod, httpMethod != "GET" {
            components.append("-X \(httpMethod)")
        }
        
        var headers: [AnyHashable: Any] = [:]
        
        if let headerFields = allHTTPHeaderFields {
            for (field, value) in headerFields where field != "Cookie" {
                headers[field] = value
            }
        }
        
        for (field, value) in headers {
            components.append("-H \"\(field): \(value)\"")
        }
        
        if let httpBodyData = httpBody, let httpBody = String(data: httpBodyData, encoding: .utf8) {
            var escapedBody = httpBody.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            escapedBody = escapedBody.replacingOccurrences(of: "\"", with: "\\\"")
            
            components.append("-d \"\(escapedBody)\"")
        }
        
        components.append("\"\(url.absoluteString)\"")
        
        return components.joined(separator: " \\\n\t")
    }
}
