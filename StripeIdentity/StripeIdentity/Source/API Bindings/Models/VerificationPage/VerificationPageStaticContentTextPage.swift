//
// VerificationPageStaticContentTextPage.swift
//
// Generated by swagger-codegen
// https://github.com/swagger-api/swagger-codegen
//

import Foundation
@_spi(STP) import StripeCore

extension StripeAPI { 

    struct VerificationPageStaticContentTextPage: Decodable, Equatable {
        let body: String
        let buttonText: String
        let title: String
    }

}