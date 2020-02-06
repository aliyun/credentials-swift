// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
        name: "AlibabaCloudCredentials",
        products: [
            .library(
                    name: "AlibabaCloudCredentials",
                    targets: ["AlibabaCloudCredentials"])
        ],
        dependencies: [
            // Dependencies declare other packages that this package depends on.
            .package(url: "https://github.com/aliyun/AlamofirePromiseKit.git", from: "1.0.0"),
            .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.3.0"),
            .package(url: "https://github.com/birdrides/mockingbird.git", from: "0.9.0")
        ],
        targets: [
            .target(
                    name: "AlibabaCloudCredentials",
                    dependencies: ["AlamofirePromiseKit", "CryptoSwift"]),
            .testTarget(
                    name: "AlibabaCloudCredentialsTests",
                    dependencies: ["AlibabaCloudCredentials", "AlamofirePromiseKit", "CryptoSwift", "Mockingbird"])
        ]
)
