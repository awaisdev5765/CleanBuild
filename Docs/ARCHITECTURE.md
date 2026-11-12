# Architecture

The SwiftUI app uses a feature-oriented layout and a single main-actor `AppModel` for view state. Core models are Codable and Sendable. `ScanCoordinator` serializes independently replaceable adapters and supports task cancellation. Each adapter returns measured `ScanTarget` values with an explainable classification and consequence.

`CleanupPlan` is immutable. `CleanupExecutor` rechecks classification, canonical path safety, existence, and allocated size immediately before an action. Dry run is the default. Real execution uses `FileManager.trashItem`, never shell interpolation or `rm`.

History is stored as an atomic local Codable document with a 50-scan retention cap. This release avoids external dependencies. A production evolution can migrate this metadata to SQLite without changing the domain models.

