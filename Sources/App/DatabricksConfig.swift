//
//  DatabricksConfig.swift
//  DatabricksDashboardViewer
//
//  Created by Ben Schultz on 2026-10-15.
//

import Foundation
import Vapor

/// Strongly-typed configuration holding Databricks workspace and service principal credentials.
public struct DatabricksConfig: Sendable {
    /// The Databricks workspace instance URL (e.g., "https://adb-1234567890123456.7.azuredatabricks.net" or "https://dbc-abcdefg-1234.cloud.databricks.com")
    public let instanceUrl: String
    
    /// The unique Databricks Workspace ID (numeric string)
    public let workspaceId: String
    
    /// The configured AI/BI (Lakeview) Dashboards loaded from `Resources/Dashboards.json`
    public let dashboards: [DashboardDefinition]
    
    /// The Service Principal Application (Client) ID
    public let clientId: String
    
    /// The Service Principal OAuth Secret
    public let clientSecret: String
    
    /// Default external viewer identifier (used for audit logs, must not contain PII)
    public let defaultViewerId: String
    
    /// Default external value (used for row-level security / SQL query filtering via `__aibi_external_value`)
    public let defaultExternalValue: String

    /// Initializes configuration from environment variables and loads `Dashboards.json` from `Resources`.
    public static func fromEnvironment(directory: DirectoryConfiguration = .detect()) throws -> DatabricksConfig {
        guard let instanceUrl = Environment.get("DATABRICKS_INSTANCE_URL"), !instanceUrl.isEmpty else {
            throw Abort(.internalServerError, reason: "Missing DATABRICKS_INSTANCE_URL environment variable")
        }
        guard let workspaceId = Environment.get("DATABRICKS_WORKSPACE_ID"), !workspaceId.isEmpty else {
            throw Abort(.internalServerError, reason: "Missing DATABRICKS_WORKSPACE_ID environment variable")
        }
        guard let clientId = Environment.get("DATABRICKS_CLIENT_ID"), !clientId.isEmpty else {
            throw Abort(.internalServerError, reason: "Missing DATABRICKS_CLIENT_ID environment variable")
        }
        guard let clientSecret = Environment.get("DATABRICKS_CLIENT_SECRET"), !clientSecret.isEmpty else {
            throw Abort(.internalServerError, reason: "Missing DATABRICKS_CLIENT_SECRET environment variable")
        }

        let defaultViewerId = Environment.get("DATABRICKS_DEFAULT_VIEWER_ID") ?? "anonymous_viewer"
        let defaultExternalValue = Environment.get("DATABRICKS_DEFAULT_EXTERNAL_VALUE") ?? "all"

        let dashboards = try loadDashboards(directory: directory)

        // Ensure instance URL does not have a trailing slash
        let sanitizedInstanceUrl = instanceUrl.hasSuffix("/") ? String(instanceUrl.dropLast()) : instanceUrl

        return DatabricksConfig(
            instanceUrl: sanitizedInstanceUrl,
            workspaceId: workspaceId,
            dashboards: dashboards,
            clientId: clientId,
            clientSecret: clientSecret,
            defaultViewerId: defaultViewerId,
            defaultExternalValue: defaultExternalValue
        )
    }

    /// Loads the static list of dashboards from `Resources/Dashboards.json`.
    public static func loadDashboards(directory: DirectoryConfiguration = .detect()) throws -> [DashboardDefinition] {
        let configuredURL = URL(fileURLWithPath: directory.resourcesDirectory)
            .appendingPathComponent("Dashboards.json")

        let fallbackURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // App
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // Package root
            .appendingPathComponent("Resources")
            .appendingPathComponent("Dashboards.json")

        let fileURL: URL
        if FileManager.default.fileExists(atPath: configuredURL.path) {
            fileURL = configuredURL
        } else if FileManager.default.fileExists(atPath: fallbackURL.path) {
            fileURL = fallbackURL
        } else {
            throw Abort(.internalServerError, reason: "Missing Dashboards.json at \(configuredURL.path)")
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.allowsJSON5 = true
        return try decoder.decode([DashboardDefinition].self, from: data)
    }
}

// Vapor Application storage key for DatabricksConfig
struct DatabricksConfigKey: StorageKey {
    typealias Value = DatabricksConfig
}
