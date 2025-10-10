// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "existentialannotator",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "existentialannotator",
            targets: ["existentialannotator"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax", exact: "602.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", exact: "1.6.1"),
    ],
    targets: [
        .executableTarget(
            name: "existentialannotator",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "existentialannotatorTests",
            dependencies: ["existentialannotator"]
        ),
    ]
)
