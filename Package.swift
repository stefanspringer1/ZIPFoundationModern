// swift-tools-version:5.7
import PackageDescription

#if canImport(Compression)
let targets: [Target] = [
    .target(name: "ZIPFoundation"),
    .testTarget(name: "ZIPFoundationTests",
                dependencies: ["ZIPFoundation"],
                resources: [
                    .process("Resources")
                ])
]
#else
let targets: [Target] = [
    .systemLibrary(name: "CZLib", pkgConfig: "zlib", providers: [.brew(["zlib"]), .apt(["zlib"])]),
    .target(name: "ZIPFoundation", dependencies: ["CZLib"], cSettings: [.define("_GNU_SOURCE", to: "1")]),
    .testTarget(name: "ZIPFoundationTests",
                dependencies: ["ZIPFoundation"],
                resources: [
                    .process("Resources")
                ])
]
#endif

let package = Package(
    name: "ZIPFoundation",
    platforms: [
        .macOS(.v11), .iOS(.v11), .tvOS(.v11), .watchOS(.v4)
    ],
    products: [
        .library(name: "ZIPFoundation", targets: ["ZIPFoundation"])
    ],
    targets: targets
)
