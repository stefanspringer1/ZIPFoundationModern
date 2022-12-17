// swift-tools-version:5.7
import PackageDescription

#if canImport(Compression)
    let targets: [Target] = [
        .target(name: "ZIPFoundation",
                dependencies: [
                    .product(name: "SystemPackage", package: "swift-system")
                ]),
        .testTarget(name: "ZIPFoundationTests",
                    dependencies: ["ZIPFoundation"],
                    resources: [
                        .process("Resources"),
                    ]),
    ]
#else
    let targets: [Target] = [
        .target(
            name: "CZLib",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-Wno-shorten-64-to-32"]),
                .define("Z_HAVE_UNISTD_H", .when(platforms: [.macOS, .linux])),
                .define("HAVE_STDARG_H"),
                .define("HAVE_HIDDEN"),
                .define("_LARGEFILE64_SOURCE", to: "1"),
                .define("_FILE_OFFSET_BITS", to: "64"),
                .define("_LFS64_LARGEFILE", to: "1"),
                .define("_CRT_SECURE_NO_DEPRECATE", .when(platforms: [.windows])),
                .define("_CRT_NONSTDC_NO_DEPRECATE", .when(platforms: [.windows])),
            ]
        ),
        .target(name: "ZIPFoundation",
                dependencies: [
                    "CZLib",
                    .product(name: "SystemPackage", package: "swift-system"),
                ]),
        .testTarget(name: "ZIPFoundationTests",
                    dependencies: ["ZIPFoundation"],
                    resources: [
                        .process("Resources"),
                    ]),
    ]
#endif

let package = Package(
    name: "ZIPFoundation",
    platforms: [
        .macOS(.v11), .iOS(.v12), .tvOS(.v12), .watchOS(.v4),
    ],
    products: [
        .library(name: "ZIPFoundation", targets: ["ZIPFoundation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-system", from: "1.0.0"),
    ],
    targets: targets
)
