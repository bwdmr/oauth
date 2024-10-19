// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "oauth",
  platforms: [
    .macOS(.v13),
    .iOS(.v15),
    .tvOS(.v15),
    .watchOS(.v8),
  ],
  products: [
    .library(name: "OAuth", targets: ["OAuth"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-log.git", from: "1.6.1"),
    .package(url: "https://github.com/vapor/vapor.git", from: "4.106.0"),
    .package(url: "https://github.com/bwdmr/oauth-kit", branch: "main")
  ],
  targets: [
    .target(
      name: "OAuth",
      dependencies: [
        .product(name: "OAuthKit", package: "oauth-kit"),
        .product(name: "Vapor", package: "vapor")
      ]
    ),
    .testTarget(
      name: "OAuthTests",
      dependencies: [
        .target(name: "OAuth"),
        .product(name: "XCTVapor", package: "vapor")
      ]
    ),
  ],
  swiftLanguageModes: [ .v6 ]
)
