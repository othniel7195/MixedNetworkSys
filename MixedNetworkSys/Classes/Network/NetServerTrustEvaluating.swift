//
//  NetServerTrustEvaluating.swift
//  MixedNetworkSys
//
//  Created by jimmy on 2021/8/23.
//

import Foundation
import Alamofire

public final class NetServerTrustEvaluating: ServerTrustEvaluating {
    private let certificates: [SecCertificate]
    private let acceptSelfSignedCertificates: Bool
    private let performDefaultValidation: Bool
    private let validateHost: Bool
    
    public init(certificates: [SecCertificate] = Bundle.main.af.certificates,
                acceptSelfSignedCertificates: Bool = false,
                performDefaultValidation: Bool = true,
                validateHost: Bool = true) {
        self.certificates = certificates
        self.acceptSelfSignedCertificates = acceptSelfSignedCertificates
        self.performDefaultValidation = performDefaultValidation
        self.validateHost = validateHost
    }

    public func evaluate(_ trust: SecTrust, forHost host: String) throws {
        
        var realHost = host
        if let domian = HTTPDNS.getOriginDomain(ipAddress: host) {
            realHost = domian
        }

        guard !certificates.isEmpty else {
            throw AFError.serverTrustEvaluationFailed(reason: .noCertificatesFound)
        }

        if acceptSelfSignedCertificates {
            try trust.af.setAnchorCertificates(certificates)
        }

        if performDefaultValidation {
            try trust.af.performDefaultValidation(forHost: realHost)
        }

        if validateHost {
            try trust.af.performValidation(forHost: realHost)
        }

        let serverCertificatesData = Set(trust.af.certificateData)
        let pinnedCertificatesData = Set(certificates.af.data)
        let pinnedCertificatesInServerData = !serverCertificatesData.isDisjoint(with: pinnedCertificatesData)
        if !pinnedCertificatesInServerData {
            throw AFError.serverTrustEvaluationFailed(reason: .certificatePinningFailed(host: realHost,
                                                                                        trust: trust,
                                                                                        pinnedCertificates: certificates,
                                                                                        serverCertificates: trust.af.certificates))
        }
    }
}
