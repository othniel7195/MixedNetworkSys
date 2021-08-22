//
//  Reachability.swift
//  MixedNetworkSys
//
//  Created by zf on 2021/8/22.
//

import Foundation

open class Reachability {
  /// Defines the various states of network reachability.
  ///
  /// - unknown:      It is unknown whether the network is reachable.
  /// - notReachable: The network is not reachable.
  /// - reachable:    The network is reachable.
  public enum NetworkReachabilityStatus {
    case unknown
    case notReachable
    case reachable(ConnectionType)
  }

  public enum Notification {
    /// Notification about Reachability changed, Notification Object is `Reachability`.
    public static let reachabilityChanged = Foundation.Notification.Name("reachabilityChanged.new")
  }

  /// Defines the various connection types detected by reachability flags.
  ///
  /// - ethernetOrWiFi: The connection type is either over Ethernet or WiFi.
  /// - wwan:           The connection type is a WWAN connection.
  public enum ConnectionType {
    case ethernetOrWiFi
    case wwan
  }

  // MARK: - Properties

  /// Whether the network is currently reachable.
  open var isReachable: Bool {
    return isReachableOnWWAN || isReachableOnEthernetOrWiFi
  }

  /// Whether the network is currently reachable over the WWAN interface.
  open var isReachableOnWWAN: Bool {
    return networkReachabilityStatus == .reachable(.wwan)
  }

  /// Whether the network is currently reachable over Ethernet or WiFi interface.
  open var isReachableOnEthernetOrWiFi: Bool {
    return networkReachabilityStatus == .reachable(.ethernetOrWiFi)
  }

  /// The current network reachability status.
  open var networkReachabilityStatus: NetworkReachabilityStatus {
    switch afNetworkReachabilityManager.networkReachabilityStatus {
    case .notReachable:
      return .notReachable
    case .reachableViaWiFi:
      return .reachable(.ethernetOrWiFi)
    case .reachableViaWWAN:
      return .reachable(.wwan)
    case .unknown:
      return .unknown
    default:
      return .unknown
    }
  }

  open func startListening() {
    afNetworkReachabilityManager.setReachabilityStatusChange { [weak self] _ in
      guard let self = self else { return }

      self.listener?(self.networkReachabilityStatus)

      NotificationCenter.default.post(
        name: Reachability.Notification.reachabilityChanged,
        object: self
      )
    }
    afNetworkReachabilityManager.startMonitoring()
  }

  open func stopListening() {
    afNetworkReachabilityManager.stopMonitoring()
  }

  open var listener: Listener?

  /// A closure executed when the network reachability status changes. The closure takes a single argument: the
  /// network reachability status.
  public typealias Listener = (NetworkReachabilityStatus) -> Void

  public convenience init?() {
    var address: sockaddr_in = {
      var address = sockaddr_in()
      address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
      address.sin_family = sa_family_t(AF_INET)
      return address
    }()

    let _reachability = withUnsafePointer(to: &address, { pointer in
      return pointer.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size) {
        return SCNetworkReachabilityCreateWithAddress(nil, $0)
      }
    })

    guard let reachability = _reachability else { return nil }

    self.init(manager: .init(reachability: reachability))
  }

  init(manager: AFNetworkReachabilityManager) {
    self.afNetworkReachabilityManager = manager
  }

  public static let shared = Reachability(manager: .shared())

  // MARK: - Internal

  let afNetworkReachabilityManager: AFNetworkReachabilityManager
}

// MARK: -

extension Reachability.NetworkReachabilityStatus: Equatable {
  /// Returns whether the two network reachability status values are equal.
  ///
  /// - parameter lhs: The left-hand side value to compare.
  /// - parameter rhs: The right-hand side value to compare.
  ///
  /// - returns: `true` if the two values are equal, `false` otherwise.
  public static func == (
    lhs: Reachability.NetworkReachabilityStatus,
    rhs: Reachability.NetworkReachabilityStatus
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
