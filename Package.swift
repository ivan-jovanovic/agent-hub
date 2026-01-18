// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentUI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AgentUI", targets: ["AgentUI"])
    ],
    targets: [
        .executableTarget(
            name: "AgentUI",
            path: "Sources/AgentUI"
        )
    ]
)
