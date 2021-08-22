//
//  Stub.swift
//  MixedNetworkSys
//
//  Created by jimmy on 08/03/2019.
//

import Foundation

public enum StubBehavior {
  case never
  ///立即返回
  case immediate
  case delayed(seconds: TimeInterval)
}
