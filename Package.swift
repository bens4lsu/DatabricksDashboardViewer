// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DatabricksDashboardViewer",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // Vapor web framework
        .package(url: "https://github.com/vapor/vapor.git", from: "4.89.0"),
        // Optional Leaf templating support
        .package(url: "https://github.com/vapor/leaf.git", from: "4.3.0")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Leaf", package: "leaf")
            ]
        )
    ]
)
