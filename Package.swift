// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "oauth",
    platforms: [ 
      .macOS(.v13),
      .iOS(.v16),
      .tvOS(.v16),
      .watchOS(.v9),
    ],
    products: [
        .library( name: "OAuth", targets: ["OAuth"]),
    ],
    dependencies: [
      .package(url: "https://github.com/vapor/vapor.git", from: "4.92.4"),
      .package(url: "https://github.com/bwdmr/oauth-kit", branch: "test")
    ],
    targets: [
        .target(
          name: "OAuth",
          dependencies: [
            .product(name: "OAuthKit", package: "oauth-kit"),
            .product(name: "Vapor", package: "vapor")
          ],
          swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),
        .testTarget( 
          name: "OAuthTests",
          dependencies: [
            .target(name: "OAuth"),
            .product(name: "XCTVapor", package: "vapor")
          ],
          swiftSettings: [.enableExperimentalFeature("StrictConurrency")]
        ),
    ]
)



