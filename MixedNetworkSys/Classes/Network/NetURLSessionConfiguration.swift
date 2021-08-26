//
//  NetworkResponseSerialization.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/25/2021..
//

import Foundation
import Alamofire

public struct NetworkURLSessionConfiguration {
    
    let useHTTPDNS: Bool
    
    let httpsCertificateLocalVerify: Bool
    
    let certificatesBundle: Bundle?
    
    let requestParamaterEncodeType: ParameterEncoding
    
    public let urlSessionConfiguration: URLSessionConfiguration
    
    /// 初始化
    /// - Parameter useHTTPDNS: 是否使用 HTTPDNS。默认为 true
    /// - Parameter httpsCertificateLocalVerify: 是否开启 HTTPS 证书本地校验。默认是 false
    /// - Parameter certificatesBundle: 证书 Bundle。默认是 nil。如果 httpsCertificateLocalVerify 为 true，这里就不能为 nil
    /// - Parameter requestParamaterEncodeType: 请求参数的编码方式。默认是 json
    /// - Parameter stub: 用于测试的 StubBehavior。默认是 never
    public init(
        useHTTPDNS: Bool = true,
        httpsCertificateLocalVerify: Bool = false,
        certificatesBundle: Bundle? = nil,
        requestParamaterEncodeType: ParameterEncoding = JSONEncoding.default
    ) {
        self.useHTTPDNS = useHTTPDNS
        self.httpsCertificateLocalVerify = httpsCertificateLocalVerify
        self.certificatesBundle = certificatesBundle
        self.requestParamaterEncodeType = requestParamaterEncodeType
        self.urlSessionConfiguration = URLSessionConfiguration.af.default
    }
}
