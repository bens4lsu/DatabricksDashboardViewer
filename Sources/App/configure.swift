//
//  configure.swift
//  DatabricksDashboardViewer
//
//  Created by Ben Schultz on 2026-10-15.
//

import Foundation
import Leaf
import Vapor

/// Configures services, storage, and routes on the Vapor Application.
public func configure(_ app: Application) throws {
    // 1. Initialize Databricks configuration from environment and Dashboards.json
    app.databricksConfig = try DatabricksConfig.fromEnvironment(directory: app.directory)
    
    if let portString = Environment.get("PORT"), let port = Int(portString) {
        app.http.server.configuration.port = port
    }

    // 2. Configure Leaf templating engine
    app.views.use(.leaf)

    // 3. Register controller routes for all configured dashboards
    try app.register(collection: DashboardController(dashboards: app.databricksConfig.dashboards))

    app.logger.info("Databricks Dashboard Server initialized for workspace: \(app.databricksConfig.workspaceId) with \(app.databricksConfig.dashboards.count) dashboard(s)")
}
