//
//  Reachability.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/26/2021.
//

import Foundation
import Alamofire

open class Reachability {

    public enum NetReachabilityStatus {
        case unknown
        case notReachable
        case reachable(NetConnectionType)
    }
    
    public enum Notification {
        public static let networkReachabilityChanged = Foundation.Notification.Name("net.reachabilityChanged.new")
    }
   
    public enum NetConnectionType {
        case ethernetOrWiFi
        ///移动网络
        case wwan
    }
    
    open var isReachable: Bool {
        return isReachableOnWWAN || isReachableOnEthernetOrWiFi
    }
    
    open var isReachableOnWWAN: Bool {
        return networkReachabilityStatus == .reachable(.wwan)
    }
    
    open var isReachableOnEthernetOrWiFi: Bool {
        return networkReachabilityStatus == .reachable(.ethernetOrWiFi)
    }
    
    /// The current network reachability status.
    open var networkReachabilityStatus: NetReachabilityStatus {
        switch afNetworkReachabilityManager?.status {
        case .notReachable:
            return .notReachable
        case .reachable(let connectionType):
            switch connectionType {
            case .ethernetOrWiFi:
                return .reachable(.ethernetOrWiFi)
            case .cellular:
                return .reachable(.wwan)
            }
        case .unknown:
            return .unknown
        default:
            return .unknown
        }
    }
    
    open func startListening() {
        afNetworkReachabilityManager?.startListening { [weak self] _ in
            guard let self = self else { return }
            
            self.listener?(self.networkReachabilityStatus)
            
            NotificationCenter.default.post(
                name: Reachability.Notification.networkReachabilityChanged,
                object: self
            )
        }
    }
    
    open func stopListening() {
        afNetworkReachabilityManager?.stopListening()
    }
    
    open var listener: Listener?
    
    public typealias Listener = (NetReachabilityStatus) -> Void
    
    
    public init(checkHost: String) {
        self.afNetworkReachabilityManager = Alamofire.NetworkReachabilityManager(host: checkHost)
    }
    
    public static let shared = Reachability(checkHost: "www.baidu.com")
    
    let afNetworkReachabilityManager: Alamofire.NetworkReachabilityManager?
}

extension Reachability.NetReachabilityStatus: Equatable {

    public static func == (
        lhs: Reachability.NetReachabilityStatus,
        rhs: Reachability.NetReachabilityStatus
    ) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown):
            return true
        case (.notReachable, .notReachable):
            return true
        case (.reachable(let lhsConnectionType), .reachable(let rhsConnectionType)):
            return lhsConnectionType == rhsConnectionType
        default:
            return false
        }
    }
}
