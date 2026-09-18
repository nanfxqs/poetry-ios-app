// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "PoetryCore", platforms: [.iOS(.v17), .macOS(.v13)], products: [.library(name: "PoetryCore", targets: ["PoetryCore"])], targets: [
    .systemLibrary(name: "CSQLite"),
    .target(name: "PoetryCore", dependencies: ["CSQLite"], resources: [.process("Resources")]),
    .testTarget(name: "PoetryCoreTests", dependencies: ["PoetryCore"])
])
