// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "PoetryCore", platforms: [.iOS(.v17), .macOS(.v13)], products: [.library(name: "PoetryCore", targets: ["PoetryCore"])], targets: [
    .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3", providers: [.apt(["libsqlite3-dev"]), .brew(["sqlite3"])]),
    .target(name: "PoetryCore", dependencies: ["CSQLite"], resources: [.process("Resources")]),
    .testTarget(name: "PoetryCoreTests", dependencies: ["PoetryCore"])
])
