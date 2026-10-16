//
//  DashboardController.swift
//  DatabricksDashboardViewer
//
//  Created by Ben Schultz on 2026-10-15.
//

import Foundation
import Vapor

public struct DashboardController: RouteCollection, Sendable {
    private let dashboards: [DashboardDefinition]

    public init(dashboards: [DashboardDefinition]) {
        self.dashboards = dashboards
    }

    public func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api", "token")

        for dashboard in dashboards {
            let pathComponents = dashboard.path
                .split(separator: "/")
                .map { PathComponent.constant(String($0)) }

            // Web Page Route: renders the HTML page with the embedded iframe for this dashboard
            routes.get(pathComponents) { req in
                try await self.renderDashboard(req: req, dashboardId: dashboard.id)
            }

            // API Route: returns a fresh scoped token for client-side SPAs or token refresh
            api.get(pathComponents) { req in
                try await self.getScopedTokenApi(req: req, dashboardId: dashboard.id)
            }
        }
    }

    /// Renders the HTML page embedded with Databricks AI/BI Dashboard.
    /// Supports dynamic query parameters: `?viewerId=...&externalValue=...`
    @Sendable
    public func renderDashboard(req: Request, dashboardId: String) async throws -> Response {
        let config = req.application.databricksConfig
        let authService = DatabricksAuthService(config: config)

        let viewerId = req.query[String.self, at: "viewerId"] ?? config.defaultViewerId
        let externalValue = req.query[String.self, at: "externalValue"] ?? config.defaultExternalValue

        req.logger.info("Generating Databricks scoped token for dashboard: \(dashboardId), viewer: \(viewerId), value: \(externalValue)")

        let tokenResponse = try await authService.getScopedDashboardToken(
            client: req.client,
            dashboardId: dashboardId,
            viewerId: viewerId,
            externalValue: externalValue
        )

        let view = try await DashboardHTMLRenderer.render(
            req: req,
            config: config,
            dashboardId: dashboardId,
            token: tokenResponse.access_token,
            viewerId: viewerId,
            externalValue: externalValue
        )

        var response = try await view.encodeResponse(for: req)
        response.headers.replaceOrAdd(name: .cacheControl, value: "no-store, max-age=0")
        return response
    }

    /// JSON API endpoint returning a downscoped token payload.
    @Sendable
    public func getScopedTokenApi(req: Request, dashboardId: String) async throws -> ClientTokenPayload {
        let config = req.application.databricksConfig
        let authService = DatabricksAuthService(config: config)

        let viewerId = req.query[String.self, at: "viewerId"] ?? config.defaultViewerId
        let externalValue = req.query[String.self, at: "externalValue"] ?? config.defaultExternalValue

        let tokenResponse = try await authService.getScopedDashboardToken(
            client: req.client,
            dashboardId: dashboardId,
            viewerId: viewerId,
            externalValue: externalValue
        )

        return ClientTokenPayload(
            token: tokenResponse.access_token,
            instanceUrl: config.instanceUrl,
            workspaceId: config.workspaceId,
            dashboardId: dashboardId,
            expiresIn: tokenResponse.expires_in
        )
    }
}
