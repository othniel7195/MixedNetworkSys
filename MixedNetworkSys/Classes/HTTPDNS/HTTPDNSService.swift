//
//  HTTPDNSService.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/02/2019.
//

import Foundation

public protocol HTTPDNSService {
  
  ///HTTPDNS 服务的抽象
  ///
  /// - Parameters:
  ///   - domain: 需要获取 IP 的域名 host
  ///   - maxTTL: 域名的TTL值
  ///   - response: 返回 DNS 解析结果，或者 Error
  func query(_ domain: String, maxTTL: TTL, response: @escaping (DNSRecord?, Error?) -> Void)
}

final class HTTPDNSServiceFactory: HTTPDNSService {
  
  private typealias Response = (DNSRecord?, Error?) -> Void
  
  private var service: HTTPDNSService?
  private var querying = Set<String>()
  private var queryingCompleteCache = [String: [Response]]()
  
  init(_ service: HTTPDNSService? = nil) {
    self.service = service
  }
  
  func configHTTPDNSService(_ service: HTTPDNSService) {
    self.service = service
  }
  
  func query(_ domain: String, maxTTL: TTL, response: @escaping (DNSRecord?, Error?) -> Void) {
    
    func updateCompleteCache() {
      var value = [Response]()
      if let cache = queryingCompleteCache[domain] {
        value += cache
      }
      value.append(response)
      queryingCompleteCache[domain] = nil
    }
    
    func callback(record: DNSRecord?) {
      querying.remove(domain)
      if let completes = queryingCompleteCache[domain] {
        completes.forEach { $0(record, nil) }
        queryingCompleteCache[domain] = nil
      }
    }
    
    if querying.contains(domain) {
      updateCompleteCache()
    } else {
      querying.insert(domain)
      updateCompleteCache()
      service?.query(domain, maxTTL: maxTTL, response: { (record, _) in
        callback(record: record)
      })
    }
  }
  
}
