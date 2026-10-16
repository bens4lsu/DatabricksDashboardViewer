// ==============================================================================
// DashboardHTMLRenderer.swift
//
// Production-Ready Swift Vapor Backend Framework for Databricks AI/BI Dashboard
// Embedding via OAuth 2.0 Service Principal (M2M) Authentication and iFrame Integration.
// ==============================================================================

import Foundation
import Vapor

public struct DashboardViewContext: Encodable, Sendable {
    public let title: String
    public let instanceUrl: String
    public let workspaceId: String
    public let dashboardId: String
    public let token: String
    public let viewerId: String
    public let externalValue: String
}

public enum DashboardHTMLRenderer {
    public static func render(
        req: Request,
        config: DatabricksConfig,
        dashboardId: String,
        token: String,
        viewerId: String,
        externalValue: String
    ) async throws -> View {
        let context = DashboardViewContext(
            title: "Databricks Embedded Dashboard",
            instanceUrl: config.instanceUrl,
            workspaceId: config.workspaceId,
            dashboardId: dashboardId,
            token: token,
            viewerId: viewerId,
            externalValue: externalValue
        )
        return try await req.view.render("dashboard", context)
    }
}
