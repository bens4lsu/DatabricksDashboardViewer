//
//  Application.swift
//  DatabricksDashboardViewer
//
//  Created by Ben Schultz on 2026-10-15.
//

import Vapor

extension Application {
    public var databricksConfig: DatabricksConfig {
        get {
            guard let config = self.storage[DatabricksConfigKey.self] else {
                fatalError("DatabricksConfig not configured. Call app.databricksConfig = try DatabricksConfig.fromEnvironment()")
            }
            return config
        }
        set {
            self.storage[DatabricksConfigKey.self] = newValue
        }
    }
}
