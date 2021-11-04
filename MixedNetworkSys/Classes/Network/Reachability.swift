//
//  Reachability.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/26/2021.
//

import Foundation
import RealReachability

open class Reachability {

    public enum NetReachabilityStatus {
        case unknown
        case notReachable
        case reachable(NetConnectionType)
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
    
    open var isVPN: Bool {
        return RealReachability.sharedInstance().isVPNOn()
    }
    
    /// The current network reachability status.
    open var networkReachabilityStatus: NetReachabilityStatus = .unknown {
        didSet {
            listener?(networkReachabilityStatus)
        }
    }
    
    open func startListening() {
        RealReachability.sharedInstance().startNotifier()
        NotificationCenter.default.addObserver(forName: .realReachabilityChanged, object: nil, queue: OperationQueue.main) { [weak self] notification in
            guard let self = self else { return }
            if let reachability = notification.object  as? RealReachability {
                let status = reachability.currentReachabilityStatus()
                switch status {
                case .RealStatusUnknown:
                    self.doubleCheck()
                case .RealStatusNotReachable:
                    self.doubleCheck()
                case .RealStatusViaWWAN:
                    self.networkReachabilityStatus = .reachable(.wwan)
                case .RealStatusViaWiFi:
                    self.networkReachabilityStatus = .reachable(.ethernetOrWiFi)
                default:
                    self.doubleCheck()
                }
            }
        }
    }
    
    open var checkInterval: TimeInterval = 2.0 {
        didSet {
            RealReachability.sharedInstance().autoCheckInterval = Float(checkInterval)
        }
    }
    
    private func doubleCheck() {
        RealReachability.sharedInstance().reachability { status in
            switch status {
            case .RealStatusUnknown:
                self.networkReachabilityStatus = .unknown
            case .RealStatusNotReachable:
                self.networkReachabilityStatus = .notReachable
            case .RealStatusViaWWAN:
                self.networkReachabilityStatus = .reachable(.wwan)
            case .RealStatusViaWiFi:
                self.networkReachabilityStatus = .reachable(.ethernetOrWiFi)
            default:
                self.networkReachabilityStatus = .unknown
            }
        }
    }
    open func stopListening() {
        RealReachability.sharedInstance().stopNotifier()
    }
    
    open func resetCheckHost(_ host: String) {
        RealReachability.sharedInstance().hostForPing = host
        RealReachability.sharedInstance().hostForCheck = host
    }
    
    open var listener: Listener?
    
    public typealias Listener = (NetReachabilityStatus) -> Void
    
    
    public init(checkHost: String) {
        RealReachability.sharedInstance().hostForPing = checkHost
        RealReachability.sharedInstance().hostForCheck = checkHost
    }
    
    
    public static let shared = Reachability(checkHost: "www.baidu.com")
    
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
