// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "flutter_image_clip",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "flutter-image-clip", targets: ["flutter_image_clip"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_image_clip",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
