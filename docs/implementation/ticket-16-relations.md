# Issue #16 graph component preflight

Checked 2026-09-07 against fresh official repository clone `/tmp/poetry-spec8-grape`. No project files changed. Target supplied by coordinator: iPhone16,1, iOS 26.4.1; Mac Xcode 26.6 / Swift 6.3.3. This is source/API preflight, **not a successful Xcode build or device test**.

## Recommendation

Use a small deterministic native SwiftUI graph: Path lines with individual edge hit regions, real Button nodes, and an equivalent visible relationship list. This is a fitness decision after assessing Grape, **not a claim Grape cannot run on this device**. Grape solves force simulation, which a stable sparse one-hop graph does not need, while edge selection and accessible interactive elements still need custom work. No Web container is needed.

## Fresh evidence

- Fetched `li3zhen1/Grape` main at `bdfad750d2a973af48159119eaf90530d0e30ea7` (commit timestamp 2025-05-19). `git ls-remote --tags` confirms 1.1.0 at `48eb7d8ab4ce549c6cdde106b5f7fa317421364c`. README installation URL refers to swiftgraphs/Grape; use a pinned exact release if evaluating it further rather than tracking main.
- [Package.swift](https://github.com/li3zhen1/Grape/blob/bdfad750d2a973af48159119eaf90530d0e30ea7/Package.swift): tools 5.9; minimum iOS 17 / macOS 14; Grape and ForceSimulation targets; experimental StrictConcurrency enabled; docc-plugin dependency. The supplied OS clears the declared floor. Manifest is not proof of Swift 6.3.3 compilation. [CI](https://github.com/li3zhen1/Grape/blob/bdfad750d2a973af48159119eaf90530d0e30ea7/.github/workflows/swift.yml) uses macos-14/latest-stable and macOS package tests, so it does not certify this iPhone/Xcode combination.
- [Graph state](https://github.com/li3zhen1/Grape/blob/bdfad750d2a973af48159119eaf90530d0e30ea7/Sources/Grape/Views/ForceDirectedGraphState.swift) supports `initialIsRunning: false`, mutable `isRunning`, and `ticksOnAppear: .zero` / `.untilStable`. [Graph initializer](https://github.com/li3zhen1/Grape/blob/bdfad750d2a973af48159119eaf90530d0e30ea7/Sources/Grape/Views/ForceDirectedGraph.swift) takes `emittingNewNodesWithStates`. [KineticState](https://github.com/li3zhen1/Grape/blob/bdfad750d2a973af48159119eaf90530d0e30ea7/Sources/Grape/Views/SimulationContext.swift) has position/velocity/fixation. Therefore stable prepositioned graphs are possible; continuous drift is not unavoidable. Default state runs, so adoption needs explicit state management.
- [GraphProxy](https://github.com/li3zhen1/Grape/blob/bdfad750d2a973af48159119eaf90530d0e30ea7/Sources/Grape/Modifiers/GraphProxy.swift) exposes node-at-location lookup, transforms and fixation; no equivalent public edge-at-location method. [Tap helper](https://github.com/li3zhen1/Grape/blob/bdfad750d2a973af48159119eaf90530d0e30ea7/Sources/Grape/Gestures/GraphTapGesture.swift) likewise targets nodes. Issue #16 requires actual relationship-line selection, so custom hit testing remains necessary.
- [Rendering](https://github.com/li3zhen1/Grape/blob/bdfad750d2a973af48159119eaf90530d0e30ea7/Sources/Grape/Views/ForceDirectedGraph+View.swift) uses Canvas. A search of all Grape Swift sources found no `accessibility` / `ReduceMotion` APIs. This is limited source evidence, not a claim that consumers cannot add them.
- Apple [Canvas](https://developer.apple.com/documentation/swiftui/canvas) explicitly explains that individual canvas elements, including view symbols, do not receive interactivity or accessibility automatically. Apple [accessibilityChildren](https://developer.apple.com/documentation/swiftui/view/accessibilitychildren(children:)) permits synthetic accessibility children (iOS 15+). Apple [accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion) exposes the user's preference (iOS 13+). Current markdown documentation fetched directly successfully when the web renderer could not parse it.

## Implementation guidance for #16

1. Derive a sparse local relationship set from verified data and sort IDs before assigning a deterministic center/ring or manually balanced slots. Retain these positions while selecting nodes/edges and returning from detail routes. Do not run a timer/physics loop.
2. Make each relation line independently tappable using a widened transparent stroked Path (`contentShape`) or explicit shortest-distance-to-segment hit testing. Prefer node hit areas at crossings; provide relationship rows when lines overlap. A midpoint button alone does not satisfy tapping the whole line.
3. Real node Buttons and relationship-list Buttons supply labels, actions and VoiceOver navigation naturally. Each edge action opens the exact relation record with summary, source and evidence-poem routes; gifting/response is not automatically meeting evidence.
4. Cap the drawn neighborhood, provide a complete list for overflow or large Dynamic Type, and ensure Chinese names avoid clipping. List fallback must preserve relationship selection and navigation.
5. Honor `@Environment(\.accessibilityReduceMotion)` if adding selection/layout transitions; static presentation already avoids drifting. No motion is needed for the first version.
6. Application tests should cover evidence IDs, exact chosen relationship, unknown/empty relationships and route restoration. Actual device QA still must cover each edge, Chinese text, return navigation and VoiceOver/Reduce Motion. Report any unavailable device checks truthfully.

If Grape is selected instead, first build a pinned isolated sample on the named Mac SDK and perform these same device checks; the source inspection alone cannot justify claiming successful compatibility.

## Native implementation

Relationship JSON is installed once into SQLite, with stable person/evidence IDs. The neighborhood includes only sourced edges whose people and evidence authors resolve. Three verified directional literary relations use the project's seed evidence chain; no inferred meeting or anonymous friend is promoted to a person. A deterministic native center/ring graph has entire stroked-line hit regions, separate person and relation selection, and visible equivalent list controls. Accessibility sizes and neighborhoods above five people use the complete list only. Exact evidence works and people open in the existing navigation stack.

Application tests cover exact neighborhoods, evidence authors, restart persistence and missing evidence/person empty states with retained works. No Mac build or device test was performed by this implementation task; integration must verify edges, navigation, names, large type and VoiceOver on device. R3 prototype exports are unchanged; this is a separate native increment.

## Content updates

The full catalog now requires `relationships` (an empty array is valid). Both publisher and app reject unknown/same-person endpoints, duplicate relation/evidence IDs, absent sources, missing works or works attributed to a different source poet. Relations replace atomically with all other catalogs; the installed marker prevents seed relations from returning after an intentionally empty update. Client tests cover failed-update retention and restart after replacement/clearing; service tests cover matching evidence validation.
