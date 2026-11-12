# Product Specification

CleanBuild helps developers understand and recover storage consumed by build artifacts and tool caches. It is intentionally not a generic cleaner. Results must be measured from disk, every action must be reviewable, and ambiguous data remains Review or Protected.

The native macOS 14+ app includes onboarding, Overview, Storage Explorer, History, and Settings. The initial adapters cover Xcode DerivedData and Archives, Gradle, Node package caches, and workspace-scoped Flutter build output. Docker, simulators, and Android remain report-only until tool-specific cleanup semantics are implemented and tested.

