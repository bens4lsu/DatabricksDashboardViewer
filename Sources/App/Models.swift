//
//  Models.swift
//  DatabricksDashboardViewer
//
//  Created by Ben Schultz on 2026-10-15.
//
import Foundation
import Vapor

/// Represents a single dashboard entry configured in `Resources/Dashboards.json`.
public struct DashboardDefinition: Codable, Sendable {
    public let path: String
    public let id: String

    public init(path: String, id: String) {
        self.path = path
        self.id = id
    }
}

public struct DatabricksTokenResponse: Content, Sendable {
    public let access_token: String
    public let token_type: String?
    public let expires_in: Int?
    public let scope: String?
}

/// JSON payload returned by Databricks for client-side API requests
public struct ClientTokenPayload: Content, Sendable {
    public let token: String
    public let instanceUrl: String
    public let workspaceId: String
    public let dashboardId: String
    public let expiresIn: Int?
}
