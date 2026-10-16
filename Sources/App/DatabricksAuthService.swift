//
//  DatabricksAuthService.swift
//  DatabricksDashboardViewer
//
//  Created by Ben Schultz on 2026-10-15.
//

import Foundation
import Vapor
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Thread-safe service responsible for the 3-step Databricks OAuth M2M exchange and token downscoping.
public final class DatabricksAuthService: Sendable {
    private let config: DatabricksConfig

    public init(config: DatabricksConfig) {
        self.config = config
    }

    /// Computes HTTP Basic Authentication header value: Basic Base64(client_id:client_secret)
    private var basicAuthHeader: String {
        let credentials = "\(config.clientId):\(config.clientSecret)"
        let base64 = Data(credentials.utf8).base64EncodedString()
        return "Basic \(base64)"
    }

    /// Generates a tightly-scoped access token authorized exclusively for the requested dashboard and viewer context.
    ///
    /// - Parameters:
    ///   - client: Vapor's HTTP `Client`
    ///   - dashboardId: The published AI/BI (Lakeview) Dashboard ID
    ///   - viewerId: Opaque unique identifier for the user (recorded in Databricks audit logs; must not contain PII).
    ///   - externalValue: Row-level filter value passed into the SQL dataset queries as `__aibi_external_value`.
    /// - Returns: A downscoped OAuth 2.0 access token string safe for client-side iframe rendering.
    public func getScopedDashboardToken(
        client: Client,
        dashboardId: String,
        viewerId: String,
        externalValue: String
    ) async throws -> DatabricksTokenResponse {
        // ---------------------------------------------------------------------
        // Step 1: Request Broad M2M Token ("all-apis") via Service Principal Basic Auth
        // ---------------------------------------------------------------------
        let oidcTokenUri = URI(string: "\(config.instanceUrl)/oidc/v1/token?o=\(config.workspaceId)")
        let broadTokenBody = "grant_type=client_credentials&scope=all-apis"

        var step1Headers = HTTPHeaders()
        step1Headers.contentType = .urlEncodedForm
        step1Headers.add(name: .authorization, value: self.basicAuthHeader)

        let step1Response = try await client.post(oidcTokenUri, headers: step1Headers) { req in
            req.body = .init(string: broadTokenBody)
        }

        guard step1Response.status == .ok else {
            let errorText = step1Response.body.map { String(buffer: $0) } ?? "No response body"
            throw Abort(
                .badGateway,
                reason: "Databricks OIDC Step 1 failed (HTTP \(step1Response.status.code)): \(errorText)"
            )
        }

        let broadToken = try step1Response.content.decode(DatabricksTokenResponse.self)

        // ---------------------------------------------------------------------
        // Step 2: Request TokenInfo & Authorization Details from Lakeview API
        // ---------------------------------------------------------------------
        guard let encodedViewerId = viewerId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedExternalValue = externalValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw Abort(.badRequest, reason: "Invalid characters in viewerId or externalValue")
        }

        let tokenInfoUrlString = "\(config.instanceUrl)/api/2.0/lakeview/dashboards/\(dashboardId)/published/tokeninfo?o=\(config.workspaceId)&external_viewer_id=\(encodedViewerId)&external_value=\(encodedExternalValue)"
        let tokenInfoUri = URI(string: tokenInfoUrlString)

        var step2Headers = HTTPHeaders()
        step2Headers.add(name: .authorization, value: "Bearer \(broadToken.access_token)")

        let step2Response = try await client.get(tokenInfoUri, headers: step2Headers)

        guard step2Response.status == .ok else {
            let errorText = step2Response.body.map { String(buffer: $0) } ?? "No response body"
            throw Abort(
                .badGateway,
                reason: "Databricks Lakeview TokenInfo Step 2 failed (HTTP \(step2Response.status.code)): \(errorText)"
            )
        }

        guard let tokenInfoByteBuffer = step2Response.body else {
            throw Abort(.badGateway, reason: "Empty response body from Databricks TokenInfo endpoint")
        }

        let tokenInfoData = Data(tokenInfoByteBuffer.readableBytesView)
        guard let tokenInfoJson = try JSONSerialization.jsonObject(with: tokenInfoData) as? [String: Any] else {
            throw Abort(.badGateway, reason: "Malformed JSON response from Databricks TokenInfo endpoint")
        }

        // ---------------------------------------------------------------------
        // Step 3: Exchange for Downscoped User Token
        // ---------------------------------------------------------------------
        // Extract authorization_details from the tokenInfo dictionary
        var scopedParams = tokenInfoJson
        let authDetails = scopedParams.removeValue(forKey: "authorization_details")

        var formComponents: [String] = ["grant_type=client_credentials"]

        if let authDetails = authDetails {
            let authDetailsData = try JSONSerialization.data(withJSONObject: authDetails, options: [])
            guard let authDetailsString = String(data: authDetailsData, encoding: .utf8) else {
                throw Abort(.internalServerError, reason: "Failed to encode authorization_details JSON string")
            }
            guard let encodedAuthDetails = authDetailsString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
                throw Abort(.internalServerError, reason: "Failed to percent-encode authorization_details")
            }
            formComponents.append("authorization_details=\(encodedAuthDetails)")
        }

        // Include any remaining parameters from tokeninfo (e.g. scopes, claims)
        for (key, value) in scopedParams {
            let stringVal = "\(value)"
            if let encKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let encVal = stringVal.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                formComponents.append("\(encKey)=\(encVal)")
            }
        }

        let scopedTokenBody = formComponents.joined(separator: "&")

        var step3Headers = HTTPHeaders()
        step3Headers.contentType = .urlEncodedForm
        step3Headers.add(name: .authorization, value: self.basicAuthHeader)

        let step3Response = try await client.post(oidcTokenUri, headers: step3Headers) { req in
            req.body = .init(string: scopedTokenBody)
        }

        guard step3Response.status == .ok else {
            let errorText = step3Response.body.map { String(buffer: $0) } ?? "No response body"
            throw Abort(
                .badGateway,
                reason: "Databricks OIDC Step 3 (scoped token) failed (HTTP \(step3Response.status.code)): \(errorText)"
            )
        }

        let scopedToken = try step3Response.content.decode(DatabricksTokenResponse.self)
        return scopedToken
    }
}
