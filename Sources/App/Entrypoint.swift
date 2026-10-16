//
//  File.swift
//  DatabricksDashboardViewer
//
//  Created by Ben Schultz on 2026-10-15.
//

import Foundation
import Vapor

@main
public struct Entrypoint {
    public static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = Application(env)
        defer { app.shutdown() }

        do {
            try configure(app)
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            throw error
        }
    }
}

